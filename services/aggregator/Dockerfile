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

# Create a robust wrapper script with debugging
RUN echo '#!/bin/bash\n\
set -x\n\
echo "[wrapper] Container started at $(date)"\n\
echo "[wrapper] Network configuration:"\n\
ip addr\n\
echo "[wrapper] Process list before starting aggregator:"\n\
ps aux\n\
echo "[wrapper] Open ports:"\n\
netstat -tuln\n\
echo "[wrapper] Environment variables:"\n\
env | sort\n\
echo "[wrapper] Starting aggregator service with full debugging"\n\
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
