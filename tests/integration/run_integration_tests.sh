#!/bin/bash

# Nexus CLI Integration Test Runner
# Runs all integration tests and generates report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
REPORT_DIR="$PROJECT_ROOT/.nexus-temp/test-reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
declare -A TEST_RESULTS
TOTAL_PASS=0
TOTAL_FAIL=0

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Nexus CLI Integration Test Suite                     ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Version: v4.0.2                                               ║"
echo "║  Date: $(date '+%Y-%m-%d %H:%M:%S')                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Setup report directory
mkdir -p "$REPORT_DIR"

# Run a test and capture results
run_test() {
    local test_name=$1
    local test_script=$2

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Running: $test_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    local start_time=$(date +%s)
    local test_output
    local exit_code

    # Run test and capture output
    set +e
    test_output=$("$test_script" 2>&1)
    exit_code=$?
    set -e

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Display output
    echo "$test_output"

    # Record result
    if [ $exit_code -eq 0 ]; then
        TEST_RESULTS["$test_name"]="PASS"
        TOTAL_PASS=$((TOTAL_PASS + 1))
        echo -e "\n${GREEN}✅ $test_name: PASSED${NC} (${duration}s)"
    else
        TEST_RESULTS["$test_name"]="FAIL"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        echo -e "\n${RED}❌ $test_name: FAILED${NC} (${duration}s)"
    fi

    # Save to report file
    {
        echo "=========================================="
        echo "Test: $test_name"
        echo "Result: ${TEST_RESULTS[$test_name]}"
        echo "Duration: ${duration}s"
        echo "Exit Code: $exit_code"
        echo "=========================================="
        echo "$test_output"
        echo ""
    } >> "$REPORT_DIR/integration_report_$TIMESTAMP.txt"

    return $exit_code
}

# Run mock server self-test
echo -e "${BLUE}[Pre-flight]${NC} Testing mock PAL server..."
if python3 "$SCRIPT_DIR/../mocks/mock_pal_server.py" --test > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Mock PAL server is functional${NC}\n"
else
    echo -e "${YELLOW}⚠️  Mock PAL server has issues (tests may still pass)${NC}\n"
fi

# Run all integration tests
echo -e "${BLUE}[1/3]${NC} Running Spec Flow tests..."
run_test "Spec Flow" "$SCRIPT_DIR/test_spec_flow.sh" || true

echo -e "\n${BLUE}[2/3]${NC} Running Batch Execution tests..."
run_test "Batch Execution" "$SCRIPT_DIR/test_batch_exec.sh" || true

echo -e "\n${BLUE}[3/3]${NC} Running Static Validation tests..."
run_test "Static Validation" "$PROJECT_ROOT/tests/run_static_tests.sh" || true

# Generate summary report
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                    Integration Test Summary"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "Test Results:"
echo ""
for test_name in "${!TEST_RESULTS[@]}"; do
    result=${TEST_RESULTS[$test_name]}
    if [ "$result" == "PASS" ]; then
        echo -e "  ${GREEN}✅ $test_name${NC}"
    else
        echo -e "  ${RED}❌ $test_name${NC}"
    fi
done

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo -e "  ${GREEN}Passed${NC}: $TOTAL_PASS"
echo -e "  ${RED}Failed${NC}: $TOTAL_FAIL"
echo -e "  Total:  $((TOTAL_PASS + TOTAL_FAIL))"
echo ""
echo "  Report: $REPORT_DIR/integration_report_$TIMESTAMP.txt"
echo ""

# Exit with appropriate code
if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo -e "${GREEN}🎉 All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed. Check the report for details.${NC}"
    exit 1
fi
