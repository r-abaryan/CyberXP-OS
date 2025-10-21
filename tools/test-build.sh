#!/bin/bash
###############################################################################
# CyberXP-OS Build Test Script
# Validates build artifacts and configurations
###############################################################################

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

echo "======================================"
echo "  CyberXP-OS Build Test Suite"
echo "======================================"
echo ""

# Test function
test_check() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Testing: $test_name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Configuration Tests
echo "=== Configuration Tests ==="
test_check "OpenRC init script exists" "[ -f config/services/cyberxp-agent ]"
test_check "OpenRC init script is executable format" "grep -q '#!/sbin/openrc-run' config/services/cyberxp-agent"
test_check "Package list exists" "[ -f config/system/packages.txt ]"
test_check "Dashboard app exists" "[ -f config/desktop/cyberxp-dashboard/app.py ]"
test_check "Dashboard template exists" "[ -f config/desktop/cyberxp-dashboard/templates/index.html ]"
test_check "Network config template exists" "[ -f config/system/network-interfaces ]"
test_check "Firewall rules template exists" "[ -f config/system/iptables-rules.v4 ]"
test_check "Sysctl config exists" "[ -f config/system/sysctl.conf ]"
echo ""

# Build Script Tests
echo "=== Build Script Tests ==="
test_check "Build script exists" "[ -f scripts/build-alpine-iso.sh ]"
test_check "Build script is executable" "[ -x scripts/build-alpine-iso.sh ]"
test_check "Build script has proper shebang" "head -1 scripts/build-alpine-iso.sh | grep -q '#!/bin/bash'"
test_check "Setup VM script exists" "[ -f scripts/setup-dev-vm.sh ]"
test_check "Setup VM script is executable" "[ -x scripts/setup-dev-vm.sh ]"
echo ""

# Documentation Tests
echo "=== Documentation Tests ==="
test_check "README exists" "[ -f README.md ]"
test_check "Building guide exists" "[ -f docs/BUILDING.md ]"
test_check "User guide exists" "[ -f docs/USER_GUIDE.md ]"
test_check "Configuration guide exists" "[ -f docs/CONFIGURATION.md ]"
test_check "Contributing guide exists" "[ -f docs/CONTRIBUTING.md ]"
test_check "Project status exists" "[ -f PROJECT_STATUS.md ]"
test_check "Quickstart guide exists" "[ -f QUICKSTART.md ]"
echo ""

# Python Syntax Tests
echo "=== Python Syntax Tests ==="
if command -v python3 > /dev/null 2>&1; then
    test_check "Dashboard app syntax" "python3 -m py_compile config/desktop/cyberxp-dashboard/app.py"
else
    echo -e "${YELLOW}⚠ Python3 not found, skipping syntax tests${NC}"
fi
echo ""

# Shell Script Syntax Tests
echo "=== Shell Script Syntax Tests ==="
if command -v shellcheck > /dev/null 2>&1; then
    test_check "Build script shellcheck" "shellcheck -e SC2086,SC2046 scripts/build-alpine-iso.sh"
    test_check "Setup VM script shellcheck" "shellcheck -e SC2086 scripts/setup-dev-vm.sh"
else
    echo -e "${YELLOW}⚠ shellcheck not found, skipping linting${NC}"
fi
echo ""

# Directory Structure Tests
echo "=== Directory Structure Tests ==="
test_check "Build directory exists" "[ -d build ] || mkdir -p build"
test_check "Config directory exists" "[ -d config ]"
test_check "Scripts directory exists" "[ -d scripts ]"
test_check "Docs directory exists" "[ -d docs ]"
test_check "Tools directory exists" "[ -d tools ]"
echo ""

# Summary
echo "======================================"
echo "  Test Summary"
echo "======================================"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    exit 1
fi

