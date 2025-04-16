# Rust Echo Aggregator

This service asynchronously polls all echo servers, measures their response times, and serves a dynamic HTML page showing the results in real time.

## How it Works
- On each request to `/`, the backend fetches from all echo servers (provided via the `ECHO_URLS` env variable).
- Aggregates responses and timings, and displays them in the browser via JavaScript.

## Build & Run (Locally)
1. Install Rust and Cargo.
2. Set the echo URLs (e.g., `export ECHO_URLS="http://echo-1:5678,http://echo-2:5678,http://echo-3:5678"`)
3. Run:
   ```sh
   cargo run --release
   ```
4. Open http://localhost:3000

## Docker
1. Build the image:
   ```sh
   docker build -t aggregator .
   ```
2. Run the container (with echo servers already running):
   ```sh
   docker run -e ECHO_URLS="http://echo-1:5678,http://echo-2:5678,http://echo-3:5678" -p 3000:3000 aggregator
   ```

## Terraform Integration
- The aggregator will be deployed as a container alongside the echo servers.
- The `ECHO_URLS` environment variable will be set automatically by Terraform.
