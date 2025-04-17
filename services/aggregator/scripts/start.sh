#!/bin/bash
set -x

echo "[wrapper] Container started at $(date)"

# Check for restart loop detection
RESTART_MARKER_FILE="/tmp/restart_count"
MAX_RESTARTS=5

if [ -f "$RESTART_MARKER_FILE" ]; then
  RESTART_COUNT=$(cat "$RESTART_MARKER_FILE")
  RESTART_COUNT=$((RESTART_COUNT + 1))
  echo "[wrapper] ⚠️ Container has been restarted $RESTART_COUNT times"
  echo $RESTART_COUNT > "$RESTART_MARKER_FILE"
  
  # Check if we've exceeded the restart limit
  if [ $RESTART_COUNT -gt $MAX_RESTARTS ]; then
    echo "[wrapper] 🛑 CRITICAL ERROR: Container has restarted $RESTART_COUNT times, exceeding limit of $MAX_RESTARTS"
    echo "[wrapper] 🛑 Refusing to restart again to prevent endless restart loop"
    echo "[wrapper] 🛑 Container logs may contain the root cause of the problem"
    echo "[wrapper] 🛑 Sleeping for 300 seconds for diagnostics before exiting"
    # Sleep for 5 minutes to allow diagnostic access before giving up
    sleep 300
    exit 1
  fi
else
  # First run
  echo 1 > "$RESTART_MARKER_FILE"
  echo "[wrapper] First container start"
fi

echo "[wrapper] Network configuration:"
ip addr
echo "[wrapper] Process list before starting aggregator:"
ps aux
echo "[wrapper] Open ports:"
netstat -tuln

# Check if port 3000 is already in use
if netstat -tuln | grep -q ":3000 "; then
  echo "[wrapper] 🛑 CRITICAL ERROR: Port 3000 is already in use by another process"
  echo "[wrapper] 🛑 Network port details:"
  netstat -tuln | grep ":3000 "
  echo "[wrapper] 🛑 This will prevent the aggregator from starting properly"
  echo "[wrapper] 🛑 Sleeping for 300 seconds for diagnostics before exiting"
  # Sleep for 5 minutes to allow diagnostic access before giving up
  sleep 300
  exit 1
fi

echo "[wrapper] Environment variables:"
env | sort

# Validate required environment variables
if [ -z "$ECHO_URLS" ]; then
  echo "[wrapper] 🛑 CRITICAL ERROR: ECHO_URLS environment variable is not set"
  echo "[wrapper] 🛑 Aggregator cannot function without echo servers"
  echo "[wrapper] 🛑 Sleeping for 300 seconds for diagnostics before exiting"
  # Sleep for 5 minutes to allow diagnostic access before giving up
  sleep 300
  exit 1
fi

# Extract echo URLs from environment variable
IFS="," read -ra ECHO_URL_ARRAY <<< "$ECHO_URLS"
echo "[wrapper] Found ${#ECHO_URL_ARRAY[@]} echo servers to connect to"

# Set defaults for configurable environment variables
: ${MAX_RETRIES:=3}
: ${RETRY_DELAY:=2}
: ${STARTUP_DELAY:=0}

# Add optional startup delay to allow for network setup
if [ "$STARTUP_DELAY" -gt 0 ]; then
  echo "[wrapper] Waiting $STARTUP_DELAY seconds for network to stabilize..."
  sleep "$STARTUP_DELAY"
fi

# Function to check if echo servers are available
check_echo_servers() {
  local all_available=true
  for url in "${ECHO_URL_ARRAY[@]}"; do
    echo "[wrapper] Checking echo server: $url"
    if curl -s -f -m 2 "$url" > /dev/null 2>&1; then
      echo "[wrapper] Echo server $url is available"
    else
      echo "[wrapper] Echo server $url is not available yet"
      all_available=false
    fi
  done
  $all_available
}

# DNS troubleshooting if needed
echo "[wrapper] Network DNS resolution test:"
for url in "${ECHO_URL_ARRAY[@]}"; do
  # Extract hostname from URL
  host="$(echo "$url" | sed -e 's|^[^/]*//||' -e 's|:.*$||' -e 's|/.*$||')"
  echo "[wrapper] Resolving hostname: $host"
  nslookup "$host" || echo "[wrapper] DNS resolution failed for $host"
done

# Retry for echo servers to come online
RETRY_COUNT=0
ORIGINAL_DELAY="$RETRY_DELAY"

while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
  echo "[wrapper] Checking echo server availability (attempt $(($RETRY_COUNT+1))/$MAX_RETRIES)"
  if check_echo_servers; then
    echo "[wrapper] All echo servers are available. Starting aggregator service."
    break
  fi
  
  RETRY_COUNT=$(($RETRY_COUNT+1))
  
  if [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; then
    echo "[wrapper] Some echo servers not available. Retrying in $RETRY_DELAY seconds..."
    sleep "$RETRY_DELAY"
    # Increase delay for exponential backoff, but cap at 30 seconds
    RETRY_DELAY=$(($RETRY_DELAY*2))
    if [ "$RETRY_DELAY" -gt 30 ]; then
      RETRY_DELAY=30
    fi
  fi
done

# Continue even if not all servers are available
if [ "$RETRY_COUNT" -eq "$MAX_RETRIES" ]; then
  echo "[wrapper] Warning: Not all echo servers are available after $MAX_RETRIES attempts."
  echo "[wrapper] Starting aggregator anyway - it will handle connection failures gracefully."
fi

echo "[wrapper] Starting aggregator service with full debugging"
# Clear restart count file if we've made it to the actual service start
rm -f "$RESTART_MARKER_FILE"
exec /app/aggregator
