#!/bin/bash

# Print script banner
echo_banner() {
  echo "==================================="
  echo "     Container Debug Environment   "
  echo "==================================="
  echo ""
}

# Display help message
show_help() {
  echo -e "Usage: \n\t$0 [-s | --start] [-q | --stop] [-r | --restart] [-h | --help]"
  echo ""
  echo "Options:"
  echo "  -s, --start     Start the debug containers"
  echo "  -q, --stop      Stop and remove the debug containers"
  echo "  -r, --restart   Restart the debug containers"
  echo "  -h, --help      Display this help message"
  echo ""
  echo "Example:"
  echo "  $0 -s     # Start the echo servers and aggregator"
  echo ""
}

# Stop and remove containers
stop_containers() {
  echo "=== Stopping any existing containers ==="
  docker stop local-echo-1 local-echo-2 aggregator 2>/dev/null || true
  docker rm local-echo-1 local-echo-2 aggregator 2>/dev/null || true
  echo "=== Containers stopped and removed ==="
}

# Start all containers
start_containers() {
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
  for i in {7..1}; do
    sleep 1
    echo -n "${i}..."
  done
  echo


  echo "=== Aggregator Logs ==="
  docker logs aggregator

  echo "=== Test Command ==="
  echo "curl http://localhost:3000/metrics"
}

# Restart all containers
restart_containers() {
  stop_containers
  start_containers
}

# Main logic based on arguments
if [ $# -eq 0 ]; then
  show_help
  exit 1
fi

case "$1" in
  -s | --start)
    echo_banner
    start_containers
    ;;
  -q | --stop)
    echo_banner
    stop_containers
    ;;
  -r | --restart)
    echo_banner
    restart_containers
    ;;
  -h | --help)
    show_help
    ;;
  *)
    echo_banner
    echo "Invalid option: $1"
    show_help
    exit 1
    ;;
esac
