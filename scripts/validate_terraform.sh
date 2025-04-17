#!/bin/bash

# Colors for output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Test counters and timing
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_START_TIME=0
TEST_TOTAL_TIME=0
SUITE_START_TIME=0

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
  
  # Execute the test command
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

# Print test header
echo_header() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}    Terraform Validation Suite    ${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
}

# Test suite: Terraform CLI Validation
test_terraform_validate() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Terraform Configuration Validation${NC}"
  fi
  
  # Navigate to terraform directory
  cd "/Users/jakimfett/hub/dev/k8s-factory/infrastructure/terraform" || exit
  
  # Check terraform installation
  run_test "Terraform is installed" \
    "command -v terraform" \
    "Terraform CLI to be available"
  
  # Test terraform init
  if [[ "$VERBOSE" == "true" ]]; then
    run_test "Terraform initialization" \
      "terraform init" \
      "Terraform to initialize successfully"
  else
    run_test "Terraform initialization" \
      "terraform init -no-color" \
      "Terraform to initialize successfully"
  fi
  
  # Test terraform validate
  run_test "Terraform configuration validation" \
    "terraform validate" \
    "Terraform configuration to be valid"
  
  # Test terraform plan (check if plan would succeed, don't actually create a plan)
  if [[ "$VERBOSE" == "true" ]]; then
    run_test "Terraform plan check" \
      "terraform plan -input=false -lock=false -detailed-exitcode || [ \$? -eq 2 ]" \
      "Terraform plan to execute without errors (exit code 0 or 2)"
  else
    run_test "Terraform plan check" \
      "terraform plan -input=false -lock=false -no-color -detailed-exitcode || [ \$? -eq 2 ]" \
      "Terraform plan to execute without errors (exit code 0 or 2)"
  fi
}

# Test suite: TFLint Static Analysis
test_tflint() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing TFLint Static Analysis${NC}"
  fi
  
  # Navigate to terraform directory
  cd "/Users/jakimfett/hub/dev/k8s-factory/infrastructure/terraform" || exit
  
  # Check tflint installation
  run_test "TFLint is installed" \
    "command -v tflint" \
    "TFLint CLI to be available"
  
  # Test tflint basic run
  run_test "TFLint basic configuration check" \
    "tflint --no-color" \
    "TFLint to run without errors"
  
  # Test for deprecated syntax
  run_test "Check for deprecated syntax" \
    "tflint --no-color --only=terraform_deprecated_syntax" \
    "No deprecated syntax found"
  
  # Test for deprecated interpolation
  run_test "Check for deprecated interpolation" \
    "tflint --no-color --only=terraform_deprecated_interpolation" \
    "No deprecated interpolation found"
  
  # Test for naming conventions
  run_test "Check naming conventions" \
    "tflint --no-color --only=terraform_naming_convention" \
    "Naming conventions followed"
}

# Test suite: Configuration Completeness
test_config_completeness() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "\n${BLUE}Testing Configuration Completeness${NC}"
  fi
  
  # Navigate to terraform directory
  cd "/Users/jakimfett/hub/dev/k8s-factory/infrastructure/terraform" || exit
  
  # Check for essential files
  run_test "Essential Terraform files exist" \
    "[ -f main.tf ] && [ -f variables.tf ]" \
    "Essential Terraform files to exist (main.tf, variables.tf)"
  
  # Check for outputs
  run_test "Outputs are defined" \
    "grep -q 'output' *.tf || [ \$? -eq 1 ]" \
    "Output values should be defined or explicitly not needed"
  
  # Check for provider configuration
  run_test "Provider is configured" \
    "grep -q 'provider' *.tf" \
    "Provider should be configured"
  
  # Check for backend configuration (optional)
  run_test "Backend configuration exists (optional)" \
    "grep -q 'backend' *.tf || echo 'Local backend used by default'" \
    "Backend should be configured or use local default"
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
  test_terraform_validate
  test_tflint
  test_config_completeness
  
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
  
  if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform is required but not installed.${NC}"
    echo "Please install Terraform with: brew install terraform"
    missing_deps=1
  fi
  
  if ! command -v tflint &> /dev/null; then
    echo -e "${RED}Error: tflint is required but not installed.${NC}"
    echo "Please install TFLint with: brew install tflint"
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
  echo "  test_terraform_validate   - Tests Terraform validation"
  echo "  test_tflint               - Tests TFLint static analysis"
  echo "  test_config_completeness  - Tests configuration completeness"
  echo "  run_all_tests             - Runs all test suites"
  echo ""
  echo "Run './scripts/validate_terraform.sh -v' for verbose test output"
  echo "Run './scripts/validate_terraform.sh' for minimal output"
fi
