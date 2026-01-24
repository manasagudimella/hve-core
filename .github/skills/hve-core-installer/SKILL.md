---
name: hve-core-installer
description: 'HVE-Core installation skill with 6 methods for local, devcontainer, and Codespaces environments - Brought to you by microsoft/hve-core'
maturity: stable
---

# HVE-Core Installer Skill

This skill automates HVE-Core installation with 6 methods supporting local, devcontainer, and Codespaces environments. It provides environment detection, installation scripts, and post-installation validation.

## Overview

The skill bundles cross-platform scripts for:

* Environment detection (local, devcontainer, Codespaces)
* Installation via clone or submodule
* VS Code settings configuration
* Post-installation validation

Use this skill when you need programmatic installation or want to integrate HVE-Core setup into automation workflows.

## Extension Alternative

For zero-configuration installation without scripts, use the VS Code Extension:

```bash
code --install-extension ise-hve-essentials.hve-core
```

The extension is recommended when:

* You want the simplest setup with automatic updates
* You don't need to customize agents, prompts, or instructions
* You work across multiple machines with VS Code Settings Sync

See [extension.md](../../../docs/getting-started/methods/extension.md) for details. The extension is a separate installation method and does not use the scripts in this skill.

## Response Format

After successful installation, include the absolute path to any created files:

```markdown
/absolute/path/to/.vscode/settings.json
```

## Prerequisites

### Required

* Git installed and in PATH
* Write permissions to workspace `.vscode/` directory

### Platform-Specific

| Platform | Shell Requirement |
| -------- | ----------------- |
| macOS    | bash or zsh       |
| Linux    | bash              |
| Windows  | PowerShell 7+     |

### Optional

* jq for bash workspace file validation (Method 5)

Verify prerequisites:

```bash
git --version
```

```powershell
$PSVersionTable.PSVersion
```

## Quick Start

Install with auto-detection:

```bash
./.github/skills/hve-core-installer/scripts/install.sh
```

```powershell
./.github/skills/hve-core-installer/scripts/install.ps1
```

The script detects your environment and selects the appropriate installation method.

### Remote Installation (curl)

Install HVE-Core without cloning the repository first:

```bash
curl -sSL https://raw.githubusercontent.com/microsoft/hve-core/main/.github/skills/hve-core-installer/scripts/remote-install.sh | bash
```

With options:

```bash
# Use specific method
curl -sSL https://raw.githubusercontent.com/microsoft/hve-core/main/.github/skills/hve-core-installer/scripts/remote-install.sh | bash -s -- --method 2

# Clone specific branch
curl -sSL https://raw.githubusercontent.com/microsoft/hve-core/main/.github/skills/hve-core-installer/scripts/remote-install.sh | bash -s -- --branch develop
```

Environment variables for CI/CD:

```bash
HVE_METHOD=2 HVE_BRANCH=main curl -sSL https://raw.githubusercontent.com/microsoft/hve-core/main/.github/skills/hve-core-installer/scripts/remote-install.sh | bash
```

## Parameters Reference

### install.sh / install.ps1

| Parameter | Flag (bash) | Flag (PowerShell) | Default | Description |
| --------- | ----------- | ----------------- | ------- | ----------- |
| Method | `--method` | `-Method` | auto | Installation method (1-6 or auto) |
| Target | `--target` | `-Target` | (per method) | Custom target path override |
| Workspace | `--workspace` | `-Workspace` | (current dir) | Target workspace/project directory |
| With MCP | `--with-mcp` | `-WithMcp` | false | Create MCP server configuration |
| Skip validation | `--skip-validate` | `-SkipValidate` | false | Skip post-installation validation |

### remote-install.sh

| Parameter | Flag | Environment Variable | Default | Description |
| --------- | ---- | -------------------- | ------- | ----------- |
| Method | `--method` | `HVE_METHOD` | auto | Installation method (1-6 or auto) |
| Target | `--target` | `HVE_TARGET` | (per method) | Custom target path override |
| Branch | `--branch` | `HVE_BRANCH` | main | Branch to clone |
| With MCP | `--with-mcp` | `HVE_WITH_MCP` | false | Create MCP server configuration |
| Skip validation | `--skip-validate` | - | false | Skip post-installation validation |

### validate.sh / validate.ps1

| Parameter | Position (bash) | Flag (PowerShell) | Required | Description |
| --------- | --------------- | ----------------- | -------- | ----------- |
| Method | 1 | `-Method` | Yes | Installation method number (1-6) |
| Base path | 2 | `-BasePath` | Yes | Path to hve-core root directory |

## Installation Methods

Use the decision matrix to select the appropriate method:

| Environment | Team | Updates | Recommended Method |
| ----------- | ---- | ------- | ------------------ |
| Local (no container) | Solo | - | Method 1: Peer Clone |
| Local (no container) | Team | Controlled | Method 6: Submodule |
| Local devcontainer | Solo | Auto | Method 2: Git-Ignored |
| Local devcontainer | Team | Controlled | Method 6: Submodule |
| Codespaces only | Solo | Auto | Method 4: Codespaces |
| Codespaces only | Team | Controlled | Method 6: Submodule |
| Both local + Codespaces | Any | Any | Method 5: Multi-Root |

## Method Reference

| Method | Name | Target Location | Settings Prefix | Use Case | Documentation |
| ------ | ---- | --------------- | --------------- | -------- | ------------- |
| 1 | Peer Clone | `../hve-core` | `../hve-core` | Local VS Code, solo | [peer-clone.md](../../../docs/getting-started/methods/peer-clone.md) |
| 2 | Git-Ignored | `.hve-core` | `.hve-core` | Devcontainer, isolation | [git-ignored.md](../../../docs/getting-started/methods/git-ignored.md) |
| 3 | Mounted | `/workspaces/hve-core` | `/workspaces/hve-core` | Devcontainer + host clone | [mounted.md](../../../docs/getting-started/methods/mounted.md) |
| 4 | Codespaces | `/workspaces/hve-core` | `/workspaces/hve-core` | GitHub Codespaces | [codespaces.md](../../../docs/getting-started/methods/codespaces.md) |
| 5 | Multi-Root | Per workspace file | Per workspace file | Best IDE integration | [multi-root.md](../../../docs/getting-started/methods/multi-root.md) |
| 6 | Submodule | `lib/hve-core` | `lib/hve-core` | Team version control | [submodule.md](../../../docs/getting-started/methods/submodule.md) |

## Script Reference

### Environment Detection

Detect the current environment:

```bash
./.github/skills/hve-core-installer/scripts/detect-env.sh
```

```powershell
./.github/skills/hve-core-installer/scripts/detect-env.ps1
```

Output format:

```text
ENV_TYPE=local|devcontainer|codespaces
IS_CODESPACES=true|false
IS_DEVCONTAINER=true|false
HAS_DEVCONTAINER_JSON=true|false
HAS_WORKSPACE_FILE=true|false
IS_HVE_CORE_REPO=true|false
```

### Installation

Install with specific method:

```bash
# Auto-detect environment
./install.sh

# Use specific method
./install.sh --method 1

# Custom target path
./install.sh --method 2 --target .my-hve

# Install into a different project
./install.sh --workspace /path/to/my-project

# Skip validation
./install.sh --method 1 --skip-validate
```

```powershell
# Auto-detect environment
./install.ps1

# Use specific method
./install.ps1 -Method 1

# Custom target path
./install.ps1 -Method 2 -Target .my-hve

# Install into a different project
./install.ps1 -Workspace /path/to/my-project

# Skip validation
./install.ps1 -Method 1 -SkipValidate
```

### Validation

Validate an existing installation:

```bash
./validate.sh 1 ../hve-core
./validate.sh 2 .hve-core
./validate.sh 4 /workspaces/hve-core
```

```powershell
./validate.ps1 -Method 1 -BasePath ../hve-core
./validate.ps1 -Method 2 -BasePath .hve-core
./validate.ps1 -Method 4 -BasePath /workspaces/hve-core
```

## Environment Detection

The detection script identifies:

| Variable | Description |
| -------- | ----------- |
| ENV_TYPE | Environment type: local, devcontainer, or codespaces |
| IS_CODESPACES | Running in GitHub Codespaces |
| IS_DEVCONTAINER | Running in any container environment |
| HAS_DEVCONTAINER_JSON | Project has .devcontainer/devcontainer.json |
| HAS_WORKSPACE_FILE | Project has a .code-workspace file |
| IS_HVE_CORE_REPO | Currently inside the hve-core repository |

Detection methods:

* Codespaces: `$CODESPACES` environment variable
* Devcontainer: `/.dockerenv` file or `$REMOTE_CONTAINERS` variable
* Workspace file: `*.code-workspace` in current directory
* HVE-Core repo: Git root directory name equals "hve-core"

## Settings Configuration

The installation script creates `.vscode/settings.json` with this structure:

```json
{
  "chat.modeFilesLocations": {
    ".github/agents": true,
    "<PREFIX>/.github/agents": true
  },
  "chat.agentFilesLocations": {
    ".github/agents": true,
    "<PREFIX>/.github/agents": true
  },
  "chat.promptFilesLocations": {
    ".github/prompts": true,
    "<PREFIX>/.github/prompts": true
  },
  "chat.instructionsFilesLocations": {
    ".github/instructions": true,
    "<PREFIX>/.github/instructions": true
  }
}
```

Replace `<PREFIX>` with the target path for your method.

## Troubleshooting

### Git not found

Verify git is in your PATH:

```bash
which git       # macOS/Linux
where.exe git   # Windows
```

Install git if missing, then ensure it's in your PATH.

### Clone failed

Check network connectivity to github.com. Verify git credentials are configured for HTTPS access. Ensure you have write permissions to the target directory.

### Validation failed

The repository may be incomplete. Delete the HVE-Core directory and re-run the installer:

```bash
rm -rf ../hve-core && ./install.sh --method 1
```

### Settings update failed

Verify `.vscode/settings.json` contains valid JSON. Close VS Code before modifying settings. Check write permissions to the `.vscode/` directory.

### Method 3 (Mounted) requires host setup

Method 3 requires cloning HVE-Core on the host machine before container setup:

1. Clone HVE-Core on host: `git clone https://github.com/microsoft/hve-core.git`
2. Add mount to devcontainer.json
3. Rebuild container
4. Run validation after rebuild

### jq not installed

Install jq for full workspace file validation:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

Without jq, Method 5 validation shows a warning but continues.

### Devcontainer rebuild required

Methods 3-4 require a container rebuild after configuration changes. After modifying devcontainer.json, rebuild the container and run validation.

*Crafted with precision by Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
