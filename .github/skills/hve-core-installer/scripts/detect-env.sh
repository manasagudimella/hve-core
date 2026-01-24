#!/usr/bin/env bash
#
# detect-env.sh
# Detect development environment for HVE-Core installation method selection

set -euo pipefail

main() {
  local env_type="local"
  local is_codespaces=false
  local is_devcontainer=false

  # Detect Codespaces via CODESPACES environment variable
  if [[ "${CODESPACES:-}" == "true" ]]; then
    env_type="codespaces"
    is_codespaces=true
    is_devcontainer=true
  # Detect devcontainer via /.dockerenv or REMOTE_CONTAINERS
  elif [[ -f "/.dockerenv" ]] || [[ "${REMOTE_CONTAINERS:-}" == "true" ]]; then
    env_type="devcontainer"
    is_devcontainer=true
  fi

  # Check for devcontainer.json existence
  local has_devcontainer_json=false
  [[ -f ".devcontainer/devcontainer.json" ]] && has_devcontainer_json=true

  # Check for workspace file existence
  local has_workspace_file=false
  if [[ -n "$(find . -maxdepth 1 -name '*.code-workspace' -print -quit 2>/dev/null)" ]]; then
    has_workspace_file=true
  fi

  # Detect if running inside hve-core repository itself
  local is_hve_core_repo=false
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -n "$repo_root" ]] && [[ "$(basename "$repo_root")" == "hve-core" ]]; then
    is_hve_core_repo=true
  fi

  # Output structured key-value pairs for parsing
  echo "ENV_TYPE=$env_type"
  echo "IS_CODESPACES=$is_codespaces"
  echo "IS_DEVCONTAINER=$is_devcontainer"
  echo "HAS_DEVCONTAINER_JSON=$has_devcontainer_json"
  echo "HAS_WORKSPACE_FILE=$has_workspace_file"
  echo "IS_HVE_CORE_REPO=$is_hve_core_repo"
}

main "$@"
