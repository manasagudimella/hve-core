<#
.SYNOPSIS
    Unified HVE-Core installation script supporting all 6 clone methods.

.DESCRIPTION
    Installs HVE-Core using one of 6 methods: peer clone, git-ignored, mounted,
    Codespaces, multi-root workspace, or submodule. Supports auto-detection of
    the appropriate method based on the environment.

.PARAMETER Method
    Installation method (1-6 or auto). Default: auto
    1 = Peer Clone (../hve-core)
    2 = Git-Ignored (.hve-core)
    3 = Mounted (/workspaces/hve-core)
    4 = Codespaces (/workspaces/hve-core)
    5 = Multi-Root (workspace file)
    6 = Submodule (lib/hve-core)

.PARAMETER Target
    Custom target path override.

.PARAMETER Workspace
    Target workspace/project directory. When specified, the script changes
    to this directory before installation, enabling installation into a
    different codebase.

.PARAMETER SkipValidate
    Skip post-installation validation.

.PARAMETER WithMcp
    Create MCP server configuration file for context7, microsoft-docs, and github servers.

.EXAMPLE
    ./install.ps1

    Auto-detect environment and install using recommended method.

.EXAMPLE
    ./install.ps1 -Method 1

    Install using peer clone method.

.EXAMPLE
    ./install.ps1 -Method 2 -Target .my-hve

    Install to custom target path using git-ignored method.

.EXAMPLE
    ./install.ps1 -Workspace /path/to/project

    Install HVE-Core into a different project directory.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^(auto|[1-6])$')]
    [string]$Method = "auto",

    [Parameter()]
    [string]$Target = "",

    [Parameter()]
    [string]$Workspace = "",

    [Parameter()]
    [switch]$SkipValidate,

    [Parameter()]
    [switch]$WithMcp
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-AutoDetectedMethod {
    # Source detection script and parse output
    $envOutput = & "$ScriptDir/detect-env.ps1" | Out-String

    $isCodespaces = $envOutput -match "IS_CODESPACES=true"
    $isDevcontainer = $envOutput -match "IS_DEVCONTAINER=true"

    # Auto-detection logic from plan
    if ($isCodespaces) {
        return "4"  # Codespaces
    }
    elseif ($isDevcontainer) {
        return "2"  # Git-Ignored for devcontainer
    }
    else {
        return "1"  # Peer Clone for local
    }
}

function Get-TargetPath {
    param(
        [string]$MethodNum,
        [string]$CustomTarget
    )

    if ($CustomTarget) {
        return $CustomTarget
    }

    switch ($MethodNum) {
        "1" { return "../hve-core" }
        "2" { return ".hve-core" }
        "3" { return "/workspaces/hve-core" }
        "4" { return "/workspaces/hve-core" }
        "5" { return "../hve-core" }
        "6" { return "lib/hve-core" }
        default { throw "Invalid method: $MethodNum" }
    }
}

function Invoke-CloneHveCore {
    param([string]$TargetPath)

    if (Test-Path $TargetPath) {
        Write-Host "⏭️  HVE-Core already exists at $TargetPath"
        return
    }

    Write-Host "📥 Cloning HVE-Core to $TargetPath..."
    git clone https://github.com/microsoft/hve-core.git $TargetPath
    Write-Host "✅ Cloned HVE-Core to $TargetPath"
}

function Add-Submodule {
    param([string]$TargetPath)

    if (Test-Path $TargetPath) {
        Write-Host "⏭️  HVE-Core submodule already exists at $TargetPath"
        return
    }

    Write-Host "📥 Adding HVE-Core as submodule to $TargetPath..."
    git submodule add https://github.com/microsoft/hve-core.git $TargetPath
    git submodule update --init --recursive
    Write-Host "✅ Added HVE-Core as submodule to $TargetPath"
}

function Update-Gitignore {
    param([string]$TargetPath)

    $gitignore = ".gitignore"
    $pattern = "^$([regex]::Escape($TargetPath))/?$"

    if ((Test-Path $gitignore) -and (Get-Content $gitignore -Raw) -match $pattern) {
        return
    }

    Write-Host "📝 Adding $TargetPath/ to .gitignore..."
    Add-Content -Path $gitignore -Value ""
    Add-Content -Path $gitignore -Value "# HVE-Core local installation"
    Add-Content -Path $gitignore -Value "$TargetPath/"
}

function Set-VscodeSettings {
    param([string]$Prefix)

    $settingsDir = ".vscode"
    $settingsFile = "$settingsDir/settings.json"

    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }

    if (Test-Path $settingsFile) {
        Write-Host "⚠️  Settings file exists at $settingsFile"
        Write-Host "   Add the following paths manually if needed:"
        Write-Host "   - $Prefix/.github/agents"
        Write-Host "   - $Prefix/.github/prompts"
        Write-Host "   - $Prefix/.github/instructions"
    }
    else {
        Write-Host "📝 Creating $settingsFile..."
        $settings = @{
            "chat.modeFilesLocations" = @{
                ".github/agents" = $true
                "$Prefix/.github/agents" = $true
            }
            "chat.agentFilesLocations" = @{
                ".github/agents" = $true
                "$Prefix/.github/agents" = $true
            }
            "chat.promptFilesLocations" = @{
                ".github/prompts" = $true
                "$Prefix/.github/prompts" = $true
            }
            "chat.instructionsFilesLocations" = @{
                ".github/instructions" = $true
                "$Prefix/.github/instructions" = $true
            }
        }
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile -NoNewline
        Write-Host "✅ Created settings file"
    }
}

function New-WorkspaceFile {
    param([string]$TargetPath)

    $workspaceFile = "hve-core.code-workspace"

    if (Test-Path $workspaceFile) {
        Write-Host "⏭️  Workspace file already exists: $workspaceFile"
        return
    }

    Write-Host "📝 Creating workspace file..."
    $workspace = @{
        folders = @(
            @{ name = "Project"; path = "." }
            @{ name = "HVE-Core"; path = $TargetPath }
        )
        settings = @{
            "chat.modeFilesLocations" = @{
                ".github/agents" = $true
                "$TargetPath/.github/agents" = $true
            }
            "chat.agentFilesLocations" = @{
                ".github/agents" = $true
                "$TargetPath/.github/agents" = $true
            }
            "chat.promptFilesLocations" = @{
                ".github/prompts" = $true
                "$TargetPath/.github/prompts" = $true
            }
            "chat.instructionsFilesLocations" = @{
                ".github/instructions" = $true
                "$TargetPath/.github/instructions" = $true
            }
        }
    }
    $workspace | ConvertTo-Json -Depth 10 | Set-Content -Path $workspaceFile -NoNewline
    Write-Host "✅ Created workspace file: $workspaceFile"
    Write-Host "   Open this file in VS Code to use multi-root workspace"
}

function Set-McpConfiguration {
    $settingsDir = ".vscode"
    $mcpFile = "$settingsDir/mcp.json"

    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }

    if (Test-Path $mcpFile) {
        Write-Host "⏭️  MCP configuration already exists at $mcpFile"
        return
    }

    Write-Host "📝 Creating MCP configuration..."
    $mcpConfig = @{
        inputs = @(
            @{
                id = "ado_org"
                type = "promptString"
                description = "Azure DevOps organization name (e.g. 'contoso')"
                default = ""
            }
            @{
                id = "ado_tenant"
                type = "promptString"
                description = "Azure tenant ID (required for multi-tenant scenarios)"
                default = ""
            }
        )
        servers = @{
            "context7" = @{
                type = "stdio"
                command = "npx"
                args = @("-y", "@upstash/context7-mcp")
            }
            "microsoft-docs" = @{
                type = "http"
                url = "https://learn.microsoft.com/api/mcp"
            }
            "github" = @{
                type = "http"
                url = "https://api.githubcopilot.com/mcp/"
            }
        }
    }
    $mcpConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $mcpFile -NoNewline
    Write-Host "✅ Created MCP configuration"
    Write-Host "   See docs/getting-started/mcp-configuration.md for ADO setup"
}

# Check git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required but not installed"
}

# Change to workspace directory if specified
if ($Workspace) {
    if (-not (Test-Path $Workspace -PathType Container)) {
        throw "Workspace directory does not exist: $Workspace"
    }
    Write-Host "📂 Changing to workspace: $Workspace"
    Push-Location $Workspace
}

try {

# Resolve auto to specific method
if ($Method -eq "auto") {
    Write-Host "🔍 Detecting environment..."
    $Method = Get-AutoDetectedMethod
    Write-Host "   Detected method: $Method"
}

$targetPath = Get-TargetPath -MethodNum $Method -CustomTarget $Target
$settingsPrefix = $targetPath

Write-Host ""
Write-Host "📦 Installing HVE-Core"
Write-Host "   Method: $Method"
Write-Host "   Target: $targetPath"
Write-Host ""

# Method-specific installation
switch ($Method) {
    "1" { Invoke-CloneHveCore -TargetPath $targetPath }
    "2" {
        Update-Gitignore -TargetPath $targetPath
        Invoke-CloneHveCore -TargetPath $targetPath
    }
    "3" { Invoke-CloneHveCore -TargetPath $targetPath }
    "4" { Invoke-CloneHveCore -TargetPath $targetPath }
    "5" {
        Invoke-CloneHveCore -TargetPath $targetPath
        New-WorkspaceFile -TargetPath $targetPath
    }
    "6" { Add-Submodule -TargetPath $targetPath }
}

# Configure settings (except method 5 which uses workspace file)
if ($Method -ne "5") {
    Set-VscodeSettings -Prefix $settingsPrefix
}

# Configure MCP servers if requested
if ($WithMcp) {
    Set-McpConfiguration
}

# Run validation unless skipped
if (-not $SkipValidate) {
    Write-Host ""
    Write-Host "🔍 Validating installation..."
    & "$ScriptDir/validate.ps1" -Method ([int]$Method) -BasePath $targetPath
}

Write-Host ""
Write-Host "✅ Installation complete!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Reload VS Code (Ctrl+Shift+P → 'Reload Window')"
Write-Host "  2. Open Copilot Chat (Ctrl+Alt+I)"
Write-Host "  3. Select an agent from the picker dropdown"

}
finally {
    if ($Workspace) {
        Pop-Location
    }
}
