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

# Test counters and timing
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_START_TIME=0
TEST_TOTAL_TIME=0
SUITE_START_TIME=0

# Get time in milliseconds
get_time_ms() {
  echo $(($(date +%s%N)/1000000))
}

# Format milliseconds to a readable time format
format_time() {
  local ms=$1
  local seconds=$((ms / 1000))
  local milliseconds=$((ms % 1000))
  
  if [[ $seconds -ge 60 ]]; then
    local minutes=$((seconds / 60))
    seconds=$((seconds % 60))
    echo "${minutes}m ${seconds}.${milliseconds}s"
  else
    echo "${seconds}.${milliseconds}s"
  fi
}

# Print test header
echo_header() {
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}    Test Suite for the echo server Aggregator${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo ""
}

# Run a test and check the result
run_test() {
  local test_name="$1"
  local test_command="$2"
  local expected_result="$3"
  
  ((TESTS_TOTAL++))
  
  # Start timing the test
  TEST_START_TIME=$(get_time_ms)
  
  # Extract a short test name for non-verbose mode (up to 20 chars)
  local short_name="${test_name:0:20}"
  # If truncated, add ellipsis
  if [[ ${#test_name} -gt 20 ]]; then
    short_name="${short_name}..."
  fi
  
  # In verbose mode, show detailed test info, in non-verbose show compact version
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${YELLOW}Running test:${NC} $test_name"
  else
    # Print the short test name without a newline
    echo -n "[${short_name}] "
  fi
  
  # Capture command output for verbose mode
  if [[ "$VERBOSE" == "true" ]]; then
    if eval "$test_command"; then
      # Calculate test execution time
      local end_time=$(get_time_ms)
      local execution_time=$((end_time - TEST_START_TIME))
      TEST_TOTAL_TIME=$((TEST_TOTAL_TIME + execution_time))
      
      echo -e "${GREEN}✓ PASS:${NC} $test_name ($(format_time $execution_time))"
      ((TESTS_PASSED++))
      return 0
    else
      # Calculate test execution time
      local end_time=$(get_time_ms)
      local execution_time=$((end_time - TEST_START_TIME))
      TEST_TOTAL_TIME=$((TEST_TOTAL_TIME + execution_time))
      
      echo -e "${RED}✗ FAIL:${NC} $test_name ($(format_time $execution_time))"
      echo -e "${YELLOW}Expected:${NC} $expected_result"
      ((TESTS_FAILED++))
      return 1
    fi
  else
    # Suppress command output in non-verbose mode
    if eval "$test_command &> /dev/null"; then
      # Calculate test execution time
      local end_time=$(get_time_ms)
      local execution_time=$((end_time - TEST_START_TIME))
      TEST_TOTAL_TIME=$((TEST_TOTAL_TIME + execution_time))
      
      # Show pass with execution time in non-verbose mode
      echo -e "${GREEN}✓${NC} ($(format_time $execution_time))"
      
      ((TESTS_PASSED++))
      return 0
    else
      # Calculate test execution time
      local end_time=$(get_time_ms)
      local execution_time=$((end_time - TEST_START_TIME))
      TEST_TOTAL_TIME=$((TEST_TOTAL_TIME + execution_time))
      
      # Show failure with execution time in non-verbose mode
      echo -e "${RED}✗${NC} ($(format_time $execution_time))"
      echo -e "${RED}FAIL:${NC} $test_name"
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
  if [[ "$VERBOSE" == "true" ]]; then
    run_test "Debug containers can be stopped" \
      "./scripts/run_debug_containers.sh --stop && ! docker ps | grep -q -E 'local-echo|aggregator'" \
      "All debug containers to be stopped"
  else
    run_test "Debug containers can be stopped" \
      "./scripts/run_debug_containers.sh --stop &>/dev/null && ! docker ps | grep -q -E 'local-echo|aggregator'" \
      "All debug containers to be stopped"
  fi
  
  # Test start functionality
  if [[ "$VERBOSE" == "true" ]]; then
    run_test "Debug containers can be started" \
      "./scripts/run_debug_containers.sh --start && docker ps | grep -q 'aggregator' && docker ps | grep -q 'local-echo-1' && docker ps | grep -q 'local-echo-2'" \
      "All debug containers to be running"
  else
    run_test "Debug containers can be started" \
      "./scripts/run_debug_containers.sh --start &>/dev/null && docker ps | grep -q 'aggregator' && docker ps | grep -q 'local-echo-1' && docker ps | grep -q 'local-echo-2'" \
      "All debug containers to be running"
  fi
  
  # Test restart functionality
  if [[ "$VERBOSE" == "true" ]]; then
    run_test "Debug containers can be restarted" \
      "./scripts/run_debug_containers.sh --restart && docker ps | grep -q 'aggregator'" \
      "All debug containers to be restarted and running"
  else
    run_test "Debug containers can be restarted" \
      "./scripts/run_debug_containers.sh --restart &>/dev/null && docker ps | grep -q 'aggregator'" \
      "All debug containers to be restarted and running"
  fi
}

# Test suite: Aggregator Online Status
test_aggregator_online() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Aggregator Online Status${NC}"
  fi
  
  # Check if aggregator container is running
  run_test "Aggregator container is running" \
    "docker ps | grep -q 'aggregator'" \
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
    "docker ps | grep -q 'local-echo-1' && docker ps | grep -q 'local-echo-2'" \
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
      "curl -s http://localhost:3000/aggregate | grep -q 'Hello from'" \
      "Aggregator responses to contain echo server messages"
  else
    run_test "Echo server responses are included in aggregator output" \
      "curl -s http://localhost:3000/aggregate 2>/dev/null | grep -q 'Hello from'" \
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
  
  # Reset timing counters
  TEST_TOTAL_TIME=0
  SUITE_START_TIME=$(get_time_ms)
  
  # Ensure we start with a clean slate
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${BLUE}Starting test run at:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
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
  
  # Calculate total run time
  local total_run_time=$(($(get_time_ms) - SUITE_START_TIME))
  
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
  echo -e "\n${BLUE}Timing:${NC}"
  echo -e "Total run time: $(format_time $total_run_time)"
  echo -e "Pure test execution time: $(format_time $TEST_TOTAL_TIME)"
  echo -e "Overhead time: $(format_time $((total_run_time - TEST_TOTAL_TIME)))"
  
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
  
  time run_all_tests
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
