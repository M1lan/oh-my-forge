#!/bin/bash
# oh-my-forge installer
# Usage: ./install.sh /path/to/project [--preset <name>] [--global]

set -e

OMF_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-.}"
PRESET=""
GLOBAL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --preset)
      PRESET="$2"
      shift 2
      ;;
    --global)
      GLOBAL=true
      shift
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

echo "⚒️  oh-my-forge installer"
echo "========================"

if [ "$GLOBAL" = true ]; then
  TARGET="$HOME/.forge"
  echo "📁 Installing globally to $TARGET"
  mkdir -p "$TARGET/agents" "$TARGET/skills"
else
  echo "📁 Installing to $TARGET"
  mkdir -p "$TARGET/.forge/agents" "$TARGET/.forge/skills"
fi

# Copy agents
if [ "$GLOBAL" = true ]; then
  cp -r "$OMF_DIR/agents/"* "$TARGET/agents/"
  echo "✅ Agents installed to $TARGET/agents/"
else
  cp -r "$OMF_DIR/agents/"* "$TARGET/.forge/agents/"
  echo "✅ Agents installed to $TARGET/.forge/agents/"
fi

# Copy skills
if [ "$GLOBAL" = true ]; then
  cp -r "$OMF_DIR/skills/"* "$TARGET/skills/"
  echo "✅ Skills installed to $TARGET/skills/"
else
  cp -r "$OMF_DIR/skills/"* "$TARGET/.forge/skills/"
  echo "✅ Skills installed to $TARGET/.forge/skills/"
fi

# Copy forge.yaml (project-level only)
if [ "$GLOBAL" = false ]; then
  if [ -f "$TARGET/forge.yaml" ]; then
    echo "⚠️  forge.yaml already exists — backing up to forge.yaml.bak"
    cp "$TARGET/forge.yaml" "$TARGET/forge.yaml.bak"
  fi
  cp "$OMF_DIR/forge.yaml" "$TARGET/forge.yaml"
  echo "✅ forge.yaml installed"
fi

# Apply preset if specified
if [ -n "$PRESET" ]; then
  PRESET_DIR="$OMF_DIR/examples/$PRESET"
  if [ -d "$PRESET_DIR" ]; then
    echo "🎨 Applying preset: $PRESET"
    # Merge preset agents
    if [ -d "$PRESET_DIR/agents" ]; then
      if [ "$GLOBAL" = true ]; then
        cp -r "$PRESET_DIR/agents/"* "$TARGET/agents/"
      else
        cp -r "$PRESET_DIR/agents/"* "$TARGET/.forge/agents/"
      fi
    fi
    # Merge preset skills
    if [ -d "$PRESET_DIR/skills" ]; then
      if [ "$GLOBAL" = true ]; then
        cp -r "$PRESET_DIR/skills/"* "$TARGET/skills/"
      else
        cp -r "$PRESET_DIR/skills/"* "$TARGET/.forge/skills/"
      fi
    fi
    # Merge preset forge.yaml custom_rules
    if [ -f "$PRESET_DIR/forge.yaml" ] && [ "$GLOBAL" = false ]; then
      echo ""
      echo "📝 Preset forge.yaml available at: $PRESET_DIR/forge.yaml"
      echo "   Merge it manually into your forge.yaml if needed."
    fi
    echo "✅ Preset '$PRESET' applied"
  else
    echo "❌ Preset '$PRESET' not found. Available presets:"
    ls -1 "$OMF_DIR/examples/" 2>/dev/null || echo "   (none yet)"
    exit 1
  fi
fi

echo ""
echo "🎉 oh-my-forge installed!"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET"
echo "  2. Run 'forge' to start"
echo "  3. Try: 'plan: build a user authentication system'"
echo ""
echo "Execution modes:"
echo "  autopilot: <task>  — Full autonomous build"
echo "  turbo: <task>      — Parallel sub-tasks"
echo "  eco: <task>        — Minimal token usage"
echo "  plan: <task>       — Interview + plan first"
echo "  review: <task>     — Code review (read-only)"
echo "  ralph: <task>      — Persistence mode"
echo "  ultrawork: <task>  — Maximum parallelism"
echo "  team: N:agent      — Multi-agent coordination"
echo "  trace: <bug>       — Evidence-driven debugging"
