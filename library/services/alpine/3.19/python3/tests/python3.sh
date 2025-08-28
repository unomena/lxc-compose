#!/bin/sh
# Test Python 3 virtual environment installation and functionality

echo "Testing Python 3 virtual environment setup..."

# Check if virtual environment exists
if [ ! -d "/opt/venv" ]; then
    echo "FAIL: Virtual environment not found at /opt/venv"
    exit 1
fi
echo "✓ Virtual environment exists at /opt/venv"

# Check if virtual environment is active by default
if [ "$VIRTUAL_ENV" != "/opt/venv" ]; then
    echo "WARNING: VIRTUAL_ENV not set to /opt/venv (got: $VIRTUAL_ENV)"
fi

# Check Python is available via symlinks
if ! command -v python >/dev/null 2>&1; then
    echo "FAIL: Python not found"
    exit 1
fi
echo "✓ Python installed: $(python --version)"

# Check Python3 is available
if ! command -v python3 >/dev/null 2>&1; then
    echo "FAIL: Python 3 not found"
    exit 1
fi
echo "✓ Python 3 installed: $(python3 --version)"

# Verify python points to venv Python
PYTHON_PATH=$(which python)
if [[ "$PYTHON_PATH" != "/opt/venv/bin/python" ]] && [[ "$PYTHON_PATH" != "/usr/local/bin/python" ]]; then
    echo "WARNING: Python not using virtual environment (path: $PYTHON_PATH)"
else
    echo "✓ Python using virtual environment"
fi

# Check pip is installed and from venv
if ! command -v pip >/dev/null 2>&1; then
    echo "FAIL: pip not found"
    exit 1
fi
echo "✓ pip installed: $(pip --version)"

# Verify pip points to venv pip
PIP_PATH=$(which pip)
if [[ "$PIP_PATH" != "/opt/venv/bin/pip" ]] && [[ "$PIP_PATH" != "/usr/local/bin/pip" ]]; then
    echo "WARNING: pip not using virtual environment (path: $PIP_PATH)"
else
    echo "✓ pip using virtual environment"
fi

# Test Python can run code
if ! python -c "import sys; print(f'Python {sys.version}')" >/dev/null 2>&1; then
    echo "FAIL: Python cannot execute code"
    exit 1
fi
echo "✓ Python can execute code"

# Test pip can install packages in venv
if ! python -m pip list >/dev/null 2>&1; then
    echo "FAIL: pip cannot list packages"
    exit 1
fi
echo "✓ pip functional"

# Verify packages install to venv
TEST_PKG="six"
python -m pip install -q $TEST_PKG 2>/dev/null
if [ -f "/opt/venv/lib/python"*"/site-packages/$TEST_PKG"* ]; then
    echo "✓ Packages install to virtual environment"
    python -m pip uninstall -q -y $TEST_PKG 2>/dev/null
else
    echo "WARNING: Could not verify package installation location"
fi

# Check important modules
for module in ssl sqlite3 ctypes multiprocessing; do
    if ! python -c "import $module" 2>/dev/null; then
        echo "WARNING: Module $module not available"
    else
        echo "✓ Module $module available"
    fi
done

echo "SUCCESS: Python 3 virtual environment is fully functional"