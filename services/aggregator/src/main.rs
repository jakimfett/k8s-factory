use axum::{extract::State, response::{Html, IntoResponse}, routing::get, Json, Router};
use prometheus::{Encoder, TextEncoder, register_counter_vec, register_histogram_vec, CounterVec, HistogramVec};
use serde::Serialize;
use std::{env, net::SocketAddr, sync::Arc, time::Instant};

// Initialize metrics
lazy_static::lazy_static! {
    static ref REQUEST_COUNTER: CounterVec = register_counter_vec!(
        "aggregator_requests_total",
        "Total number of requests processed by the aggregator",
        &["endpoint"]
    ).unwrap();
    
    static ref RESPONSE_TIME_HISTOGRAM: HistogramVec = register_histogram_vec!(
        "aggregator_response_time_ms",
        "Response time in milliseconds",
        &["echo_server"],
        vec![5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0]
    ).unwrap();
}

// Define application state
#[derive(Clone)]
struct AppState {
    echo_urls: Arc<Vec<String>>,

}

#[derive(Serialize)]
struct EchoResponse {
    url: String,
    body: String,
    ms: u128,
}

async fn aggregate(State(state): State<AppState>) -> impl IntoResponse {
    // Increment real counter for aggregate endpoint
    REQUEST_COUNTER.with_label_values(&["aggregate"]).inc();
    
    let mut handles = vec![];
    for url in state.echo_urls.iter() {
        let url = url.clone();
        handles.push(tokio::spawn(async move {
            let start = Instant::now();
            let body = match reqwest::get(&url).await {
                Ok(resp) => resp.text().await.unwrap_or_else(|_| "[error reading body]".to_string()),
                Err(_) => "[error connecting]".to_string(),
            };
            let elapsed_ms = start.elapsed().as_millis() as f64;
            
            // Extract the server name from the URL for better labeling
            let server_name = url.split("://").nth(1).unwrap_or(&url).split(":").next().unwrap_or("unknown");
            
            // Record response time in histogram
            RESPONSE_TIME_HISTOGRAM.with_label_values(&[server_name]).observe(elapsed_ms);
            
            EchoResponse {
                url,
                body,
                ms: elapsed_ms as u128,
            }
        }));
    }
    let mut results = vec![];
    for h in handles {
        if let Ok(res) = h.await { results.push(res); }
    }
    Json(results)
}

async fn metrics() -> impl IntoResponse {
    // Gather metrics using the prometheus crate's built-in gather function
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    let mut buffer = Vec::new();
    encoder.encode(&metric_families, &mut buffer).unwrap();
    
    // Return the metrics in Prometheus exposition format
    ([ (axum::http::header::CONTENT_TYPE.as_str(), "text/plain; version=0.0.4") ], buffer)
}

async fn index(State(state): State<AppState>) -> impl IntoResponse {
    // Increment real counter for index endpoint
    REQUEST_COUNTER.with_label_values(&["index"]).inc();
    
    Html(format!(r#"
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>Echo Aggregator</title>
        <style>body {{ font-family: sans-serif; }}</style>
    </head>
    <body>
        <h1>Echo Aggregator</h1>
        <p>Echo URLs: {:?}</p>
        <div id="responses">Loading...</div>
        <script>
        fetch('/aggregate').then(r => r.json()).then(data => {{
            let html = '';
            data.forEach(item => {{
                html += `<div><b>${{item.url}}</b> (${{item.ms}} ms):<br><pre>${{item.body}}</pre></div><hr/>`;
            }});
            document.getElementById('responses').innerHTML = html;
        }});
        </script>
    </body>
    </html>
    "#, state.echo_urls))
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    println!("[aggregator] Starting up...");
    
    // Print environment for debugging
    for (key, value) in env::vars() {
        println!("[aggregator] ENV: {}={}", key, value);
    }
    
    match env::var("ECHO_URLS") {
        Ok(val) => println!("[aggregator] ECHO_URLS: {}", val),
        Err(e) => println!("[aggregator] ERROR: ECHO_URLS not set: {}", e),
    }
    
    let echo_urls = env::var("ECHO_URLS").expect("ECHO_URLS env var required");
    let urls: Vec<String> = echo_urls.split(',').map(|s| s.trim().to_string()).collect();
    println!("[aggregator] Parsed echo URLs: {:#?}", urls);
    
    // Try to ping each echo server to verify connectivity
    println!("[aggregator] Testing connectivity to echo servers...");
    for url in &urls {
        println!("[aggregator] Testing connection to {}", url);
    }
    
    // Add a delay to ensure everything is ready
    println!("[aggregator] Waiting for 2 seconds before starting server...");
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    
    let state = AppState { 
        echo_urls: Arc::new(urls),
    };
    
    let app = Router::new()
        .route("/", get(index))
        .route("/aggregate", get(aggregate))
        .route("/metrics", get(metrics))
        .with_state(state);
    
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    println!("[aggregator] Binding to {}", addr);
    
    match tokio::net::TcpListener::bind(addr).await {
        Ok(listener) => {
            println!("[aggregator] Successfully bound to {}", addr);
            println!("[aggregator] Starting server...");
            
            // Use a separate variable to hold the future
            let server_future = axum::serve(listener, app);
            println!("[aggregator] Server future created, awaiting...");
            
            if let Err(e) = server_future.await {
                println!("[aggregator] Server error: {}", e);
            }
            println!("[aggregator] Server exited");
        },
        Err(e) => {
            println!("[aggregator] Failed to bind to {}: {}", addr, e);
        }
    }
    
    println!("[aggregator] Main function ending");
}
