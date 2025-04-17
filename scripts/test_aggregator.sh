#!/bin/bash

# Default to non-verbose mode
VERBOSE=false

# Process command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-v|--verbose]"
      exit 1
      ;;
  esac
done

# Colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Print test header
echo_header() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}    Aggregator Test Suite${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
}

# Run a test and check the result
run_test() {
  local test_name="$1"
  local test_command="$2"
  local expected_result="$3"
  
  ((TESTS_TOTAL++))
  
  # In non-verbose mode, we only print a dot for each test to indicate progress
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${YELLOW}Running test:${NC} $test_name"
  else
    # Print a dot without newline to show progress
    echo -n "."
  fi
  
  # Capture command output for verbose mode
  if [[ "$VERBOSE" == "true" ]]; then
    if eval "$test_command"; then
      echo -e "${GREEN}✓ PASS:${NC} $test_name"
      ((TESTS_PASSED++))
      return 0
    else
      echo -e "${RED}✗ FAIL:${NC} $test_name"
      echo -e "${YELLOW}Expected:${NC} $expected_result"
      ((TESTS_FAILED++))
      return 1
    fi
  else
    # Suppress command output in non-verbose mode
    if eval "$test_command &> /dev/null"; then
      ((TESTS_PASSED++))
      return 0
    else
      # In case of failure, print a newline and the failure info even in non-verbose mode
      echo ""
      echo -e "${RED}✗ FAIL:${NC} $test_name"
      echo -e "${YELLOW}Expected:${NC} $expected_result"
      ((TESTS_FAILED++))
      return 1
    fi
  fi
}

# Test suite: Debug Script Functionality
test_debug_script() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Debug Script Functionality${NC}"
  fi
  
  # Create verbose flag for container script if needed
  VERBOSE_FLAG=""
  if [[ "$VERBOSE" == "true" ]]; then
    VERBOSE_FLAG="--verbose"
  fi
  
  # Test stop functionality
  run_test "Debug containers can be stopped" \
    "./scripts/run_debug_containers.sh $VERBOSE_FLAG --stop &>/dev/null && ! docker ps | grep -q -E 'local-echo|aggregator'" \
    "All debug containers to be stopped"
  
  # Test start functionality
  run_test "Debug containers can be started" \
    "./scripts/run_debug_containers.sh $VERBOSE_FLAG --start &>/dev/null && docker ps | grep -q 'aggregator' && docker ps | grep -q 'local-echo-1' && docker ps | grep -q 'local-echo-2'" \
    "All debug containers to be running"
  
  # Test restart functionality
  run_test "Debug containers can be restarted" \
    "./scripts/run_debug_containers.sh $VERBOSE_FLAG --restart &>/dev/null && docker ps | grep -q 'aggregator'" \
    "All debug containers to be restarted and running"
}

# Test suite: Aggregator Online Status
test_aggregator_online() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Aggregator Online Status${NC}"
  fi
  
  # Check if aggregator container is running
  run_test "Aggregator container is running" \
    "docker ps -q | grep -q $(docker ps -qf name=aggregator) 2>/dev/null" \
    "Aggregator container to be running"
  
  # Check if aggregator is accepting HTTP connections
  run_test "Aggregator HTTP endpoint is responding" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/ 2>/dev/null | grep -q '200'" \
    "HTTP 200 response from aggregator endpoint"
  
  # Check if aggregator process is healthy according to container health check
  run_test "Aggregator container health check" \
    "docker inspect --format='{{.State.Health.Status}}' aggregator 2>/dev/null | grep -q 'healthy'" \
    "Container health check to report 'healthy'"
}

# Test suite: Echo Server Connectivity
test_echo_connectivity() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Echo Server Connectivity${NC}"
  fi
  
  # Get the list of echo servers the aggregator should be connected to
  run_test "Echo servers are running" \
    "docker ps -q | grep -q $(docker ps -qf name=local-echo-1) && docker ps -q | grep -q $(docker ps -qf name=local-echo-2) 2>/dev/null" \
    "All echo server containers to be running"
  
  # Check if aggregator can reach all echo servers
  if [[ "$VERBOSE" == "true" ]]; then
    run_test "Aggregator connects to all echo servers" \
      "curl -s http://localhost:3000/aggregate | jq -e 'length == 2'" \
      "Response from /aggregate endpoint to contain responses from 2 echo servers"
  else
    run_test "Aggregator connects to all echo servers" \
      "curl -s http://localhost:3000/aggregate 2>/dev/null | jq -e 'length == 2' 2>/dev/null" \
      "Response from /aggregate endpoint to contain responses from 2 echo servers"
  fi
  
  # Verify echo server responses are included in the aggregator response
  if [[ "$VERBOSE" == "true" ]]; then
    run_test "Echo server responses are included in aggregator output" \
      "curl -s http://localhost:3000/aggregate | jq -e 'map(.body) | .[] | contains(\"Hello from\")'" \
      "Aggregator responses to contain echo server messages"
  else
    run_test "Echo server responses are included in aggregator output" \
      "curl -s http://localhost:3000/aggregate 2>/dev/null | jq -e 'map(.body) | .[] | contains(\"Hello from\")' 2>/dev/null" \
      "Aggregator responses to contain echo server messages"
  fi
}

# Test suite: Metrics Availability
test_metrics_availability() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Metrics Availability${NC}"
  fi
  
  # Check if metrics endpoint is accessible
  run_test "Metrics endpoint is accessible" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/metrics 2>/dev/null | grep -q '200'" \
    "HTTP 200 response from metrics endpoint"
  
  # Verify request counter metric exists
  run_test "Request counter metrics exist" \
    "curl -s http://localhost:3000/metrics 2>/dev/null | grep -q 'aggregator_requests_total'" \
    "Metrics to include request counter"
  
  # Verify response time histogram metric exists
  run_test "Response time histogram metrics exist" \
    "curl -s http://localhost:3000/metrics 2>/dev/null | grep -q 'aggregator_response_time_ms'" \
    "Metrics to include response time histogram"
  
  # Verify metrics are properly formatted
  run_test "Metrics are in Prometheus format" \
    "curl -s http://localhost:3000/metrics 2>/dev/null | grep -q '# HELP'" \
    "Metrics to follow Prometheus exposition format"
}

# Run all test suites
run_all_tests() {
  echo_header
  
  # Ensure we start with a clean slate
  if [[ "$VERBOSE" == "true" ]]; then
    ./scripts/run_debug_containers.sh --stop
  else
    ./scripts/run_debug_containers.sh --stop >/dev/null 2>&1
  fi
  
  # In non-verbose mode, print start message
  if [[ "$VERBOSE" == "false" ]]; then
    echo -e "Running tests"
  fi
  
  # Run test suites
  test_debug_script
  test_aggregator_online
  test_echo_connectivity
  test_metrics_availability
  
  # In non-verbose mode, print a newline after dots
  if [[ "$VERBOSE" == "false" ]]; then
    echo ""
  fi
  
  # Print test summary
  echo -e "\n${BLUE}=======================================${NC}"
  echo -e "${BLUE}    Test Summary${NC}"
  echo -e "${BLUE}=======================================${NC}"
  echo -e "Total tests: ${TESTS_TOTAL}"
  echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
  echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
  
  # Return non-zero exit code if any tests failed
  if [ ${TESTS_FAILED} -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

# Display usage information
show_usage() {
  echo "Usage: $0 [-v|--verbose]"
  echo ""
  echo "Options:"
  echo "  -v, --verbose    Enable verbose output (shows detailed test progress)"
  echo ""
  echo "Default mode shows minimal output with dots indicating test progress."
  echo "Use verbose mode for debugging or to see detailed test output."
  echo ""
  echo "Examples:"
  echo "  $0              # Run tests with minimal output"
  echo "  $0 --verbose    # Run tests with detailed output"
}

# Only run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Check dependencies
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Please install jq with: brew install jq"
    exit 1
  fi
  
  run_all_tests
  exit $?
else
  # This is for when the script is sourced rather than executed directly
  echo "Available test suites:"
  echo "  test_debug_script        - Tests container start/stop/restart"
  echo "  test_aggregator_online   - Tests aggregator service status"
  echo "  test_echo_connectivity   - Tests echo server connectivity"
  echo "  test_metrics_availability - Tests Prometheus metrics"
  echo "  run_all_tests           - Runs all test suites"
  echo ""
  echo "Run './scripts/test_aggregator.sh -v' for verbose test output"
  echo "Run './scripts/test_aggregator.sh' for minimal output (dots only)"
fi
