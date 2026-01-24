#!/usr/bin/env bash
#
# validate.sh
# Validate HVE-Core installation by checking required directories and method-specific configuration

set -euo pipefail

usage() {
  echo "Usage: ${0##*/} <method> <base_path>"
  echo ""
  echo "Arguments:"
  echo "  method     Installation method number (1-6)"
  echo "  base_path  Path to hve-core root directory"
  echo ""
  echo "Examples:"
  echo "  ${0##*/} 1 ../hve-core"
  echo "  ${0##*/} 2 .hve-core"
  echo "  ${0##*/} 4 /workspaces/hve-core"
  exit 1
}

main() {
  if [[ "$#" -ne 2 ]]; then
    usage
  fi

  local method="$1"
  local base_path="$2"
  local valid=true

  # Validate required directories exist
  for path in "$base_path/.github/agents" "$base_path/.github/prompts" "$base_path/.github/instructions"; do
    if [[ -d "$path" ]]; then
      echo "✅ Found: $path"
    else
      echo "❌ Missing: $path"
      valid=false
    fi
  done

  # Method 5: workspace file check (requires jq)
  if [[ "$method" == "5" ]]; then
    if ! command -v jq &>/dev/null; then
      echo "⚠️  jq not installed - skipping workspace JSON validation"
      echo "   Install jq for full validation, or manually verify hve-core.code-workspace has 2+ folders"
    elif [[ -f "hve-core.code-workspace" ]]; then
      if jq -e '.folders | length >= 2' hve-core.code-workspace &>/dev/null; then
        echo "✅ Multi-root configured"
      else
        echo "❌ Multi-root not configured"
        valid=false
      fi
    else
      echo "❌ Workspace file not found: hve-core.code-workspace"
      valid=false
    fi
  fi

  # Method 6: submodule check
  if [[ "$method" == "6" ]]; then
    if [[ -f ".gitmodules" ]] && grep -q "$base_path" .gitmodules 2>/dev/null; then
      echo "✅ Submodule configured at $base_path"
    else
      echo "❌ Submodule path $base_path not in .gitmodules"
      valid=false
    fi
  fi

  # Final status
  if [[ "$valid" == true ]]; then
    echo "✅ Installation validated successfully"
    exit 0
  else
    echo "❌ Installation validation failed"
    exit 1
  fi
}

main "$@"
