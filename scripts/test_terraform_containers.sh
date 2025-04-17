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
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}    Terraform Container Test Suite    ${NC}"
    echo -e "${BLUE}=======================================${NC}"
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

# Test suite: Echo Server Container Tests
test_echo_servers() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Echo Server Containers${NC}"
  fi
  
  # Test if echo servers are running
  for i in {1..3}; do
    run_test "Echo server $i container is running" \
      "docker ps | grep -q \"echo-$i\"" \
      "Echo server $i container to be running"
    
    # Test if echo server is responding
    run_test "Echo server $i HTTP endpoint is responding" \
      "curl -s -o /dev/null -w '%{http_code}' http://localhost:$((8080 + $i)) | grep -q '200'" \
      "HTTP 200 response from echo server $i endpoint"
    
    # Test if echo server content is correct
    run_test "Echo server $i returns correct content" \
      "curl -s http://localhost:$((8080 + $i)) | grep -q \"Hello from echo-$i\"" \
      "Echo server $i to return correct content"
  done
}

# Test suite: Aggregator Container Tests
test_aggregator() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Aggregator Container${NC}"
  fi
  
  # Test if aggregator container is running
  run_test "Aggregator container is running" \
    "docker ps | grep -q 'aggregator'" \
    "Aggregator container to be running"
  
  # Test if aggregator HTTP endpoint is responding
  run_test "Aggregator HTTP endpoint is responding" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/ | grep -q '200'" \
    "HTTP 200 response from aggregator endpoint"
  
  # Test if aggregator can reach all echo servers
  run_test "Aggregator connects to all echo servers" \
    "curl -s http://localhost:3000/aggregate | grep -q 'echo-1' && curl -s http://localhost:3000/aggregate | grep -q 'echo-2' && curl -s http://localhost:3000/aggregate | grep -q 'echo-3'" \
    "Aggregator to connect to all echo servers"
  
  # Test if aggregator metrics endpoint is available
  run_test "Aggregator metrics endpoint is available" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/metrics | grep -q '200'" \
    "HTTP 200 response from metrics endpoint"
  
  # Test if aggregator metrics have request counters
  run_test "Aggregator metrics have request counters" \
    "curl -s http://localhost:3000/metrics | grep -q 'aggregator_requests_total'" \
    "Metrics to include request counters"
  
  # Test if aggregator metrics have response time histograms
  run_test "Aggregator metrics have response time histograms" \
    "curl -s http://localhost:3000/metrics | grep -q 'aggregator_response_time_ms'" \
    "Metrics to include response time histograms"
}

# Test suite: Prometheus Container Tests
test_prometheus() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Prometheus Container${NC}"
  fi
  
  # Test if prometheus container is running
  run_test "Prometheus container is running" \
    "docker ps | grep -q 'prometheus'" \
    "Prometheus container to be running"
  
  # Test if prometheus web UI is responding
  run_test "Prometheus web UI is accessible" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:9090/ | grep -q '200'" \
    "HTTP 200 response from Prometheus web UI"
  
  # Test if prometheus API is available
  run_test "Prometheus API is available" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:9090/api/v1/status/config | grep -q '200'" \
    "HTTP 200 response from Prometheus API"
  
  # Test if prometheus can scrape the aggregator target
  run_test "Prometheus is scraping aggregator metrics" \
    "curl -s http://localhost:9090/api/v1/targets | grep -q 'aggregator'" \
    "Prometheus to scrape aggregator metrics"
  
  # Test if prometheus has aggregator metrics
  run_test "Prometheus has aggregator metrics data" \
    "curl -s -X POST http://localhost:9090/api/v1/query --data-urlencode 'query=aggregator_requests_total' | grep -q 'result'" \
    "Prometheus to have aggregator metrics data"
}

# Test suite: Grafana Container Tests (if enabled)
test_grafana() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Grafana Container${NC}"
  fi
  
  # Check if Grafana is enabled in terraform variables
  if ! docker ps | grep -q 'grafana'; then
    if [[ "$VERBOSE" == "true" ]]; then
      echo -e "${YELLOW}Grafana is not enabled in Terraform configuration, skipping tests${NC}"
    fi
    return 0
  fi
  
  # Test if grafana container is running
  run_test "Grafana container is running" \
    "docker ps | grep -q 'grafana'" \
    "Grafana container to be running"
  
  # Test if grafana web UI is responding
  run_test "Grafana web UI is accessible" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:3001/ | grep -q '200'" \
    "HTTP 200 response from Grafana web UI"
  
  # Test if grafana API is available (requires authentication)
  run_test "Grafana API is available" \
    "curl -s -o /dev/null -w '%{http_code}' http://admin:admin@localhost:3001/api/health | grep -q '200'" \
    "HTTP 200 response from Grafana API"
  
  # Test if grafana has prometheus data source
  run_test "Grafana has Prometheus data source" \
    "curl -s -u admin:admin http://localhost:3001/api/datasources | grep -q 'prometheus'" \
    "Grafana to have Prometheus data source"
}

# Run all test suites
run_all_tests() {
  echo_header
  
  # Reset timing counters
  TEST_TOTAL_TIME=0
  SUITE_START_TIME=$(get_time_ms)
  
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${BLUE}Starting test run at:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
  else
    echo -e "Running tests"
  fi
  
  # Run test suites
  test_echo_servers
  test_aggregator
  test_prometheus
  test_grafana
  
  # Calculate total run time
  local total_run_time=$(($(get_time_ms) - SUITE_START_TIME))
  
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
  echo "Default mode shows minimal output with test names and timing."
  echo "Use verbose mode for debugging or to see detailed test output."
  echo ""
  echo "Examples:"
  echo "  $0              # Run tests with minimal output"
  echo "  $0 --verbose    # Run tests with detailed output"
}

# Check dependencies
check_dependencies() {
  local missing_deps=0
  
  if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed.${NC}"
    echo "Please install curl with: brew install curl"
    missing_deps=1
  fi
  
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker is required but not installed.${NC}"
    echo "Please install Docker from: https://docs.docker.com/get-docker/"
    missing_deps=1
  fi
  
  if [ $missing_deps -ne 0 ]; then
    exit 1
  fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Check dependencies
  check_dependencies
  
  # Run all tests
  run_all_tests
  exit $?
else
  # This is for when the script is sourced rather than executed directly
  echo "Available test suites:"
  echo "  test_echo_servers    - Tests echo server containers"
  echo "  test_aggregator      - Tests aggregator container"
  echo "  test_prometheus      - Tests Prometheus container"
  echo "  test_grafana         - Tests Grafana container (if enabled)"
  echo "  run_all_tests        - Runs all test suites"
  echo ""
  echo "Run './scripts/test_terraform_containers.sh -v' for verbose test output"
  echo "Run './scripts/test_terraform_containers.sh' for minimal output"
fi
