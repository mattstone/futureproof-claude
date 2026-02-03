#!/bin/bash
# Build script for Rust Monte Carlo engine using maturin

echo "=========================================="
echo "Building Rust Monte Carlo Engine"
echo "=========================================="

# Source Rust environment and add to PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Build in release mode using maturin (handles Python linking)
echo "Building with maturin (optimized)..."
python3 -m maturin build --release

# Install the wheel if build succeeded
if [ $? -eq 0 ]; then
    echo "Installing wheel..."
    pip3 install --force-reinstall target/wheels/*.whl
fi

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "Module installed in development mode"
    echo ""
    echo "You can now run:"
    echo "  python3 profitability_sweep.py"
    echo ""
else
    echo ""
    echo "❌ Build failed. Check errors above."
    exit 1
fi
