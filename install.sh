#!/bin/bash
set -e

# Claude Code YOLO Quick Installer

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="claude.sh"
YOLO_WRAPPER="claude-yolo"
DOCKER_IMAGE="lroolle/claude-code-yolo:latest"
GITHUB_RAW="https://raw.githubusercontent.com/lroolle/claude-code-yolo/main"

echo "Claude Code YOLO Installer"
echo "=========================="
echo ""

# Create install directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Creating $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
fi

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "warning: $INSTALL_DIR is not in PATH"
    echo "Add this to your shell profile:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# Download claude.sh
echo "Downloading claude.sh script..."
curl -fsSL "$GITHUB_RAW/claude.sh" -o "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Download claude-yolo script
echo "Downloading claude-yolo script..."
curl -fsSL "$GITHUB_RAW/claude-yolo" -o "$INSTALL_DIR/$YOLO_WRAPPER"
chmod +x "$INSTALL_DIR/$YOLO_WRAPPER"

# Pull Docker image
echo ""
echo "Pulling Docker image..."
docker pull "$DOCKER_IMAGE"

# Success message
echo ""
echo "✓ Installation complete!"
echo ""
echo "Commands available:"
echo "=================="
echo ""
echo "  claude.sh      - Full Claude wrapper with all options"
echo "  claude-yolo    - Quick alias for 'claude.sh --yolo'"
echo ""
echo "Quick Start:"
echo "============"
echo ""
echo "1. Make sure Docker is running"
echo ""
echo "2. Navigate to your project directory:"
echo "   cd ~/projects/my-project"
echo ""
echo "3. Run Claude in YOLO mode:"
echo "   claude-yolo ."
echo ""
echo "4. Or use claude.sh for more options:"
echo "   claude.sh --help          # Show all options"
echo "   claude.sh .               # Local mode"
echo "   claude.sh --yolo .        # YOLO mode"
echo "   claude.sh -a .            # API key mode"
echo "   claude.sh --shell         # Docker shell"
echo ""
echo "WARNING: Never run --yolo in your home directory or system directories!"
echo "" 