#!/usr/bin/env bash
#
# lint.sh - Run shellcheck and shfmt on all shell scripts in the repo
#
# Usage:
#   ./lint.sh        Check mode (reports issues without modifying)
#   ./lint.sh --fix  Auto-fix formatting with shfmt

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Track overall status
exit_code=0

# Parse arguments
FIX_MODE=false
if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
fi

# Check dependencies
check_dependency() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        echo "Install with: brew install $cmd"
        return 1
    fi
}

echo "Checking dependencies..."
deps_ok=true
check_dependency shellcheck || deps_ok=false
check_dependency shfmt || deps_ok=false

if [[ "$deps_ok" == "false" ]]; then
    exit 1
fi
echo -e "${GREEN}Dependencies OK${NC}"
echo

# Find all shell scripts in repo root
scripts=()
for script in *.sh; do
    if [[ -f "$script" ]]; then
        scripts+=("$script")
    fi
done

if [[ ${#scripts[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No shell scripts found in repo root${NC}"
    exit 0
fi

echo "Found ${#scripts[@]} script(s): ${scripts[*]}"
echo

# Run shellcheck
echo "Running shellcheck..."
if shellcheck "${scripts[@]}"; then
    echo -e "${GREEN}shellcheck: OK${NC}"
else
    echo -e "${RED}shellcheck: FAILED${NC}"
    exit_code=1
fi
echo

# Run shfmt
echo "Running shfmt..."
if [[ "$FIX_MODE" == "true" ]]; then
    # Fix mode: modify files in place
    if shfmt -w -i 4 "${scripts[@]}"; then
        echo -e "${GREEN}shfmt: Fixed formatting${NC}"
    else
        echo -e "${RED}shfmt: FAILED${NC}"
        exit_code=1
    fi
else
    # Check mode: show diff without modifying
    if shfmt -d -i 4 "${scripts[@]}"; then
        echo -e "${GREEN}shfmt: OK${NC}"
    else
        echo -e "${RED}shfmt: Formatting issues found (run with --fix to auto-fix)${NC}"
        exit_code=1
    fi
fi
echo

# Report results
if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}All checks passed!${NC}"
else
    echo -e "${RED}Some checks failed${NC}"
fi

exit $exit_code
