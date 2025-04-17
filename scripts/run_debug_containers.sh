#!/bin/bash
set -e

echo "=== Stopping any existing containers ==="
docker stop local-echo-1 local-echo-2 aggregator 2>/dev/null || true
docker rm local-echo-1 local-echo-2 aggregator 2>/dev/null || true

echo "=== Starting echo server containers ==="
docker run -d --name local-echo-1 -p 5001:5678 hashicorp/http-echo -text="Hello from Local Echo 1!"
docker run -d --name local-echo-2 -p 5002:5678 hashicorp/http-echo -text="Hello from Local Echo 2!"

echo "=== Creating docker network if it doesn't exist ==="
docker network create debug-net 2>/dev/null || true

echo "=== Connecting echo servers to network ==="
docker network connect debug-net local-echo-1 || true
docker network connect debug-net local-echo-2 || true

echo "=== Building aggregator container ==="
cd "$(dirname "$0")/../services/aggregator"
docker build -t aggregator:debug .

echo "=== Starting aggregator container ==="
docker run -d --name aggregator \
  --network debug-net \
  -p 3000:3000 \
  -e ECHO_URLS="http://local-echo-1:5678,http://local-echo-2:5678" \
  aggregator:debug

echo "=== Container Status ==="
docker ps | grep -E 'local-echo|aggregator'

echo "=== Waiting for aggregator to start ==="
for i in {1..7}; do
  sleep 1
  echo -n "."
done
echo

echo "=== Aggregator Logs ==="
docker logs aggregator

echo "=== Test Command ==="
echo "curl http://localhost:3000/metrics"
