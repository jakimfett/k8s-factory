#!/bin/bash

# Script to test port conflict detection in the aggregator container

# Colors for formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directory setup
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"

# Variable to track test result
TEST_RESULT=1 # Default to failure unless explicitly passed

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}    Port Conflict Detection Test    ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Step 1: Make sure port 3000 is free
echo -e "${YELLOW}Ensuring port 3000 is free...${NC}"
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
sleep 1

# Step 2: Start debug containers using the existing script
echo -e "${YELLOW}Starting debug containers on port 3000...${NC}"
cd "${PROJECT_ROOT}"
"${SCRIPTS_DIR}/run_debug_containers.sh" --start

# Wait for the server to initialize
sleep 15

# Verify the server is running
if ! curl -s http://localhost:3000 > /dev/null; then
  echo -e "${RED}Failed to start debug containers on port 3000.${NC}"
  exit 1
fi

# Get the container IDs for later reference
AGGREGATOR_CONTAINER=$(docker ps | grep aggregator | awk '{print $1}')
ECHO_CONTAINERS=$(docker ps | grep 'local-echo' | awk '{print $1}')

echo -e "${GREEN}Debug containers successfully started${NC}"
echo -e "${GREEN}Aggregator: ${AGGREGATOR_CONTAINER}${NC}"
echo -e "${GREEN}Echo servers: ${ECHO_CONTAINERS}${NC}"

# Step 3: Try to start the aggregator container directly to test port conflict detection
echo -e "${YELLOW}Testing port conflict detection in the aggregator container...${NC}"

# First, make sure the aggregator image is built
echo -e "${YELLOW}Building aggregator container with port conflict detection...${NC}"
cd ${PROJECT_ROOT}/services/aggregator
docker build -t aggregator:test . > /dev/null

# Now run the container and check if it detects the port conflict
echo -e "${YELLOW}Starting aggregator container (should detect port conflict)...${NC}"
docker run --name port-conflict-test -p 3000:3000 -e "ECHO_URLS=http://example.com" aggregator:test &> /tmp/container_logs.txt

# Get the exit code
DOCKER_EXIT_CODE=$?
sleep 2

# Step 4: Check container logs for Docker's port conflict error message
echo -e "${YELLOW}Checking logs for port conflict detection...${NC}"

if grep -q "port is already allocated" /tmp/container_logs.txt; then
  echo -e "${GREEN}SUCCESS: Docker port conflict was properly detected!${NC}"
  echo -e "${YELLOW}Error message:${NC}"
  grep -A 1 "port is already allocated" /tmp/container_logs.txt
  TEST_RESULT=0
else
  echo -e "${RED}FAILURE: Docker port conflict was not detected.${NC}"
  echo -e "${YELLOW}Container logs:${NC}"
  cat /tmp/container_logs.txt
  TEST_RESULT=1
fi

# Step 5: Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"

# Stop the debug containers
cd "${PROJECT_ROOT}"
"${SCRIPTS_DIR}/run_debug_containers.sh" --stop

# Clean up the test container
docker rm -f port-conflict-test &>/dev/null || true

# Remove test files
rm -f /tmp/container_logs.txt

echo -e "${GREEN}All test containers stopped and removed${NC}"

echo -e "${BLUE}=======================================${NC}"
if [ "$TEST_RESULT" -eq 0 ]; then
  echo -e "${GREEN}PORT CONFLICT TEST PASSED!${NC}"
else
  echo -e "${RED}PORT CONFLICT TEST FAILED!${NC}"
fi
echo -e "${BLUE}=======================================${NC}"

exit $TEST_RESULT
