# Start from the official Rust image for building
FROM rust:1.81 AS builder
WORKDIR /usr/src/aggregator

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

# Create a simple wrapper script
RUN echo '#!/bin/bash\necho "[wrapper] Starting aggregator service"\n/app/aggregator' > /app/start.sh && \
    chmod +x /app/start.sh

# Install required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy the aggregator binary
COPY --from=builder /usr/src/aggregator/target/release/aggregator /app/aggregator

# Set environment variables for logging
ENV RUST_BACKTRACE=1

# Expose port
EXPOSE 3000

# Set container to be interactive with TTY allocation
ENV DEBIAN_FRONTEND=noninteractive

# Use the wrapper script
CMD ["/app/start.sh"]
