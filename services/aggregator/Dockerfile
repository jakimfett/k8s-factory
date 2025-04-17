# Start from the official Rust image for building
FROM rust:1.81 AS builder
WORKDIR /usr/src/aggregator

# Set environment variables for debug builds
ENV RUSTFLAGS="-C debuginfo=2"
ENV RUST_LOG=debug
ENV RUST_BACKTRACE=full

# Cache dependencies
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release || true

# Now copy the rest of the source and build the real binary
COPY . .
RUN cargo build --release

# Use a minimal base image for running
FROM debian:bookworm-slim
WORKDIR /app

# Install required dependencies plus troubleshooting tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 ca-certificates procps net-tools curl strace \
    lsof iproute2 && \
    rm -rf /var/lib/apt/lists/*

# Create a robust wrapper script with comprehensive checks and debugging
RUN echo '#!/bin/bash\n\
set -x\n\
echo "[wrapper] Container started at $(date)"\n\
\n\
# Check for restart loop detection\n\
RESTART_MARKER_FILE="/tmp/restart_count"\n\
MAX_RESTARTS=5\n\
\n\
if [ -f "$RESTART_MARKER_FILE" ]; then\n\
  RESTART_COUNT=$(cat "$RESTART_MARKER_FILE")\n\
  RESTART_COUNT=$((RESTART_COUNT + 1))\n\
  echo "[wrapper] ⚠️ Container has been restarted $RESTART_COUNT times"\n\
  echo $RESTART_COUNT > "$RESTART_MARKER_FILE"\n\
  \n\
  # Check if we\'ve exceeded the restart limit\n\
  if [ $RESTART_COUNT -gt $MAX_RESTARTS ]; then\n\
    echo "[wrapper] 🛑 CRITICAL ERROR: Container has restarted $RESTART_COUNT times, exceeding limit of $MAX_RESTARTS"\n\
    echo "[wrapper] 🛑 Refusing to restart again to prevent endless restart loop"\n\
    echo "[wrapper] 🛑 Container logs may contain the root cause of the problem"\n\
    echo "[wrapper] 🛑 Sleeping for 300 seconds for diagnostics before exiting"\n\
    # Sleep for 5 minutes to allow diagnostic access before giving up\n\
    sleep 300\n\
    exit 1\n\
  fi\n\
else\n\
  # First run\n\
  echo 1 > "$RESTART_MARKER_FILE"\n\
  echo "[wrapper] First container start"\n\
fi\n\
\n\
echo "[wrapper] Network configuration:"\n\
ip addr\n\
echo "[wrapper] Process list before starting aggregator:"\n\
ps aux\n\
echo "[wrapper] Open ports:"\n\
netstat -tuln\n\
\n\
# Check if port 3000 is already in use\n\
if netstat -tuln | grep -q ":3000 "; then\n\
  echo "[wrapper] 🛑 CRITICAL ERROR: Port 3000 is already in use by another process"\n\
  echo "[wrapper] 🛑 Network port details:"\n\
  netstat -tuln | grep ":3000 "\n\
  echo "[wrapper] 🛑 This will prevent the aggregator from starting properly"\n\
  echo "[wrapper] 🛑 Sleeping for 300 seconds for diagnostics before exiting"\n\
  # Sleep for 5 minutes to allow diagnostic access before giving up\n\
  sleep 300\n\
  exit 1\n\
fi\n\
\n\
echo "[wrapper] Environment variables:"\n\
env | sort\n\
\n\
# Validate required environment variables\n\
if [ -z "$ECHO_URLS" ]; then\n\
  echo "[wrapper] 🛑 CRITICAL ERROR: ECHO_URLS environment variable is not set"\n\
  echo "[wrapper] 🛑 Aggregator cannot function without echo servers"\n\
  echo "[wrapper] 🛑 Sleeping for 300 seconds for diagnostics before exiting"\n\
  # Sleep for 5 minutes to allow diagnostic access before giving up\n\
  sleep 300\n\
  exit 1\n\
fi\n\
\n\
# Extract echo URLs from environment variable\n\
IFS="," read -ra ECHO_URL_ARRAY <<< "$ECHO_URLS"\n\
echo "[wrapper] Found ${#ECHO_URL_ARRAY[@]} echo servers to connect to"\n\
\n\
# Function to check if echo servers are available\n\
check_echo_servers() {\n\
  local all_available=true\n\
  for url in "${ECHO_URL_ARRAY[@]}"; do\n\
    echo "[wrapper] Checking echo server: $url"\n\
    if curl -s -f -m 1 "$url" > /dev/null 2>&1; then\n\
      echo "[wrapper] Echo server $url is available"\n\
    else\n\
      echo "[wrapper] Echo server $url is not available yet"\n\
      all_available=false\n\
    fi\n\
  done\n\
  $all_available\n\
}\n\
\n\
# Retry logic for connecting to echo servers\n\
MAX_RETRIES=3\n\
RETRY_COUNT=0\n\
RETRY_DELAY=2\n\
\n\
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do\n\
  echo "[wrapper] Checking echo server availability (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"\n\
  if check_echo_servers; then\n\
    echo "[wrapper] All echo servers are available. Starting aggregator service."\n\
    break\n\
  else\n\
    RETRY_COUNT=$((RETRY_COUNT+1))\n\
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then\n\
      echo "[wrapper] Waiting ${RETRY_DELAY}s before retry..."\n\
      sleep $RETRY_DELAY\n\
      # Increase delay for next attempt (exponential backoff)\n\
      RETRY_DELAY=$((RETRY_DELAY*2))\n\
    else\n\
      echo "[wrapper] Warning: Not all echo servers are available after $MAX_RETRIES attempts."\n\
      echo "[wrapper] Starting aggregator anyway - it will handle connection failures gracefully."\n\
    fi\n\
  fi\n\
done\n\
\n\
echo "[wrapper] Starting aggregator service with full debugging"\n\
# Clear restart count file if we\'ve made it to the actual service start\n\
rm -f "$RESTART_MARKER_FILE"\n\
exec /app/aggregator' > /app/start.sh && \
    chmod +x /app/start.sh

# Copy the aggregator binary
COPY --from=builder /usr/src/aggregator/target/release/aggregator /app/aggregator

# Set environment variables for maximum debugging
ENV RUST_BACKTRACE=full
ENV RUST_LOG=debug,aggregator=trace,tokio=debug,hyper=debug,tower=debug
ENV DEBIAN_FRONTEND=noninteractive

# Port configuration
EXPOSE 3000

# Start with the debugging wrapper
CMD ["/bin/bash", "-c", "/app/start.sh"]

# Health check to verify process is running
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep -f aggregator || exit 1
