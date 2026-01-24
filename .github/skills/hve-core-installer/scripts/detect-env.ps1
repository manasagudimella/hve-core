<#
.SYNOPSIS
    Detect development environment for HVE-Core installation method selection.

.DESCRIPTION
    Detects whether the current environment is local, devcontainer, or Codespaces.
    Outputs structured key-value pairs for use by installation scripts.

.EXAMPLE
    ./detect-env.ps1

    Outputs environment detection results as key-value pairs.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Detect environment type
$envType = "local"
$isCodespaces = $false
$isDevcontainer = $false

if ($env:CODESPACES -eq "true") {
    $envType = "codespaces"
    $isCodespaces = $true
    $isDevcontainer = $true
}
elseif ((Test-Path "/.dockerenv") -or ($env:REMOTE_CONTAINERS -eq "true")) {
    $envType = "devcontainer"
    $isDevcontainer = $true
}

# Check for devcontainer.json existence
$hasDevcontainerJson = Test-Path ".devcontainer/devcontainer.json"

# Check for workspace file existence
$hasWorkspaceFile = (Get-ChildItem -Filter "*.code-workspace" -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0

# Detect if running inside hve-core repository itself
$isHveCoreRepo = $false
try {
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if ($repoRoot -and (Split-Path $repoRoot -Leaf) -eq "hve-core") {
        $isHveCoreRepo = $true
    }
}
catch {
    $isHveCoreRepo = $false
}

# Output structured key-value pairs for parsing
Write-Host "ENV_TYPE=$envType"
Write-Host "IS_CODESPACES=$($isCodespaces.ToString().ToLower())"
Write-Host "IS_DEVCONTAINER=$($isDevcontainer.ToString().ToLower())"
Write-Host "HAS_DEVCONTAINER_JSON=$($hasDevcontainerJson.ToString().ToLower())"
Write-Host "HAS_WORKSPACE_FILE=$($hasWorkspaceFile.ToString().ToLower())"
Write-Host "IS_HVE_CORE_REPO=$($isHveCoreRepo.ToString().ToLower())"
