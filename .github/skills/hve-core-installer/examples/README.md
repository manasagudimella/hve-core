# HVE-Core Installer Examples

This document provides usage examples for common installation scenarios.

## Solo Developer Local Setup (Method 1)

Clone HVE-Core as a sibling directory for local VS Code development:

```bash
cd ~/projects/my-project
./.github/skills/hve-core-installer/scripts/install.sh --method 1
```

```powershell
cd ~/projects/my-project
./.github/skills/hve-core-installer/scripts/install.ps1 -Method 1
```

Result:

* HVE-Core cloned to `../hve-core`
* Settings configured in `.vscode/settings.json`
* Agents accessible via Copilot Chat picker

## Devcontainer Isolation Setup (Method 2)

Clone HVE-Core inside your project with git exclusion:

```bash
./.github/skills/hve-core-installer/scripts/install.sh --method 2
```

```powershell
./.github/skills/hve-core-installer/scripts/install.ps1 -Method 2
```

Result:

* HVE-Core cloned to `.hve-core/`
* `.hve-core/` added to `.gitignore`
* Settings configured for container use

## GitHub Codespaces Setup (Method 4)

Install HVE-Core in a Codespaces environment:

```bash
./.github/skills/hve-core-installer/scripts/install.sh --method 4
```

```powershell
./.github/skills/hve-core-installer/scripts/install.ps1 -Method 4
```

Result:

* HVE-Core cloned to `/workspaces/hve-core`
* Settings configured for Codespaces paths

For persistent Codespaces setup, add to `devcontainer.json`:

```jsonc
{
  "postCreateCommand": "[ -d /workspaces/hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core"
}
```

## Team Submodule Setup (Method 6)

Add HVE-Core as a git submodule for team version control:

```bash
./.github/skills/hve-core-installer/scripts/install.sh --method 6
```

```powershell
./.github/skills/hve-core-installer/scripts/install.ps1 -Method 6
```

Result:

* HVE-Core added as submodule at `lib/hve-core`
* `.gitmodules` updated
* Team members clone with `git submodule update --init --recursive`

## Custom Path Installation

Override the default target path:

```bash
# Clone to custom location
./.github/skills/hve-core-installer/scripts/install.sh --method 2 --target .tools/hve-core

# Use method 1 with different directory name
./.github/skills/hve-core-installer/scripts/install.sh --method 1 --target ../hve-tools
```

```powershell
# Clone to custom location
./.github/skills/hve-core-installer/scripts/install.ps1 -Method 2 -Target .tools/hve-core

# Use method 1 with different directory name
./.github/skills/hve-core-installer/scripts/install.ps1 -Method 1 -Target ../hve-tools
```

## Install Into a Different Codebase

Use the `--workspace` parameter to install HVE-Core into another project:

```bash
# Install into another project from anywhere
./.github/skills/hve-core-installer/scripts/install.sh --workspace /path/to/my-project

# Install with specific method into target project
./.github/skills/hve-core-installer/scripts/install.sh --workspace ~/projects/my-app --method 1

# Combine workspace and custom target
./.github/skills/hve-core-installer/scripts/install.sh --workspace /projects/my-app --method 2 --target .tools/hve
```

```powershell
# Install into another project from anywhere
./.github/skills/hve-core-installer/scripts/install.ps1 -Workspace /path/to/my-project

# Install with specific method into target project
./.github/skills/hve-core-installer/scripts/install.ps1 -Workspace ~/projects/my-app -Method 1

# Combine workspace and custom target
./.github/skills/hve-core-installer/scripts/install.ps1 -Workspace /projects/my-app -Method 2 -Target .tools/hve
```

Result:

* Script changes to the workspace directory
* HVE-Core cloned relative to that directory
* Settings configured in workspace's `.vscode/settings.json`

This enables running the installer from hve-core to configure a target codebase.

## Validation-Only Run

Validate an existing installation without reinstalling:

```bash
# Validate peer clone installation
./.github/skills/hve-core-installer/scripts/validate.sh 1 ../hve-core

# Validate git-ignored installation
./.github/skills/hve-core-installer/scripts/validate.sh 2 .hve-core

# Validate submodule installation
./.github/skills/hve-core-installer/scripts/validate.sh 6 lib/hve-core
```

```powershell
# Validate peer clone installation
./.github/skills/hve-core-installer/scripts/validate.ps1 -Method 1 -BasePath ../hve-core

# Validate git-ignored installation
./.github/skills/hve-core-installer/scripts/validate.ps1 -Method 2 -BasePath .hve-core

# Validate submodule installation
./.github/skills/hve-core-installer/scripts/validate.ps1 -Method 6 -BasePath lib/hve-core
```

## Re-Running After Failed Installation

If installation fails, clean up and retry:

```bash
# Remove failed peer clone and retry
rm -rf ../hve-core
./.github/skills/hve-core-installer/scripts/install.sh --method 1

# Remove failed git-ignored clone and retry
rm -rf .hve-core
./.github/skills/hve-core-installer/scripts/install.sh --method 2

# Remove failed submodule and retry
git submodule deinit lib/hve-core
git rm lib/hve-core
rm -rf .git/modules/lib/hve-core
./.github/skills/hve-core-installer/scripts/install.sh --method 6
```

```powershell
# Remove failed peer clone and retry
Remove-Item -Recurse -Force ../hve-core
./.github/skills/hve-core-installer/scripts/install.ps1 -Method 1

# Remove failed git-ignored clone and retry
Remove-Item -Recurse -Force .hve-core
./.github/skills/hve-core-installer/scripts/install.ps1 -Method 2
```

## Quick Installation Without Validation

Skip validation for faster installation (useful in CI/CD):

```bash
./.github/skills/hve-core-installer/scripts/install.sh --method 1 --skip-validate
```

```powershell
./.github/skills/hve-core-installer/scripts/install.ps1 -Method 1 -SkipValidate
```

## Auto-Detection

Let the installer choose the best method for your environment:

```bash
./.github/skills/hve-core-installer/scripts/install.sh
```

```powershell
./.github/skills/hve-core-installer/scripts/install.ps1
```

Auto-detection logic:

* Codespaces detected → Method 4
* Devcontainer detected → Method 2
* Local environment → Method 1
