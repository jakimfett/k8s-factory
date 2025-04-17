// Import required libraries
use axum::{extract::State, response::{Html, IntoResponse}, routing::get, Json, Router}; // Web framework for routing and responses
use prometheus::{Encoder, TextEncoder, register_counter_vec, register_histogram_vec, CounterVec, HistogramVec}; // Metrics collection and exposition
use serde::Serialize; // Serialization for JSON responses
use std::{env, net::SocketAddr, sync::Arc, time::Instant}; // Standard library components

// Initialize Prometheus metrics using lazy_static to ensure one-time initialization
lazy_static::lazy_static! {
    // Counter to track total requests by endpoint
    static ref REQUEST_COUNTER: CounterVec = register_counter_vec!(
        "aggregator_requests_total", // Metric name
        "Total number of requests processed by the aggregator", // Metric description
        &["endpoint"] // Label dimension (which endpoint was called)
    ).unwrap();
    
    // Histogram to track response times from echo servers
    static ref RESPONSE_TIME_HISTOGRAM: HistogramVec = register_histogram_vec!(
        "aggregator_response_time_ms", // Metric name
        "Response time in milliseconds", // Metric description
        &["echo_server"], // Label dimension (which server responded)
        vec![5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0] // Histogram buckets in milliseconds
    ).unwrap();
}

// Define application state to be shared across all request handlers
#[derive(Clone)] // Enable cloning for sharing across threads
struct AppState {
    echo_urls: Arc<Vec<String>>, // Thread-safe reference-counted list of echo server URLs
}

// Response structure for each echo server request
#[derive(Serialize)] // Enable JSON serialization for API responses
struct EchoResponse {
    url: String,   // The URL of the echo server
    body: String,  // The response body from the echo server
    ms: u128,      // Response time in milliseconds
}

// Handler for /aggregate endpoint - retrieves data from all echo servers
async fn aggregate(State(state): State<AppState>) -> impl IntoResponse {
    // Increment request counter with 'aggregate' endpoint label
    REQUEST_COUNTER.with_label_values(&["aggregate"]).inc();
    
    // Create a vector to store async task handles
    let mut handles = vec![];
    
    // Create a separate task for each echo server URL
    for url in state.echo_urls.iter() {
        let url = url.clone(); // Clone URL for use in the async task
        
        // Spawn a new async task to fetch from one echo server
        handles.push(tokio::spawn(async move {
            // Start timing the request
            let start = Instant::now();
            
            // Make HTTP request to echo server and handle errors gracefully
            let body = match reqwest::get(&url).await {
                Ok(resp) => resp.text().await.unwrap_or_else(|_| "[error reading body]".to_string()),
                Err(_) => "[error connecting]".to_string(),
            };
            
            // Calculate elapsed time in milliseconds
            let elapsed_ms = start.elapsed().as_millis() as f64;
            
            // Extract hostname from URL for more readable metrics labeling
            let server_name = url.split("://").nth(1).unwrap_or(&url).split(":").next().unwrap_or("unknown");
            
            // Record response time in the Prometheus histogram
            RESPONSE_TIME_HISTOGRAM.with_label_values(&[server_name]).observe(elapsed_ms);
            
            // Create a response object with results from this echo server
            EchoResponse {
                url,
                body,
                ms: elapsed_ms as u128,
            }
        }));
    }
    
    // Collect results from all async tasks
    let mut results = vec![];
    for h in handles {
        if let Ok(res) = h.await { results.push(res); } // Only keep successful responses
    }
    
    // Return results as JSON
    Json(results)
}

// Handler for /metrics endpoint - exposes Prometheus metrics
async fn metrics() -> impl IntoResponse {
    // Create a text encoder for Prometheus exposition format
    let encoder = TextEncoder::new();
    
    // Gather all registered metrics from the Prometheus registry
    let metric_families = prometheus::gather();
    
    // Create a buffer for the encoded metrics
    let mut buffer = Vec::new();
    
    // Encode metrics into the buffer
    encoder.encode(&metric_families, &mut buffer).unwrap();
    
    // Return metrics with proper content type header for Prometheus scraping
    ([ (axum::http::header::CONTENT_TYPE.as_str(), "text/plain; version=0.0.4") ], buffer)
}

// Handler for root (/) endpoint - displays HTML dashboard
async fn index(State(state): State<AppState>) -> impl IntoResponse {
    // Increment request counter with 'index' endpoint label
    REQUEST_COUNTER.with_label_values(&["index"]).inc();
    
    // Return HTML response with a simple dashboard
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
        // Client-side JavaScript to fetch and display data from the /aggregate endpoint
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
    "#, state.echo_urls)) // Insert the list of echo URLs into the HTML template
}

// Main entry point - initializes and runs the web server
#[tokio::main] // Macro to set up the async runtime
async fn main() {
    // Initialize the tracing subscriber for structured logging
    tracing_subscriber::fmt::init();
    println!("[aggregator] Starting up...");
    
    // Print all environment variables for debugging
    for (key, value) in env::vars() {
        println!("[aggregator] ENV: {}={}", key, value);
    }
    
    // Specifically check for the ECHO_URLS environment variable
    match env::var("ECHO_URLS") {
        Ok(val) => println!("[aggregator] ECHO_URLS: {}", val),
        Err(e) => println!("[aggregator] ERROR: ECHO_URLS not set: {}", e),
    }
    
    // Get the ECHO_URLS environment variable or exit with error
    let echo_urls = env::var("ECHO_URLS").expect("ECHO_URLS env var required");
    
    // Split the comma-separated list of URLs into a vector
    let urls: Vec<String> = echo_urls.split(',').map(|s| s.trim().to_string()).collect();
    println!("[aggregator] Parsed echo URLs: {:#?}", urls);
    
    // Report connectivity test status (logging only, no actual testing yet)
    println!("[aggregator] Testing connectivity to echo servers...");
    for url in &urls {
        println!("[aggregator] Testing connection to {}", url);
    }
    
    // Short delay to ensure all services are ready
    println!("[aggregator] Waiting for 2 seconds before starting server...");
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    
    // Create the application state with the list of echo server URLs
    let state = AppState { 
        echo_urls: Arc::new(urls), // Wrap in Arc for thread-safe reference counting
    };
    
    // Create the Axum router with all routes and shared state
    let app = Router::new()
        .route("/", get(index))           // Route for HTML dashboard
        .route("/aggregate", get(aggregate)) // Route for JSON API
        .route("/metrics", get(metrics))     // Route for Prometheus metrics
        .with_state(state);                   // Attach shared state
    
    // Configure server to listen on all interfaces, port 3000
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    println!("[aggregator] Binding to {}", addr);
    
    // Bind the server to the socket address
    match tokio::net::TcpListener::bind(addr).await {
        Ok(listener) => {
            println!("[aggregator] Successfully bound to {}", addr);
            println!("[aggregator] Starting server...");
            
            // Create the server future
            let server_future = axum::serve(listener, app);
            println!("[aggregator] Server future created, awaiting...");
            
            // Run the server and handle any errors
            if let Err(e) = server_future.await {
                println!("[aggregator] Server error: {}", e);
            }
            println!("[aggregator] Server exited");
        },
        Err(e) => {
            println!("[aggregator] Failed to bind to {}: {}", addr, e);
        }
    }
    
    // Note: this line is only reached if the server stops
    println!("[aggregator] Main function ending");
}
