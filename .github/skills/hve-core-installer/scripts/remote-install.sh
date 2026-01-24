#!/usr/bin/env bash
#
# remote-install.sh
# Portable HVE-Core installer for curl-based installation
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/microsoft/hve-core/main/.github/skills/hve-core-installer/scripts/remote-install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/microsoft/hve-core/main/.github/skills/hve-core-installer/scripts/remote-install.sh | bash -s -- --method 2
#   curl -sSL https://raw.githubusercontent.com/microsoft/hve-core/main/.github/skills/hve-core-installer/scripts/remote-install.sh | bash -s -- --help

set -euo pipefail

## Environment Variables (optional):
# HVE_METHOD    - Installation method (1-6 or auto, default: auto)
# HVE_TARGET    - Custom target path override
# HVE_BRANCH    - Branch to clone (default: main)
# HVE_WITH_MCP  - Create MCP configuration (true/false, default: false)

VERSION="1.0.0"
REPO_URL="https://github.com/microsoft/hve-core.git"

METHOD="${HVE_METHOD:-auto}"
TARGET="${HVE_TARGET:-}"
BRANCH="${HVE_BRANCH:-main}"
SKIP_VALIDATE=false
WITH_MCP="${HVE_WITH_MCP:-false}"

usage() {
  echo "HVE-Core Remote Installer v${VERSION}"
  echo ""
  echo "Usage: curl -sSL <url>/remote-install.sh | bash -s -- [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --method <1-6|auto>  Installation method (default: auto)"
  echo "  --target <path>      Custom target path override"
  echo "  --branch <name>      Branch to clone (default: main)"
  echo "  --with-mcp           Create MCP server configuration"
  echo "  --skip-validate      Skip post-installation validation"
  echo "  --help, -h           Show this help message"
  echo ""
  echo "Methods:"
  echo "  1  Peer Clone     - Clone to ../hve-core"
  echo "  2  Git-Ignored    - Clone to .hve-core (excluded from git)"
  echo "  3  Mounted        - Use /workspaces/hve-core (devcontainer mount)"
  echo "  4  Codespaces     - Clone to /workspaces/hve-core"
  echo "  5  Multi-Root     - Clone with workspace file"
  echo "  6  Submodule      - Add as git submodule to lib/hve-core"
  echo ""
  echo "Environment Variables:"
  echo "  HVE_METHOD        Equivalent to --method"
  echo "  HVE_TARGET        Equivalent to --target"
  echo "  HVE_BRANCH        Equivalent to --branch"
  echo "  HVE_WITH_MCP      Equivalent to --with-mcp (true/false)"
  echo ""
  echo "Examples:"
  echo "  # Auto-detect environment"
  echo "  curl -sSL <url>/remote-install.sh | bash"
  echo ""
  echo "  # Use specific method"
  echo "  curl -sSL <url>/remote-install.sh | bash -s -- --method 1"
  echo ""
  echo "  # Clone specific branch"
  echo "  curl -sSL <url>/remote-install.sh | bash -s -- --branch develop"
  exit 0
}

err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --method)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--method requires an argument (1-6 or auto)"
        fi
        METHOD="$2"
        shift 2
        ;;
      --target)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--target requires an argument"
        fi
        TARGET="$2"
        shift 2
        ;;
      --branch)
        if [[ -z "${2:-}" || "$2" == --* ]]; then
          err "--branch requires an argument"
        fi
        BRANCH="$2"
        shift 2
        ;;
      --skip-validate)
        SKIP_VALIDATE=true
        shift
        ;;
      --with-mcp)
        WITH_MCP=true
        shift
        ;;
      --help|-h)
        usage
        ;;
      *)
        err "Unknown option: $1"
        ;;
    esac
  done
}

# Auto-detect environment and recommend method
auto_detect_method() {
  # Detect Codespaces via CODESPACES environment variable
  if [[ "${CODESPACES:-}" == "true" ]]; then
    echo "4"  # Codespaces
    return
  fi

  # Detect devcontainer via /.dockerenv or REMOTE_CONTAINERS
  if [[ -f "/.dockerenv" ]] || [[ "${REMOTE_CONTAINERS:-}" == "true" ]]; then
    echo "2"  # Git-Ignored for devcontainer
    return
  fi

  echo "1"  # Peer Clone for local
}

# Get target path for method
get_target_path() {
  local method="$1"
  local custom_target="${2:-}"

  if [[ -n "$custom_target" ]]; then
    echo "$custom_target"
    return
  fi

  case "$method" in
    1) echo "../hve-core" ;;
    2) echo ".hve-core" ;;
    3) echo "/workspaces/hve-core" ;;
    4) echo "/workspaces/hve-core" ;;
    5) echo "../hve-core" ;;
    6) echo "lib/hve-core" ;;
    *) err "Invalid method: $method" ;;
  esac
}

# Clone HVE-Core repository
clone_hve_core() {
  local target="$1"

  if [[ -d "$target" ]]; then
    echo "⏭️  HVE-Core already exists at $target"
    return 0
  fi

  echo "📥 Cloning HVE-Core to $target..."
  if [[ "$BRANCH" == "main" ]]; then
    git clone "$REPO_URL" "$target"
  else
    git clone --branch "$BRANCH" "$REPO_URL" "$target"
  fi
  echo "✅ Cloned HVE-Core to $target"
}

# Add submodule instead of clone for method 6
add_submodule() {
  local target="$1"

  if [[ -d "$target" ]]; then
    echo "⏭️  HVE-Core submodule already exists at $target"
    return 0
  fi

  echo "📥 Adding HVE-Core as submodule to $target..."
  git submodule add "$REPO_URL" "$target"
  git submodule update --init --recursive
  echo "✅ Added HVE-Core as submodule to $target"
}

# Update .gitignore for method 2
update_gitignore() {
  local target="$1"
  local gitignore=".gitignore"

  # Check if entry already exists
  if [[ -f "$gitignore" ]] && grep -q "^${target}/?$" "$gitignore" 2>/dev/null; then
    return 0
  fi

  echo "📝 Adding $target/ to .gitignore..."
  {
    echo ""
    echo "# HVE-Core local installation"
    echo "${target}/"
  } >> "$gitignore"
}

# Configure .vscode/settings.json
configure_settings() {
  local prefix="$1"
  local settings_dir=".vscode"
  local settings_file="$settings_dir/settings.json"

  mkdir -p "$settings_dir"

  if [[ -f "$settings_file" ]]; then
    echo "⚠️  Settings file exists at $settings_file"
    echo "   Add the following paths manually if needed:"
    echo "   - $prefix/.github/agents"
    echo "   - $prefix/.github/prompts"
    echo "   - $prefix/.github/instructions"
  else
    echo "📝 Creating $settings_file..."
    cat > "$settings_file" << EOF
{
  "chat.modeFilesLocations": {
    ".github/agents": true,
    "$prefix/.github/agents": true
  },
  "chat.agentFilesLocations": {
    ".github/agents": true,
    "$prefix/.github/agents": true
  },
  "chat.promptFilesLocations": {
    ".github/prompts": true,
    "$prefix/.github/prompts": true
  },
  "chat.instructionsFilesLocations": {
    ".github/instructions": true,
    "$prefix/.github/instructions": true
  }
}
EOF
    echo "✅ Created settings file"
  fi
}

# Create workspace file for method 5
create_workspace_file() {
  local target="$1"
  local workspace_file="hve-core.code-workspace"

  if [[ -f "$workspace_file" ]]; then
    echo "⏭️  Workspace file already exists: $workspace_file"
    return 0
  fi

  echo "📝 Creating workspace file..."
  cat > "$workspace_file" << EOF
{
  "folders": [
    { "name": "Project", "path": "." },
    { "name": "HVE-Core", "path": "$target" }
  ],
  "settings": {
    "chat.modeFilesLocations": {
      ".github/agents": true,
      "$target/.github/agents": true
    },
    "chat.agentFilesLocations": {
      ".github/agents": true,
      "$target/.github/agents": true
    },
    "chat.promptFilesLocations": {
      ".github/prompts": true,
      "$target/.github/prompts": true
    },
    "chat.instructionsFilesLocations": {
      ".github/instructions": true,
      "$target/.github/instructions": true
    }
  }
}
EOF
  echo "✅ Created workspace file: $workspace_file"
  echo "   Open this file in VS Code to use multi-root workspace"
}

# Configure .vscode/mcp.json for MCP servers
configure_mcp() {
  local settings_dir=".vscode"
  local mcp_file="$settings_dir/mcp.json"

  mkdir -p "$settings_dir"

  if [[ -f "$mcp_file" ]]; then
    echo "⏭️  MCP configuration already exists at $mcp_file"
    return 0
  fi

  echo "📝 Creating MCP configuration..."
  cat > "$mcp_file" << 'EOF'
{
  "inputs": [
    {
      "id": "ado_org",
      "type": "promptString",
      "description": "Azure DevOps organization name (e.g. 'contoso')",
      "default": ""
    },
    {
      "id": "ado_tenant",
      "type": "promptString",
      "description": "Azure tenant ID (required for multi-tenant scenarios)",
      "default": ""
    }
  ],
  "servers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "microsoft-docs": {
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp"
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    }
  }
}
EOF
  echo "✅ Created MCP configuration"
  echo "   See docs/getting-started/mcp-configuration.md for ADO setup"
}

# Validate installation
validate_installation() {
  local method="$1"
  local target="$2"
  local valid=true

  # Validate required directories exist
  for path in "$target/.github/agents" "$target/.github/prompts" "$target/.github/instructions"; do
    if [[ -d "$path" ]]; then
      echo "✅ Found: $path"
    else
      echo "❌ Missing: $path"
      valid=false
    fi
  done

  # Method 5: workspace file check
  if [[ "$method" == "5" ]]; then
    if [[ -f "hve-core.code-workspace" ]]; then
      echo "✅ Workspace file exists"
    else
      echo "❌ Workspace file not found"
      valid=false
    fi
  fi

  # Method 6: submodule check
  if [[ "$method" == "6" ]]; then
    if [[ -f ".gitmodules" ]] && grep -q "$target" .gitmodules 2>/dev/null; then
      echo "✅ Submodule configured at $target"
    else
      echo "❌ Submodule path $target not in .gitmodules"
      valid=false
    fi
  fi

  # Final status
  if [[ "$valid" == true ]]; then
    echo "✅ Installation validated successfully"
    return 0
  else
    echo "❌ Installation validation failed"
    return 1
  fi
}

main() {
  parse_args "$@"

  echo "🚀 HVE-Core Remote Installer v${VERSION}"
  echo ""

  # Check git is available
  if ! command -v git &>/dev/null; then
    err "git is required but not installed"
  fi

  # Resolve auto to specific method
  if [[ "$METHOD" == "auto" ]]; then
    echo "🔍 Detecting environment..."
    METHOD=$(auto_detect_method)
    echo "   Detected method: $METHOD"
  fi

  # Validate method
  if ! [[ "$METHOD" =~ ^[1-6]$ ]]; then
    err "Invalid method: $METHOD (must be 1-6 or auto)"
  fi

  local target_path
  target_path=$(get_target_path "$METHOD" "$TARGET")

  echo ""
  echo "📦 Installing HVE-Core"
  echo "   Method: $METHOD"
  echo "   Target: $target_path"
  echo "   Branch: $BRANCH"
  echo ""

  # Method-specific installation
  case "$METHOD" in
    1|3|4)
      clone_hve_core "$target_path"
      ;;
    2)
      update_gitignore "$target_path"
      clone_hve_core "$target_path"
      ;;
    5)
      clone_hve_core "$target_path"
      create_workspace_file "$target_path"
      ;;
    6)
      add_submodule "$target_path"
      ;;
  esac

  # Configure settings (except method 5 which uses workspace file)
  if [[ "$METHOD" != "5" ]]; then
    configure_settings "$target_path"
  fi

  # Configure MCP servers if requested
  if [[ "$WITH_MCP" == true ]]; then
    configure_mcp
  fi

  # Run validation unless skipped
  if [[ "$SKIP_VALIDATE" == false ]]; then
    echo ""
    echo "🔍 Validating installation..."
    validate_installation "$METHOD" "$target_path"
  fi

  echo ""
  echo "✅ Installation complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Reload VS Code (Ctrl+Shift+P → 'Reload Window')"
  echo "  2. Open Copilot Chat (Ctrl+Alt+I)"
  echo "  3. Select an agent from the picker dropdown"
}

main "$@"
