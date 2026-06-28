#!/bin/bash

echo "================================================"
echo "RTX 3090 AI Training Tools (T) - Environment Setup"
echo "================================================"

# Shared venv location. R and T both target ~/ai-inference: a single tool invocation spans
# both repos (you run a T tool from cwd=R), so one neutral env serves both. This script only
# ADDS T's dependency (httpx) into that env; it never clobbers an existing venv that R may
# have created first. The materialized venv is a gitignored build artifact, not a repo asset.
VENV_PATH="$HOME/ai-inference"

#######################################################################
# SECTION 1: Python Environment
#######################################################################
echo ""
echo "[1/3] Setting up Python environment..."

python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "  Python version: $python_version"

if [ ! -d "$VENV_PATH" ]; then
    echo "  Creating virtual environment at $VENV_PATH..."
    python3 -m venv "$VENV_PATH"
else
    echo "  Virtual environment already exists at $VENV_PATH (reusing; not clobbering)"
fi

. "$VENV_PATH/bin/activate"

echo "  Upgrading pip..."
pip install --upgrade pip

#######################################################################
# SECTION 2: Tool Dependencies
#######################################################################
echo ""
echo "[2/3] Installing tool dependencies..."

# T's tools are HTTP clients (the serving stack lives in the Docker image, not the host venv),
# so the only third-party dependency is httpx. See requirements.txt for the rationale.
pip install -r requirements.txt

#######################################################################
# SECTION 3: Verification
#######################################################################
echo ""
echo "[3/3] Verifying setup..."

python3 -c "import httpx; print(f'  httpx {httpx.__version__} OK')"

echo ""
echo "================================================"
echo "Setup complete!"
echo "================================================"
echo ""
echo "To activate the environment:"
echo "  source ~/ai-inference/bin/activate"
echo ""
echo "Run the tools from the data repo (R) so results land in R; see README.md."
