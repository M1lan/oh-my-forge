#!/bin/bash
# oh-my-forge global installer
# Installs agents to ~/.forge/agents so they work in every project

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/install.sh" --global

echo ""
echo "💡 Global agents are loaded from ~/.forge/agents/"
echo "   Project-level agents in .forge/agents/ take precedence."
echo "   Copy forge.yaml to individual projects as needed."
