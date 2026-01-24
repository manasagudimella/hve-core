<#
.SYNOPSIS
    Validate HVE-Core installation by checking required directories and method-specific configuration.

.DESCRIPTION
    Verifies that HVE-Core was installed correctly by checking for required directories
    (.github/agents, .github/prompts, .github/instructions) and method-specific configuration.

.PARAMETER Method
    Installation method number (1-6).

.PARAMETER BasePath
    Path to hve-core root directory.

.EXAMPLE
    ./validate.ps1 -Method 1 -BasePath ../hve-core

    Validates a peer clone installation.

.EXAMPLE
    ./validate.ps1 -Method 2 -BasePath .hve-core

    Validates a git-ignored installation.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 6)]
    [int]$Method,

    [Parameter(Mandatory = $true)]
    [string]$BasePath
)

$ErrorActionPreference = 'Stop'

$valid = $true

# Validate required directories exist
$requiredPaths = @(
    "$BasePath/.github/agents",
    "$BasePath/.github/prompts",
    "$BasePath/.github/instructions"
)

foreach ($path in $requiredPaths) {
    if (Test-Path $path) {
        Write-Host "✅ Found: $path"
    }
    else {
        Write-Host "❌ Missing: $path"
        $valid = $false
    }
}

# Method 5: workspace file check
if ($Method -eq 5) {
    if (Test-Path "hve-core.code-workspace") {
        try {
            $workspace = Get-Content "hve-core.code-workspace" -Raw | ConvertFrom-Json
            if ($workspace.folders.Count -ge 2) {
                Write-Host "✅ Multi-root configured"
            }
            else {
                Write-Host "❌ Multi-root not configured"
                $valid = $false
            }
        }
        catch {
            Write-Host "❌ Failed to parse workspace file: $_"
            $valid = $false
        }
    }
    else {
        Write-Host "❌ Workspace file not found: hve-core.code-workspace"
        $valid = $false
    }
}

# Method 6: submodule check
if ($Method -eq 6) {
    $escapedPath = [regex]::Escape($BasePath)
    if ((Test-Path ".gitmodules") -and (Select-String -Path ".gitmodules" -Pattern $escapedPath -Quiet)) {
        Write-Host "✅ Submodule configured at $BasePath"
    }
    else {
        Write-Host "❌ Submodule path $BasePath not in .gitmodules"
        $valid = $false
    }
}

# Final status
if ($valid) {
    Write-Host "✅ Installation validated successfully"
    exit 0
}
else {
    Write-Host "❌ Installation validation failed"
    exit 1
}
