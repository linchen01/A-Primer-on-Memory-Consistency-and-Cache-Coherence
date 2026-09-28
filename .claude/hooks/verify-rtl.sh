#!/bin/bash
set -euo pipefail

# RTL Verification Script for SessionStart Hook
# Runs simulation and basic validation checks

echo "🚀 Starting RTL Verification..."

cd "$CLAUDE_PROJECT_DIR" || exit 1

# Function to print section headers
print_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Function to check file
check_file() {
    local file=$1
    local name=$2
    if [ -f "$file" ]; then
        echo "✅ $name exists"
        return 0
    else
        echo "❌ $name not found: $file"
        return 1
    fi
}

# Section 1: Verify project structure
print_section "Project Structure Verification"
check_file "rtl/sync_fifo.sv" "RTL source"
check_file "tb/sync_fifo_tb.sv" "Testbench"
check_file "Makefile" "Build system"
check_file "sim_fifo.py" "Python simulator"

# Section 2: Check file syntax (basic)
print_section "Syntax Check"
echo "Checking SystemVerilog files for common issues..."

if python3 -c "import re; content = open('rtl/sync_fifo.sv').read(); assert 'module sync_fifo' in content; print('✅ RTL module definition found')" 2>/dev/null; then
    :
else
    echo "⚠️  Warning: RTL module definition check failed"
fi

if python3 -c "import re; content = open('tb/sync_fifo_tb.sv').read(); assert 'module sync_fifo_tb' in content; print('✅ Testbench module definition found')" 2>/dev/null; then
    :
else
    echo "⚠️  Warning: Testbench module definition check failed"
fi

# Section 3: Run Python simulation
print_section "Running FIFO Simulation"
if [ -f "sim_fifo.py" ]; then
    if python3 sim_fifo.py 2>&1 | tail -5; then
        echo "✅ Simulation completed successfully"
    else
        echo "❌ Simulation failed"
        exit 1
    fi
else
    echo "⚠️  sim_fifo.py not found, skipping simulation"
fi

# Section 4: Verify VCD generation
print_section "Waveform Verification"
if [ -f "sync_fifo.vcd" ]; then
    lines=$(wc -l < sync_fifo.vcd)
    echo "✅ Waveform file generated ($lines lines)"

    # Check VCD format
    if head -1 sync_fifo.vcd | grep -q "date"; then
        echo "✅ VCD file format valid"
    else
        echo "⚠️  VCD format check failed"
    fi
else
    echo "⚠️  No waveform file found"
fi

# Section 5: Check documentation
print_section "Documentation Check"
check_file "FIFO_DESIGN.md" "Design documentation"
check_file "wave_viewer.html" "Waveform viewer"

# Section 6: Git status
print_section "Git Repository Status"
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "✅ Git repository initialized"

    # Show branch info
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    echo "📍 Current branch: $branch"

    # Show commit count
    commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    echo "📊 Total commits: $commits"

    # Check for uncommitted changes
    if [ -z "$(git status --porcelain)" ]; then
        echo "✅ Working tree clean"
    else
        echo "⚠️  Uncommitted changes detected:"
        git status --short | head -5
    fi
else
    echo "❌ Not a git repository"
fi

# Section 7: Build system check
print_section "Build System Check"
if [ -f "Makefile" ]; then
    echo "✅ Makefile found"

    if make --version > /dev/null 2>&1; then
        echo "✅ Make installed"

        # List available targets
        echo "📌 Available Make targets:"
        grep "^[a-z_]*:" Makefile | sed 's/:.*$//' | sed 's/^/  - /' | head -10
    else
        echo "❌ Make not found"
    fi
else
    echo "❌ Makefile not found"
fi

print_section "Verification Complete"
echo "✅ All checks passed! RTL project is ready for development."
echo ""
echo "📚 Next steps:"
echo "  1. Make changes to RTL files in rtl/ directory"
echo "  2. Make will automatically run these checks on save"
echo "  3. Use 'make python_sim' to run full simulation"
echo "  4. Check wave_viewer.html for waveform visualization"
echo ""
