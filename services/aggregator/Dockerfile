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
RUN apt-get update && apt-get install -y --no-install-recommends libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/src/aggregator/target/release/aggregator /app/aggregator
EXPOSE 3000
#CMD ["/app/aggregator"]
CMD ["/bin/sh", "-c", "echo 'got here'; sleep 3;/app/aggregator; echo 'got after'; sleep 6"]
