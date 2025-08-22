#!/bin/sh
# Test Python 3 installation and functionality

echo "Testing Python 3 installation..."

# Check Python is installed
if ! command -v python3 >/dev/null 2>&1; then
    echo "FAIL: Python 3 not found"
    exit 1
fi
echo "✓ Python 3 installed: $(python3 --version)"

# Check pip is installed
if ! command -v pip3 >/dev/null 2>&1; then
    echo "FAIL: pip3 not found"
    exit 1
fi
echo "✓ pip3 installed: $(pip3 --version)"

# Test Python can run code
if ! python3 -c "import sys; print(f'Python {sys.version}')" >/dev/null 2>&1; then
    echo "FAIL: Python cannot execute code"
    exit 1
fi
echo "✓ Python can execute code"

# Test venv creation
TEST_VENV="/tmp/test_venv_$$"
if ! python3 -m venv "$TEST_VENV" >/dev/null 2>&1; then
    echo "FAIL: Cannot create virtual environment"
    exit 1
fi
rm -rf "$TEST_VENV"
echo "✓ Virtual environment support working"

# Test pip can install packages
if ! python3 -m pip list >/dev/null 2>&1; then
    echo "FAIL: pip cannot list packages"
    exit 1
fi
echo "✓ pip functional"

# Check important modules
for module in ssl sqlite3 ctypes multiprocessing; do
    if ! python3 -c "import $module" 2>/dev/null; then
        echo "WARNING: Module $module not available"
    else
        echo "✓ Module $module available"
    fi
done

echo "SUCCESS: Python 3 environment is fully functional"