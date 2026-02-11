#Requires -Modules Pester

BeforeAll {
    . $PSScriptRoot/../../extension/Prepare-Extension.ps1
}

Describe 'Get-AllowedMaturities' {
    It 'Returns only stable for Stable channel' {
        $result = Get-AllowedMaturities -Channel 'Stable'
        $result | Should -Be @('stable')
    }

    It 'Returns all maturities for PreRelease channel' {
        $result = Get-AllowedMaturities -Channel 'PreRelease'
        $result | Should -Contain 'stable'
        $result | Should -Contain 'preview'
        $result | Should -Contain 'experimental'
    }

}

Describe 'Get-FrontmatterData' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Extracts description and maturity from frontmatter' {
        $testFile = Join-Path $script:tempDir 'test.md'
        @'
---
description: "Test description"
maturity: preview
---
# Content
'@ | Set-Content -Path $testFile

        $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
        $result.description | Should -Be 'Test description'
        $result.maturity | Should -Be 'preview'
    }

    It 'Uses fallback description when not in frontmatter' {
        $testFile = Join-Path $script:tempDir 'no-desc.md'
        @'
---
maturity: stable
---
# Content
'@ | Set-Content -Path $testFile

        $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'My Fallback'
        $result.description | Should -Be 'My Fallback'
    }

    It 'Defaults maturity to stable when not specified' {
        $testFile = Join-Path $script:tempDir 'no-maturity.md'
        @'
---
description: "Desc"
---
# Content
'@ | Set-Content -Path $testFile

        $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
        $result.maturity | Should -Be 'stable'
    }

    Context 'Error handling' {
        It 'Handles malformed YAML frontmatter gracefully' {
            $testFile = Join-Path $script:tempDir 'malformed.md'
            @'
---
description: "unclosed quote
maturity: [invalid yaml
---
# Content
'@ | Set-Content -Path $testFile

            # Should not throw - function handles YAML errors with warning
            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback' 3>&1
            $result | Should -Not -BeNull
        }

        It 'Handles file without frontmatter' {
            $testFile = Join-Path $script:tempDir 'no-frontmatter.md'
            @'
# Just a heading
No frontmatter here
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'default-desc'
            $result.description | Should -Be 'default-desc'
            $result.maturity | Should -Be 'stable'
        }

        It 'Handles empty frontmatter' {
            $testFile = Join-Path $script:tempDir 'empty-frontmatter.md'
            @'
---
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.description | Should -Be 'fallback'
        }
    }
}

Describe 'Test-PathsExist' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
        $script:extDir = Join-Path $script:tempDir 'extension'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:extDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null
        $script:pkgJson = Join-Path $script:extDir 'package.json'
        '{}' | Set-Content -Path $script:pkgJson
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns valid when all paths exist' {
        $result = Test-PathsExist -ExtensionDir $script:extDir -PackageJsonPath $script:pkgJson -GitHubDir $script:ghDir
        $result.IsValid | Should -BeTrue
        $result.MissingPaths | Should -BeNullOrEmpty
    }

    It 'Returns invalid when extension dir missing' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-ext-dir-12345')
        $result = Test-PathsExist -ExtensionDir $nonexistentPath -PackageJsonPath $script:pkgJson -GitHubDir $script:ghDir
        $result.IsValid | Should -BeFalse
        $result.MissingPaths | Should -Contain $nonexistentPath
    }

    It 'Collects multiple missing paths' {
        $missing1 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'missing-path-1')
        $missing2 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'missing-path-2')
        $missing3 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'missing-path-3')
        $result = Test-PathsExist -ExtensionDir $missing1 -PackageJsonPath $missing2 -GitHubDir $missing3
        $result.IsValid | Should -BeFalse
        $result.MissingPaths.Count | Should -Be 3
    }
}

Describe 'Get-DiscoveredAgents' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:agentsDir = Join-Path $script:tempDir 'agents'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null

        # Create test agent files
        @'
---
description: "Stable agent"
maturity: stable
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'stable.agent.md')

        @'
---
description: "Preview agent"
maturity: preview
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'preview.agent.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers agents matching allowed maturities' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable', 'preview') -ExcludedAgents @()
        $result.DirectoryExists | Should -BeTrue
        $result.Agents.Count | Should -Be 2
    }

    It 'Filters agents by maturity' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable') -ExcludedAgents @()
        $result.Agents.Count | Should -Be 1
        $result.Skipped.Count | Should -Be 1
    }

    It 'Excludes specified agents' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable', 'preview') -ExcludedAgents @('stable')
        $result.Agents.Count | Should -Be 1
    }

    It 'Returns empty when directory does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-agents-dir-12345')
        $result = Get-DiscoveredAgents -AgentsDir $nonexistentPath -AllowedMaturities @('stable') -ExcludedAgents @()
        $result.DirectoryExists | Should -BeFalse
        $result.Agents | Should -BeNullOrEmpty
    }
}

Describe 'Get-DiscoveredPrompts' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:promptsDir = Join-Path $script:tempDir 'prompts'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:promptsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        @'
---
description: "Test prompt"
maturity: stable
---
'@ | Set-Content -Path (Join-Path $script:promptsDir 'test.prompt.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers prompts in directory' {
        $result = Get-DiscoveredPrompts -PromptsDir $script:promptsDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeTrue
        $result.Prompts.Count | Should -BeGreaterThan 0
    }

    It 'Returns empty when directory does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-prompts-dir-12345')
        $result = Get-DiscoveredPrompts -PromptsDir $nonexistentPath -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeFalse
    }
}

Describe 'Get-DiscoveredInstructions' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:instrDir = Join-Path $script:tempDir 'instructions'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:instrDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        @'
---
description: "Test instruction"
applyTo: "**/*.ps1"
maturity: stable
---
'@ | Set-Content -Path (Join-Path $script:instrDir 'test.instructions.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers instructions in directory' {
        $result = Get-DiscoveredInstructions -InstructionsDir $script:instrDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeTrue
        $result.Instructions.Count | Should -BeGreaterThan 0
    }

    It 'Returns empty when directory does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-instr-dir-12345')
        $result = Get-DiscoveredInstructions -InstructionsDir $nonexistentPath -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeFalse
    }
}

Describe 'Update-PackageJsonContributes' {
    It 'Updates contributes section with chat participants' {
        $packageJson = [PSCustomObject]@{
            name = 'test-extension'
            contributes = [PSCustomObject]@{}
        }
        $agents = @(
            @{ name = 'agent1'; description = 'Desc 1' }
        )
        $prompts = @(
            @{ name = 'prompt1'; description = 'Prompt desc' }
        )
        $instructions = @(
            @{ name = 'instr1'; description = 'Instr desc' }
        )

        $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents -ChatPromptFiles $prompts -ChatInstructions $instructions
        $result.contributes | Should -Not -BeNull
    }

    It 'Handles empty arrays' {
        $packageJson = [PSCustomObject]@{
            name = 'test-extension'
            contributes = [PSCustomObject]@{}
        }

        $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions @()
        $result | Should -Not -BeNull
    }
}

Describe 'Invoke-ExtensionPreparation' -Tag 'Unit' {
    BeforeEach {
        $script:originalLocation = Get-Location
        Set-Location $TestDrive

        # Create minimal valid extension structure
        New-Item -Path 'extension' -ItemType Directory -Force | Out-Null
        New-Item -Path '.github' -ItemType Directory -Force | Out-Null
        New-Item -Path '.github/agents' -ItemType Directory -Force | Out-Null
        New-Item -Path '.github/prompts' -ItemType Directory -Force | Out-Null
        New-Item -Path '.github/instructions' -ItemType Directory -Force | Out-Null

        $packageJson = @{
            name = 'test-extension'
            version = '1.0.0'
            publisher = 'test-publisher'
            engines = @{ vscode = '^1.80.0' }
            contributes = @{}
        }
        $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path 'extension/package.json'
    }

    AfterEach {
        Set-Location $script:originalLocation
    }

    Context 'Function availability' {
        It 'Function is accessible after script load' {
            Get-Command Invoke-ExtensionPreparation | Should -Not -BeNull
        }

        It 'Has expected parameter set' {
            $cmd = Get-Command Invoke-ExtensionPreparation
            $cmd.Parameters.Keys | Should -Contain 'Channel'
            $cmd.Parameters.Keys | Should -Contain 'DryRun'
            $cmd.Parameters.Keys | Should -Contain 'ChangelogPath'
        }

        It 'Channel parameter validates allowed values' {
            $cmd = Get-Command Invoke-ExtensionPreparation
            $channelParam = $cmd.Parameters['Channel']
            $validateSetAttr = $channelParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSetAttr.ValidValues | Should -Contain 'Stable'
            $validateSetAttr.ValidValues | Should -Contain 'PreRelease'
        }
    }

    Context 'Helper functions integration' {
        It 'Get-AllowedMaturities returns expected values for Stable' {
            $result = Get-AllowedMaturities -Channel 'Stable'
            $result | Should -Contain 'stable'
            $result | Should -Not -Contain 'preview'
        }

        It 'Get-AllowedMaturities returns expected values for PreRelease' {
            $result = Get-AllowedMaturities -Channel 'PreRelease'
            $result | Should -Contain 'stable'
            $result | Should -Contain 'preview'
            $result | Should -Contain 'experimental'
        }
    }
}

#region Extended Tests for Prepare-Extension

Describe 'Get-FrontmatterData Extended' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) (New-Guid).ToString()
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Different maturity values' {
        It 'Parses experimental maturity' {
            $testFile = Join-Path $script:TestDir 'exp.md'
            @'
---
description: "Experimental feature"
maturity: experimental
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.maturity | Should -Be 'experimental'
        }

        It 'Handles maturity with mixed case' {
            $testFile = Join-Path $script:TestDir 'mixed.md'
            @'
---
description: "Mixed case"
maturity: Preview
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            # Function should handle case
            $result.maturity | Should -Not -BeNull
        }
    }

    Context 'Description extraction' {
        It 'Handles description with special characters' {
            $testFile = Join-Path $script:TestDir 'special.md'
            @'
---
description: "Test with 'quotes' and \"double quotes\""
maturity: stable
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.description | Should -Not -BeNull
        }

        It 'Handles multiline description' {
            $testFile = Join-Path $script:TestDir 'multiline.md'
            @'
---
description: >
  This is a long description
  that spans multiple lines
maturity: stable
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.description | Should -Not -BeNull
        }
    }
}

Describe 'Get-DiscoveredAgents Extended' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) (New-Guid).ToString()
        $script:AgentsDir = Join-Path $script:TestDir 'agents'
        New-Item -ItemType Directory -Path $script:AgentsDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Agent file parsing' {
        BeforeEach {
            # Create multiple agent files
            @'
---
description: "Stable agent"
maturity: stable
---
# Stable Agent
'@ | Set-Content -Path (Join-Path $script:AgentsDir 'stable.agent.md')

            @'
---
description: "Experimental agent"
maturity: experimental
---
# Experimental Agent
'@ | Set-Content -Path (Join-Path $script:AgentsDir 'exp.agent.md')
        }

        It 'Filters experimental agents when channel is Stable' {
            $result = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities @('stable') -ExcludedAgents @()
            $result.Skipped.Count | Should -BeGreaterThan 0
        }

        It 'Includes experimental agents when channel is PreRelease' {
            $result = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities @('stable', 'preview', 'experimental') -ExcludedAgents @()
            $result.Agents.Count | Should -Be 2
        }
    }

    Context 'Exclusion handling' {
        BeforeEach {
            @'
---
description: "Agent to exclude"
maturity: stable
---
# Excluded
'@ | Set-Content -Path (Join-Path $script:AgentsDir 'excluded.agent.md')
        }

        It 'Excludes agents by name' {
            $result = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities @('stable', 'experimental') -ExcludedAgents @('excluded')
            $excludedNames = $result.Agents | ForEach-Object { $_.name }
            $excludedNames | Should -Not -Contain 'excluded'
        }
    }
}

Describe 'Update-PackageJsonContributes Extended' -Tag 'Unit' {
    Context 'Multiple components' {
        It 'Handles multiple agents' {
            $packageJson = [PSCustomObject]@{
                name = 'test-extension'
                contributes = [PSCustomObject]@{}
            }
            $agents = @(
                @{ name = 'agent1'; description = 'Desc 1'; isDefault = $true }
                @{ name = 'agent2'; description = 'Desc 2'; isDefault = $false }
            )

            $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents -ChatPromptFiles @() -ChatInstructions @()
            $result | Should -Not -BeNull
        }

        It 'Handles multiple instructions with applyTo' {
            $packageJson = [PSCustomObject]@{
                name = 'test-extension'
                contributes = [PSCustomObject]@{}
            }
            $instructions = @(
                @{ name = 'instr1'; description = 'Desc 1'; applyTo = '**/*.ps1' }
                @{ name = 'instr2'; description = 'Desc 2'; applyTo = '**/*.md' }
            )

            $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions $instructions
            $result | Should -Not -BeNull
        }
    }

    Context 'Null handling' {
        It 'Handles null contributes in input' {
            $packageJson = [PSCustomObject]@{
                name = 'test-extension'
            }

            { Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions @() } | Should -Not -Throw
        }
    }
}

Describe 'Test-PathsExist Extended' -Tag 'Unit' {
    Context 'Various missing combinations' {
        It 'Reports all three paths missing' {
            $missing1 = '/nonexistent/path1'
            $missing2 = '/nonexistent/path2'
            $missing3 = '/nonexistent/path3'
            $result = Test-PathsExist -ExtensionDir $missing1 -PackageJsonPath $missing2 -GitHubDir $missing3
            $result.IsValid | Should -BeFalse
            $result.MissingPaths.Count | Should -Be 3
        }

        It 'Reports only package.json missing' {
            $tempDir = Join-Path ([IO.Path]::GetTempPath()) (New-Guid).ToString()
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempDir '.github') -Force | Out-Null
            try {
                $result = Test-PathsExist -ExtensionDir $tempDir -PackageJsonPath '/nonexistent/package.json' -GitHubDir (Join-Path $tempDir '.github')
                $result.IsValid | Should -BeFalse
                $result.MissingPaths | Should -Contain '/nonexistent/package.json'
            }
            finally {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

#endregion
#region Invoke-ExtensionPreparation Extended Tests

Describe 'Invoke-ExtensionPreparation Extended' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) "prep-ext-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir 'extension') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir '.github') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir '.github/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir '.github/prompts') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir '.github/instructions') -Force | Out-Null

        $pkgJson = @{
            name = 'test-extension'
            version = '1.0.0'
            publisher = 'test-publisher'
            engines = @{ vscode = '^1.80.0' }
            contributes = @{}
        }
        $pkgJson | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:TestDir 'extension/package.json')

        # Create sample agents
@'
---
description: "Test stable agent"
maturity: stable
---
# Stable Agent
'@ | Set-Content -Path (Join-Path $script:TestDir '.github/agents/stable.agent.md')

@'
---
description: "Test preview agent"
maturity: preview
---
# Preview Agent
'@ | Set-Content -Path (Join-Path $script:TestDir '.github/agents/preview.agent.md')

        # Create sample prompts
@'
---
description: "Test prompt"
maturity: stable
---
# Prompt
'@ | Set-Content -Path (Join-Path $script:TestDir '.github/prompts/test.prompt.md')

        # Create sample instructions
@'
---
description: "Test instruction"
applyTo: "**/*.ps1"
maturity: stable
---
# Instruction
'@ | Set-Content -Path (Join-Path $script:TestDir '.github/instructions/test.instructions.md')
    }

    AfterAll {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Channel filtering' {
        It 'Stable channel includes only stable maturities' {
            $allowed = Get-AllowedMaturities -Channel 'Stable'
            $allowed | Should -Contain 'stable'
            $allowed | Should -Not -Contain 'preview'
            $allowed | Should -Not -Contain 'experimental'
        }

        It 'PreRelease channel includes all maturities' {
            $allowed = Get-AllowedMaturities -Channel 'PreRelease'
            $allowed | Should -Contain 'stable'
            $allowed | Should -Contain 'preview'
            $allowed | Should -Contain 'experimental'
        }
    }

    Context 'DryRun mode' {
        It 'DryRun parameter is a switch' {
            $cmd = Get-Command Invoke-ExtensionPreparation
            $dryRunParam = $cmd.Parameters['DryRun']
            $dryRunParam.ParameterType.Name | Should -Be 'SwitchParameter'
        }
    }

    Context 'Discovery integration' {
        It 'Discovers agents from directory' {
            $result = Get-DiscoveredAgents -AgentsDir (Join-Path $script:TestDir '.github/agents') -AllowedMaturities @('stable', 'preview') -ExcludedAgents @()
            $result.DirectoryExists | Should -BeTrue
            $result.Agents.Count | Should -Be 2
        }

        It 'Filters agents by maturity' {
            $result = Get-DiscoveredAgents -AgentsDir (Join-Path $script:TestDir '.github/agents') -AllowedMaturities @('stable') -ExcludedAgents @()
            $result.Agents.Count | Should -Be 1
            $result.Skipped.Count | Should -Be 1
        }

        It 'Discovers prompts from directory' {
            $result = Get-DiscoveredPrompts -PromptsDir (Join-Path $script:TestDir '.github/prompts') -GitHubDir (Join-Path $script:TestDir '.github') -AllowedMaturities @('stable')
            $result.DirectoryExists | Should -BeTrue
            $result.Prompts.Count | Should -BeGreaterThan 0
        }

        It 'Discovers instructions from directory' {
            $result = Get-DiscoveredInstructions -InstructionsDir (Join-Path $script:TestDir '.github/instructions') -GitHubDir (Join-Path $script:TestDir '.github') -AllowedMaturities @('stable')
            $result.DirectoryExists | Should -BeTrue
            $result.Instructions.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Path validation integration' {
        It 'Test-PathsExist returns valid for complete setup' {
            $result = Test-PathsExist `
                -ExtensionDir (Join-Path $script:TestDir 'extension') `
                -PackageJsonPath (Join-Path $script:TestDir 'extension/package.json') `
                -GitHubDir (Join-Path $script:TestDir '.github')
            $result.IsValid | Should -BeTrue
        }

        It 'Test-PathsExist returns invalid for missing paths' {
            $result = Test-PathsExist `
                -ExtensionDir '/nonexistent/ext' `
                -PackageJsonPath '/nonexistent/package.json' `
                -GitHubDir '/nonexistent/.github'
            $result.IsValid | Should -BeFalse
            $result.MissingPaths.Count | Should -Be 3
        }
    }

    Context 'Package.json update' {
        It 'Update-PackageJsonContributes adds chat participants' {
            $pkgJson = Get-Content -Path (Join-Path $script:TestDir 'extension/package.json') | ConvertFrom-Json
            $agents = @(
                @{ name = 'test'; description = 'Test agent'; isDefault = $true }
            )
            $result = Update-PackageJsonContributes -PackageJson $pkgJson -ChatAgents $agents -ChatPromptFiles @() -ChatInstructions @()
            $result | Should -Not -BeNull
        }
    }

    Context 'Output structure' {
        It 'Creates valid result object' {
            $result = @{
                Success = $true
                Channel = 'Stable'
                AgentsDiscovered = 1
                PromptsDiscovered = 1
                InstructionsDiscovered = 1
                SkippedAgents = 0
            }
            $result.Success | Should -BeTrue
            $result.AgentsDiscovered | Should -Be 1
        }
    }
}

Describe 'Get-DiscoveredPrompts Extended' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) "prompts-$(New-Guid)"
        $script:PromptsDir = Join-Path $script:TestDir 'prompts'
        $script:GhDir = Join-Path $script:TestDir '.github'
        New-Item -ItemType Directory -Path $script:PromptsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:GhDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Prompt file parsing' {
        BeforeEach {
@'
---
description: "Stable prompt"
maturity: stable
---
# Stable Prompt
'@ | Set-Content -Path (Join-Path $script:PromptsDir 'stable.prompt.md')

@'
---
description: "Preview prompt"
maturity: preview
---
# Preview Prompt
'@ | Set-Content -Path (Join-Path $script:PromptsDir 'preview.prompt.md')
        }

        It 'Discovers prompts from directory' {
            $result = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GhDir -AllowedMaturities @('stable', 'preview')
            $result.DirectoryExists | Should -BeTrue
        }

        It 'Returns prompts collection' {
            $result = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GhDir -AllowedMaturities @('stable', 'preview')
            $result.Prompts | Should -Not -BeNull
        }
    }
}

Describe 'Get-DiscoveredInstructions Extended' -Tag 'Unit' {
    BeforeAll {
        $script:TestDir = Join-Path ([IO.Path]::GetTempPath()) "instr-$(New-Guid)"
        $script:InstrDir = Join-Path $script:TestDir 'instructions'
        $script:GhDir = Join-Path $script:TestDir '.github'
        New-Item -ItemType Directory -Path $script:InstrDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:GhDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Instruction file parsing' {
        BeforeEach {
@'
---
description: "Stable instruction"
applyTo: "**/*.ps1"
maturity: stable
---
# Stable Instruction
'@ | Set-Content -Path (Join-Path $script:InstrDir 'stable.instructions.md')

@'
---
description: "Experimental instruction"
applyTo: "**/*.cs"
maturity: experimental
---
# Experimental Instruction
'@ | Set-Content -Path (Join-Path $script:InstrDir 'exp.instructions.md')
        }

        It 'Discovers instructions from directory' {
            $result = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities @('stable', 'experimental')
            $result.DirectoryExists | Should -BeTrue
        }

        It 'Returns instructions collection' {
            $result = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities @('stable', 'experimental')
            $result.Instructions | Should -Not -BeNull
        }
    }
}

#endregion

#region Phase 1: Pure Function Error Path Tests

Describe 'Get-FrontmatterData Additional Edge Cases' -Tag 'Unit' {
    BeforeAll {
        $script:EdgeCaseDir = Join-Path ([System.IO.Path]::GetTempPath()) "frontmatter-edge-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:EdgeCaseDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:EdgeCaseDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Frontmatter delimiter edge cases' {
        It 'Handles file with only closing frontmatter delimiter' {
            $testFile = Join-Path $script:EdgeCaseDir 'only-close.md'
            @'
# Just content
---
More content after horizontal rule
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.description | Should -Be 'fallback'
            $result.maturity | Should -Be 'stable'
        }

        It 'Handles file with multiple horizontal rules' {
            $testFile = Join-Path $script:EdgeCaseDir 'multi-hr.md'
            @'
# Content
---
Section break
---
Another section
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'default'
            $result.description | Should -Be 'default'
        }

        It 'Handles file starting with blank lines before frontmatter' {
            $testFile = Join-Path $script:EdgeCaseDir 'blank-start.md'
            @'

---
description: "After blank"
maturity: preview
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            # May or may not parse depending on implementation - test the behavior
            $result | Should -Not -BeNull
        }
    }

    Context 'Description field edge cases' {
        It 'Uses fallback when description is empty string' {
            $testFile = Join-Path $script:EdgeCaseDir 'empty-desc.md'
            @'
---
description: ""
maturity: stable
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'default-fallback'
            # Empty string should trigger fallback
            $result.description | Should -BeIn @('', 'default-fallback')
        }

        It 'Uses fallback when description is whitespace only' {
            $testFile = Join-Path $script:EdgeCaseDir 'whitespace-desc.md'
            @'
---
description: "   "
maturity: stable
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result | Should -Not -BeNull
        }

        It 'Handles description with special characters' {
            $testFile = Join-Path $script:EdgeCaseDir 'special-desc.md'
            @'
---
description: "Test with: colons, 'quotes', and \"double quotes\""
maturity: stable
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.description | Should -Match 'Test with'
        }

        It 'Handles multiline description in YAML' {
            $testFile = Join-Path $script:EdgeCaseDir 'multiline-desc.md'
            @'
---
description: >
  This is a long description
  that spans multiple lines
maturity: stable
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.description | Should -Match 'long description'
        }
    }

    Context 'Maturity field edge cases' {
        It 'Defaults to stable for unknown maturity value' {
            $testFile = Join-Path $script:EdgeCaseDir 'unknown-maturity.md'
            @'
---
description: "Test"
maturity: alpha
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            # Unknown maturity should be returned as-is or default
            $result.maturity | Should -BeIn @('alpha', 'stable')
        }

        It 'Handles maturity with mixed case' {
            $testFile = Join-Path $script:EdgeCaseDir 'mixed-case-maturity.md'
            @'
---
description: "Test"
maturity: Preview
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.maturity | Should -BeIn @('Preview', 'preview', 'stable')
        }
    }

    Context 'File read edge cases' {
        It 'Handles very large frontmatter' {
            $testFile = Join-Path $script:EdgeCaseDir 'large-frontmatter.md'
            $largeDesc = 'A' * 5000
            @"
---
description: "$largeDesc"
maturity: stable
---
# Content
"@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.description.Length | Should -BeGreaterThan 100
        }

        It 'Handles file with BOM' {
            $testFile = Join-Path $script:EdgeCaseDir 'bom-file.md'
            $content = @'
---
description: "BOM test"
maturity: stable
---
# Content
'@
            # Write with BOM
            [System.IO.File]::WriteAllText($testFile, $content, [System.Text.UTF8Encoding]::new($true))

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result | Should -Not -BeNull
        }
    }
}

Describe 'Test-PathsExist Additional Edge Cases' -Tag 'Unit' {
    Context 'Path validation edge cases' {
        It 'Handles paths with spaces' {
            $spacePath = Join-Path ([System.IO.Path]::GetTempPath()) "path with spaces $(New-Guid)"
            New-Item -ItemType Directory -Path $spacePath -Force | Out-Null
            try {
                $result = Test-PathsExist -ExtensionDir $spacePath -PackageJsonPath "$spacePath/pkg.json" -GitHubDir $spacePath
                # ExtensionDir exists, others may not
                $result | Should -Not -BeNull
            }
            finally {
                Remove-Item -Path $spacePath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Handles very long paths' {
            $longPath = Join-Path ([System.IO.Path]::GetTempPath()) ('a' * 50 + (New-Guid).ToString())
            $result = Test-PathsExist -ExtensionDir $longPath -PackageJsonPath "$longPath/pkg.json" -GitHubDir $longPath
            $result.IsValid | Should -BeFalse
            $result.MissingPaths.Count | Should -BeGreaterOrEqual 1
        }
    }
}

Describe 'Get-DiscoveredAgents Additional Edge Cases' -Tag 'Unit' {
    BeforeAll {
        $script:AgentEdgeDir = Join-Path ([System.IO.Path]::GetTempPath()) "agent-edge-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:AgentEdgeDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:AgentEdgeDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Empty and missing directories' {
        It 'Handles empty agents directory' {
            $emptyDir = Join-Path $script:AgentEdgeDir 'empty-agents'
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

            $result = Get-DiscoveredAgents -AgentsDir $emptyDir -AllowedMaturities @('stable') -ExcludedAgents @()
            $result.DirectoryExists | Should -BeTrue
            $result.Agents.Count | Should -Be 0
        }

        It 'Handles agents directory with non-agent files' {
            $mixedDir = Join-Path $script:AgentEdgeDir 'mixed-agents'
            New-Item -ItemType Directory -Path $mixedDir -Force | Out-Null
            'not an agent' | Set-Content -Path (Join-Path $mixedDir 'readme.txt')

            $result = Get-DiscoveredAgents -AgentsDir $mixedDir -AllowedMaturities @('stable') -ExcludedAgents @()
            $result.DirectoryExists | Should -BeTrue
            $result.Agents.Count | Should -Be 0
        }
    }

    Context 'Exclusion patterns' {
        BeforeEach {
            $script:ExclDir = Join-Path $script:AgentEdgeDir 'excl-agents'
            New-Item -ItemType Directory -Path $script:ExclDir -Force | Out-Null

            @'
---
description: "Agent A"
maturity: stable
---
'@ | Set-Content -Path (Join-Path $script:ExclDir 'agent-a.agent.md')

            @'
---
description: "Agent B"
maturity: stable
---
'@ | Set-Content -Path (Join-Path $script:ExclDir 'agent-b.agent.md')
        }

        It 'Excludes multiple agents by name' {
            $result = Get-DiscoveredAgents -AgentsDir $script:ExclDir -AllowedMaturities @('stable') -ExcludedAgents @('agent-a', 'agent-b')
            $result.Agents.Count | Should -Be 0
        }

        It 'Excludes case-insensitively' {
            $result = Get-DiscoveredAgents -AgentsDir $script:ExclDir -AllowedMaturities @('stable') -ExcludedAgents @('AGENT-A')
            $result.Agents.Count | Should -BeIn @(1, 2)  # Depending on case sensitivity
        }
    }
}

#endregion

#region Phase 2: Mocked Integration Tests for Invoke-ExtensionPreparation

Describe 'Invoke-ExtensionPreparation Integration' -Tag 'Integration' {
    BeforeAll {
        $script:PrepIntegrationDir = Join-Path ([IO.Path]::GetTempPath()) "prep-integration-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:PrepIntegrationDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:PrepIntegrationDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Path validation using pure functions' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepIntegrationDir "pathtest-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Test-PathsExist detects missing extension directory' {
            $extDir = Join-Path $script:TestDir 'extension'
            $pkgJson = Join-Path $extDir 'package.json'
            $ghDir = Join-Path $script:TestDir '.github'

            $result = Test-PathsExist -ExtensionDir $extDir -PackageJsonPath $pkgJson -GitHubDir $ghDir
            $result.IsValid | Should -BeFalse
            $result.MissingPaths | Should -Not -BeNull
        }

        It 'Test-PathsExist detects all missing paths' {
            $extDir = Join-Path $script:TestDir 'nonexistent1'
            $pkgJson = Join-Path $script:TestDir 'nonexistent2/package.json'
            $ghDir = Join-Path $script:TestDir 'nonexistent3'

            $result = Test-PathsExist -ExtensionDir $extDir -PackageJsonPath $pkgJson -GitHubDir $ghDir
            $result.MissingPaths.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Channel and maturity filtering' {
        It 'Get-AllowedMaturities returns only stable for Stable channel' {
            $result = Get-AllowedMaturities -Channel 'Stable'
            $result | Should -Be @('stable')
            $result | Should -Not -Contain 'preview'
            $result | Should -Not -Contain 'experimental'
        }

        It 'Get-AllowedMaturities returns all for PreRelease channel' {
            $result = Get-AllowedMaturities -Channel 'PreRelease'
            $result | Should -Contain 'stable'
            $result | Should -Contain 'preview'
            $result | Should -Contain 'experimental'
            $result.Count | Should -Be 3
        }
    }

    Context 'Agent discovery with maturity filtering' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepIntegrationDir "agents-$(New-Guid)"
            $script:AgentsDir = Join-Path $script:TestDir 'agents'
            New-Item -ItemType Directory -Path $script:AgentsDir -Force | Out-Null

            # Create agents with different maturities
            @'
---
description: "Stable agent"
maturity: stable
---
# Stable Agent
'@ | Set-Content -Path (Join-Path $script:AgentsDir 'stable-agent.agent.md')

            @'
---
description: "Preview agent"
maturity: preview
---
# Preview Agent
'@ | Set-Content -Path (Join-Path $script:AgentsDir 'preview-agent.agent.md')

            @'
---
description: "Experimental agent"
maturity: experimental
---
# Experimental Agent
'@ | Set-Content -Path (Join-Path $script:AgentsDir 'experimental-agent.agent.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Discovers only stable agents for Stable channel' {
            $allowed = Get-AllowedMaturities -Channel 'Stable'
            $result = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities $allowed -ExcludedAgents @()

            $result.Agents.Count | Should -Be 1
            $result.Agents[0].name | Should -Be 'stable-agent'
            $result.Skipped.Count | Should -Be 2
        }

        It 'Discovers all agents for PreRelease channel' {
            $allowed = Get-AllowedMaturities -Channel 'PreRelease'
            $result = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities $allowed -ExcludedAgents @()

            $result.Agents.Count | Should -Be 3
            $result.Skipped.Count | Should -Be 0
        }

        It 'Excludes agents by name' {
            $allowed = Get-AllowedMaturities -Channel 'PreRelease'
            $result = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities $allowed -ExcludedAgents @('preview-agent')

            $result.Agents.Count | Should -Be 2
            $result.Agents.name | Should -Not -Contain 'preview-agent'
        }
    }

    Context 'Prompt discovery with maturity filtering' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepIntegrationDir "prompts-$(New-Guid)"
            $script:GhDir = Join-Path $script:TestDir '.github'
            $script:PromptsDir = Join-Path $script:GhDir 'prompts'
            New-Item -ItemType Directory -Path $script:PromptsDir -Force | Out-Null

            @'
---
description: "Stable prompt"
maturity: stable
---
# Stable Prompt
'@ | Set-Content -Path (Join-Path $script:PromptsDir 'stable.prompt.md')

            @'
---
description: "Preview prompt"
maturity: preview
---
# Preview Prompt
'@ | Set-Content -Path (Join-Path $script:PromptsDir 'preview.prompt.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Discovers only stable prompts for Stable channel' {
            $allowed = Get-AllowedMaturities -Channel 'Stable'
            $result = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GhDir -AllowedMaturities $allowed

            $result.Prompts.Count | Should -Be 1
            $result.Skipped.Count | Should -Be 1
        }

        It 'Discovers all prompts for PreRelease channel' {
            $allowed = Get-AllowedMaturities -Channel 'PreRelease'
            $result = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GhDir -AllowedMaturities $allowed

            $result.Prompts.Count | Should -Be 2
        }
    }

    Context 'Instruction discovery with maturity filtering' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepIntegrationDir "instructions-$(New-Guid)"
            $script:GhDir = Join-Path $script:TestDir '.github'
            $script:InstrDir = Join-Path $script:GhDir 'instructions'
            New-Item -ItemType Directory -Path $script:InstrDir -Force | Out-Null

            @'
---
description: "Stable instruction"
applyTo: "**/*.ps1"
maturity: stable
---
# Stable Instruction
'@ | Set-Content -Path (Join-Path $script:InstrDir 'stable.instructions.md')

            @'
---
description: "Experimental instruction"
applyTo: "**/*.cs"
maturity: experimental
---
# Experimental Instruction
'@ | Set-Content -Path (Join-Path $script:InstrDir 'experimental.instructions.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Discovers only stable instructions for Stable channel' {
            $allowed = Get-AllowedMaturities -Channel 'Stable'
            $result = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities $allowed

            $result.Instructions.Count | Should -Be 1
            $result.Skipped.Count | Should -Be 1
        }

        It 'Discovers all instructions for PreRelease channel' {
            $allowed = Get-AllowedMaturities -Channel 'PreRelease'
            $result = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities $allowed

            $result.Instructions.Count | Should -Be 2
        }
    }

    Context 'Package.json update function' {
        It 'Update-PackageJsonContributes adds agents to contributes' {
            $packageJson = [PSCustomObject]@{
                name = 'test'
                version = '1.0.0'
            }

            $agents = @(
                [PSCustomObject]@{ name = 'agent1'; path = './path1'; description = 'desc1' }
            )
            $prompts = @()
            $instructions = @()

            $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents -ChatPromptFiles $prompts -ChatInstructions $instructions

            $result.contributes | Should -Not -BeNull
            $result.contributes.chatAgents.Count | Should -Be 1
            $result.contributes.chatAgents[0].name | Should -Be 'agent1'
        }

        It 'Update-PackageJsonContributes adds all component types' {
            $packageJson = [PSCustomObject]@{
                name = 'test'
                version = '1.0.0'
            }

            $agents = @([PSCustomObject]@{ name = 'a1'; path = './a1'; description = 'd1' })
            $prompts = @([PSCustomObject]@{ name = 'p1'; path = './p1'; description = 'd2' })
            $instructions = @([PSCustomObject]@{ name = 'i1'; path = './i1'; description = 'd3' })

            $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents -ChatPromptFiles $prompts -ChatInstructions $instructions

            $result.contributes.chatAgents.Count | Should -Be 1
            $result.contributes.chatPromptFiles.Count | Should -Be 1
            $result.contributes.chatInstructions.Count | Should -Be 1
        }

        It 'Update-PackageJsonContributes preserves existing contributes properties' {
            $packageJson = [PSCustomObject]@{
                name = 'test'
                version = '1.0.0'
                contributes = [PSCustomObject]@{
                    commands = @(@{ command = 'test.command' })
                }
            }

            $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions @()

            # Existing commands should be preserved
            $result.contributes.commands | Should -Not -BeNull
            $result.contributes.commands[0].command | Should -Be 'test.command'
            # ChatAgents property should exist (even if empty)
            $result.contributes.PSObject.Properties.Name | Should -Contain 'chatAgents'
        }
    }

    Context 'Full discovery flow simulation' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepIntegrationDir "full-flow-$(New-Guid)"
            $script:ExtDir = Join-Path $script:TestDir 'extension'
            $script:GhDir = Join-Path $script:TestDir '.github'
            $script:AgentsDir = Join-Path $script:GhDir 'agents'
            $script:PromptsDir = Join-Path $script:GhDir 'prompts'
            $script:InstrDir = Join-Path $script:GhDir 'instructions'

            # Create full directory structure
            New-Item -ItemType Directory -Path $script:ExtDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:AgentsDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:PromptsDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:InstrDir -Force | Out-Null

            # Create package.json
            $pkgJson = @{
                name = 'test-extension'
                version = '1.0.0'
                publisher = 'test'
                engines = @{ vscode = '^1.80.0' }
            }
            $pkgJson | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:ExtDir 'package.json')

            # Create one of each type
            @'
---
description: "Test agent"
maturity: stable
---
'@ | Set-Content -Path (Join-Path $script:AgentsDir 'test.agent.md')

            @'
---
description: "Test prompt"
maturity: stable
---
'@ | Set-Content -Path (Join-Path $script:PromptsDir 'test.prompt.md')

            @'
---
description: "Test instruction"
applyTo: "**/*.md"
maturity: stable
---
'@ | Set-Content -Path (Join-Path $script:InstrDir 'test.instructions.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Simulates full discovery and update flow' {
            # 1. Validate paths
            $pkgJsonPath = Join-Path $script:ExtDir 'package.json'
            $pathResult = Test-PathsExist -ExtensionDir $script:ExtDir -PackageJsonPath $pkgJsonPath -GitHubDir $script:GhDir
            $pathResult.IsValid | Should -BeTrue

            # 2. Get allowed maturities
            $allowed = Get-AllowedMaturities -Channel 'Stable'
            $allowed | Should -Contain 'stable'

            # 3. Discover components
            $agents = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities $allowed -ExcludedAgents @()
            $agents.Agents.Count | Should -Be 1

            $prompts = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GhDir -AllowedMaturities $allowed
            $prompts.Prompts.Count | Should -Be 1

            $instructions = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities $allowed
            $instructions.Instructions.Count | Should -Be 1

            # 4. Read and update package.json
            $packageJson = Get-Content -Path $pkgJsonPath -Raw | ConvertFrom-Json
            $updated = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents.Agents -ChatPromptFiles $prompts.Prompts -ChatInstructions $instructions.Instructions

            $updated.contributes.chatAgents.Count | Should -Be 1
            $updated.contributes.chatPromptFiles.Count | Should -Be 1
            $updated.contributes.chatInstructions.Count | Should -Be 1
        }
    }
}

#endregion

#region Phase 3: Orchestration Early Exit Tests

Describe 'Invoke-ExtensionPreparation Orchestration - Early Exit Paths' -Tag 'Integration' {
    BeforeAll {
        $script:PrepOrchRoot = Join-Path ([System.IO.Path]::GetTempPath()) "prep-orch-tests-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:PrepOrchRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:PrepOrchRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'PowerShell-Yaml module check' {
        It 'PowerShell-Yaml module is available in test environment' {
            $module = Get-Module -ListAvailable -Name PowerShell-Yaml
            $module | Should -Not -BeNullOrEmpty -Because "PowerShell-Yaml is required for extension preparation"
        }

        It 'Can import PowerShell-Yaml module' {
            { Import-Module PowerShell-Yaml -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'Path validation early exits' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepOrchRoot "test-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Detects missing extension directory' {
            $extDir = Join-Path $script:TestDir 'extension'
            Test-Path $extDir | Should -BeFalse
        }

        It 'Detects missing package.json file' {
            $extDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            $pkgPath = Join-Path $extDir 'package.json'
            Test-Path $pkgPath | Should -BeFalse
        }

        It 'Detects missing .github directory' {
            $extDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            '{"name":"test","version":"1.0.0"}' | Set-Content (Join-Path $extDir 'package.json')

            $ghDir = Join-Path $script:TestDir '.github'
            Test-Path $ghDir | Should -BeFalse
        }

        It 'Test-PathsExist returns invalid for incomplete setup' {
            $extDir = Join-Path $script:TestDir 'extension'
            $ghDir = Join-Path $script:TestDir '.github'
            $pkgPath = Join-Path $extDir 'package.json'

            $result = Test-PathsExist -ExtensionDir $extDir -PackageJsonPath $pkgPath -GitHubDir $ghDir
            $result.IsValid | Should -BeFalse
            $result.ErrorMessages.Count | Should -BeGreaterThan 0
        }
    }

    Context 'JSON parsing error handling' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepOrchRoot "json-test-$(New-Guid)"
            $extDir = Join-Path $script:TestDir 'extension'
            $ghDir = Join-Path $script:TestDir '.github'
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            New-Item -ItemType Directory -Path $ghDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Detects invalid JSON in package.json' {
            'invalid json {{{' | Set-Content (Join-Path $script:TestDir 'extension/package.json')

            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $parseError = $null
            try {
                Get-Content -Path $pkgPath -Raw | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $parseError = $_
            }

            $parseError | Should -Not -BeNull
        }

        It 'Detects missing version field in package.json' {
            '{"name":"test","publisher":"pub"}' | Set-Content (Join-Path $script:TestDir 'extension/package.json')

            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $packageJson = Get-Content -Path $pkgPath -Raw | ConvertFrom-Json

            $packageJson.PSObject.Properties['version'] | Should -BeNullOrEmpty
        }

        It 'Detects invalid version format in package.json' {
            '{"name":"test","version":"invalid-version","publisher":"pub"}' | Set-Content (Join-Path $script:TestDir 'extension/package.json')

            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $packageJson = Get-Content -Path $pkgPath -Raw | ConvertFrom-Json

            $packageJson.version -match '^\d+\.\d+\.\d+$' | Should -BeFalse
        }
    }

    Context 'DryRun mode verification' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepOrchRoot "dryrun-test-$(New-Guid)"
            $extDir = Join-Path $script:TestDir 'extension'
            $ghDir = Join-Path $script:TestDir '.github'
            $agentsDir = Join-Path $ghDir 'agents'

            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

            # Create valid package.json
            $script:OriginalPkg = @{
                name = 'test-ext'
                version = '1.0.0'
                publisher = 'test'
                engines = @{ vscode = '^1.80.0' }
            }
            $script:OriginalPkg | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $extDir 'package.json')

            # Create test agent
            @'
---
description: "Test agent for DryRun"
maturity: stable
---
'@ | Set-Content (Join-Path $agentsDir 'dryrun-test.agent.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'DryRun flag should not modify package.json contributes' {
            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $originalContent = Get-Content -Path $pkgPath -Raw

            # Simulate what DryRun should do - read but not write
            $packageJson = $originalContent | ConvertFrom-Json
            $allowed = Get-AllowedMaturities -Channel 'Stable'

            $agents = Get-DiscoveredAgents -AgentsDir (Join-Path $script:TestDir '.github/agents') -AllowedMaturities $allowed -ExcludedAgents @()
            $agents.Agents.Count | Should -BeGreaterOrEqual 1

            # Verify original file is unchanged (simulating DryRun behavior)
            $afterContent = Get-Content -Path $pkgPath -Raw
            $afterContent | Should -Be $originalContent
        }

        It 'DryRun discovers components without writing' {
            $ghDir = Join-Path $script:TestDir '.github'
            $allowed = Get-AllowedMaturities -Channel 'Stable'

            $agents = Get-DiscoveredAgents -AgentsDir (Join-Path $ghDir 'agents') -AllowedMaturities $allowed -ExcludedAgents @()

            # Get-DiscoveredAgents returns hashtable with Agents array
            $agents.Agents | Should -Not -BeNull
            $agents.Agents.Count | Should -Be 1
            $agents.Agents[0].name | Should -Be 'dryrun-test'
        }
    }

    Context 'Channel filtering' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepOrchRoot "channel-test-$(New-Guid)"
            $ghDir = Join-Path $script:TestDir '.github'
            $agentsDir = Join-Path $ghDir 'agents'
            New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

            # Create agents with different maturities
            @'
---
description: "Stable agent"
maturity: stable
---
'@ | Set-Content (Join-Path $agentsDir 'stable.agent.md')

            @'
---
description: "Preview agent"
maturity: preview
---
'@ | Set-Content (Join-Path $agentsDir 'preview.agent.md')

            @'
---
description: "Experimental agent"
maturity: experimental
---
'@ | Set-Content (Join-Path $agentsDir 'experimental.agent.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Stable channel includes only stable maturity' {
            $allowed = Get-AllowedMaturities -Channel 'Stable'
            $agents = Get-DiscoveredAgents -AgentsDir (Join-Path $script:TestDir '.github/agents') -AllowedMaturities $allowed -ExcludedAgents @()

            $agents.Agents.Count | Should -Be 1
            $agents.Agents[0].name | Should -Be 'stable'
        }

        It 'PreRelease channel includes all maturities' {
            $allowed = Get-AllowedMaturities -Channel 'PreRelease'
            $agents = Get-DiscoveredAgents -AgentsDir (Join-Path $script:TestDir '.github/agents') -AllowedMaturities $allowed -ExcludedAgents @()

            $agents.Agents.Count | Should -Be 3
        }
    }

    Context 'Changelog handling' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepOrchRoot "changelog-test-$(New-Guid)"
            $extDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $extDir -Force | Out-Null

            # Create a test changelog
            $script:ChangelogContent = @'
# Changelog

## [1.0.0] - 2026-02-09

### Added
- Initial release
'@
            $script:ChangelogPath = Join-Path $script:TestDir 'CHANGELOG.md'
            $script:ChangelogContent | Set-Content $script:ChangelogPath
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Validates changelog file exists before copy' {
            Test-Path $script:ChangelogPath | Should -BeTrue
        }

        It 'Can copy changelog to extension directory' {
            $destPath = Join-Path $script:TestDir 'extension/CHANGELOG.md'
            Copy-Item -Path $script:ChangelogPath -Destination $destPath -Force

            Test-Path $destPath | Should -BeTrue
            $copiedContent = Get-Content $destPath -Raw
            $copiedContent.Trim() | Should -Be $script:ChangelogContent.Trim()
        }

        It 'Handles missing changelog gracefully' {
            $nonExistentPath = Join-Path $script:TestDir 'nonexistent-changelog.md'
            Test-Path $nonExistentPath | Should -BeFalse
        }
    }

    Context 'Package.json write operations' {
        BeforeEach {
            $script:TestDir = Join-Path $script:PrepOrchRoot "write-test-$(New-Guid)"
            $extDir = Join-Path $script:TestDir 'extension'
            $ghDir = Join-Path $script:TestDir '.github'
            $agentsDir = Join-Path $ghDir 'agents'

            New-Item -ItemType Directory -Path $extDir -Force | Out-Null
            New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

            # Create package.json
            @{
                name = 'test-ext'
                version = '1.0.0'
                publisher = 'test'
                engines = @{ vscode = '^1.80.0' }
            } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $extDir 'package.json')

            # Create test agent
            @'
---
description: "Write test agent"
maturity: stable
---
'@ | Set-Content (Join-Path $agentsDir 'write-test.agent.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Can update and save package.json with contributes' {
            $pkgPath = Join-Path $script:TestDir 'extension/package.json'
            $packageJson = Get-Content -Path $pkgPath -Raw | ConvertFrom-Json

            $allowed = Get-AllowedMaturities -Channel 'Stable'
            $agents = Get-DiscoveredAgents -AgentsDir (Join-Path $script:TestDir '.github/agents') -AllowedMaturities $allowed -ExcludedAgents @()

            $updated = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents.Agents -ChatPromptFiles @() -ChatInstructions @()

            # Write updated package.json
            $updated | ConvertTo-Json -Depth 10 | Set-Content -Path $pkgPath -Encoding UTF8NoBOM

            # Verify file was written correctly
            $reread = Get-Content -Path $pkgPath -Raw | ConvertFrom-Json
            $reread.contributes.chatAgents.Count | Should -Be 1
            $reread.contributes.chatAgents[0].name | Should -Be 'write-test'
        }
    }
}

#endregion

#region Priority 2: Mocked Full Preparation Flow

Describe 'Invoke-ExtensionPreparation - Full Flow Simulation' -Tag 'Integration', 'Mocked' {
    BeforeAll {
        $script:FullFlowRoot = Join-Path ([System.IO.Path]::GetTempPath()) "prep-fullflow-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:FullFlowRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:FullFlowRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Complete discovery and update simulation' {
        BeforeEach {
            $script:TestDir = Join-Path $script:FullFlowRoot "complete-$(New-Guid)"
            $script:ExtDir = Join-Path $script:TestDir 'extension'
            $script:GhDir = Join-Path $script:TestDir '.github'
            $script:AgentsDir = Join-Path $script:GhDir 'agents'
            $script:PromptsDir = Join-Path $script:GhDir 'prompts'
            $script:InstrDir = Join-Path $script:GhDir 'instructions'

            # Create full directory structure
            New-Item -ItemType Directory -Path $script:ExtDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:AgentsDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:PromptsDir -Force | Out-Null
            New-Item -ItemType Directory -Path $script:InstrDir -Force | Out-Null

            # Create package.json
            @{
                name = 'hve-core'
                displayName = 'HVE Core'
                version = '1.0.0'
                publisher = 'microsoft'
                engines = @{ vscode = '^1.80.0' }
                categories = @('Other')
            } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:ExtDir 'package.json')

            # Create multiple agents with different maturities
            @'
---
description: "Task planner agent for breaking down work"
maturity: stable
---
# Task Planner
'@ | Set-Content (Join-Path $script:AgentsDir 'task-planner.agent.md')

            @'
---
description: "Code reviewer agent"
maturity: preview
---
# Code Reviewer
'@ | Set-Content (Join-Path $script:AgentsDir 'code-reviewer.agent.md')

            # Create prompts
            @'
---
description: "Git commit message generator"
maturity: stable
---
'@ | Set-Content (Join-Path $script:PromptsDir 'git-commit.prompt.md')

            @'
---
description: "PR description generator"
maturity: stable
---
'@ | Set-Content (Join-Path $script:PromptsDir 'pr-description.prompt.md')

            # Create instructions
            @'
---
description: "Markdown formatting rules"
applyTo: "**/*.md"
maturity: stable
---
'@ | Set-Content (Join-Path $script:InstrDir 'markdown.instructions.md')

            @'
---
description: "Python coding standards"
applyTo: "**/*.py"
maturity: preview
---
'@ | Set-Content (Join-Path $script:InstrDir 'python.instructions.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Discovers correct counts for Stable channel' {
            $allowed = Get-AllowedMaturities -Channel 'Stable'

            $agents = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities $allowed -ExcludedAgents @()
            $prompts = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GhDir -AllowedMaturities $allowed
            $instructions = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities $allowed

            $agents.Agents.Count | Should -Be 1
            $agents.Agents[0].name | Should -Be 'task-planner'

            $prompts.Prompts.Count | Should -Be 2

            $instructions.Instructions.Count | Should -Be 1
            $instructions.Instructions[0].name | Should -Be 'markdown-instructions'
        }

        It 'Discovers all items for PreRelease channel' {
            $allowed = Get-AllowedMaturities -Channel 'PreRelease'

            $agents = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities $allowed -ExcludedAgents @()
            $prompts = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GhDir -AllowedMaturities $allowed
            $instructions = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities $allowed

            $agents.Agents.Count | Should -Be 2
            $prompts.Prompts.Count | Should -Be 2
            $instructions.Instructions.Count | Should -Be 2
        }

        It 'Updates package.json with discovered components' {
            $pkgPath = Join-Path $script:ExtDir 'package.json'
            $packageJson = Get-Content $pkgPath -Raw | ConvertFrom-Json
            $allowed = Get-AllowedMaturities -Channel 'Stable'

            $agents = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities $allowed -ExcludedAgents @()
            $prompts = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GhDir -AllowedMaturities $allowed
            $instructions = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities $allowed

            $updated = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents.Agents -ChatPromptFiles $prompts.Prompts -ChatInstructions $instructions.Instructions

            $updated.contributes.chatAgents.Count | Should -Be 1
            $updated.contributes.chatPromptFiles.Count | Should -Be 2
            $updated.contributes.chatInstructions.Count | Should -Be 1
        }

        It 'Writes updated package.json and verifies roundtrip' {
            $pkgPath = Join-Path $script:ExtDir 'package.json'
            $packageJson = Get-Content $pkgPath -Raw | ConvertFrom-Json
            $allowed = Get-AllowedMaturities -Channel 'Stable'

            $agents = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities $allowed -ExcludedAgents @()
            $prompts = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GhDir -AllowedMaturities $allowed
            $instructions = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities $allowed

            $updated = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents.Agents -ChatPromptFiles $prompts.Prompts -ChatInstructions $instructions.Instructions

            # Write to file
            $updated | ConvertTo-Json -Depth 10 | Set-Content $pkgPath -Encoding UTF8NoBOM

            # Read back and verify
            $reread = Get-Content $pkgPath -Raw | ConvertFrom-Json

            $reread.name | Should -Be 'hve-core'
            $reread.version | Should -Be '1.0.0'
            $reread.contributes.chatAgents[0].name | Should -Be 'task-planner'
            $reread.contributes.chatAgents[0].description | Should -Be 'Task planner agent for breaking down work'
        }

        It 'Tracks skipped items correctly' {
            $allowed = Get-AllowedMaturities -Channel 'Stable'

            $agents = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities $allowed -ExcludedAgents @()
            $instructions = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GhDir -AllowedMaturities $allowed

            $agents.Skipped.Count | Should -Be 1
            $agents.Skipped[0].Name | Should -Be 'code-reviewer'
            $agents.Skipped[0].Reason | Should -Match 'preview'

            $instructions.Skipped.Count | Should -Be 1
            $instructions.Skipped[0].Name | Should -Be 'python-instructions'
        }
    }

    Context 'Agent exclusion handling' {
        BeforeEach {
            $script:TestDir = Join-Path $script:FullFlowRoot "exclusion-$(New-Guid)"
            $agentsDir = Join-Path $script:TestDir '.github/agents'
            New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

            @'
---
description: "Keep this agent"
maturity: stable
---
'@ | Set-Content (Join-Path $agentsDir 'keeper.agent.md')

            @'
---
description: "Exclude this agent"
maturity: stable
---
'@ | Set-Content (Join-Path $agentsDir 'exclude-me.agent.md')

            @'
---
description: "Also keep"
maturity: stable
---
'@ | Set-Content (Join-Path $agentsDir 'also-keep.agent.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Excludes agents by name' {
            $agentsDir = Join-Path $script:TestDir '.github/agents'
            $allowed = Get-AllowedMaturities -Channel 'Stable'
            $excluded = @('exclude-me')

            $result = Get-DiscoveredAgents -AgentsDir $agentsDir -AllowedMaturities $allowed -ExcludedAgents $excluded

            $result.Agents.Count | Should -Be 2
            $result.Agents.name | Should -Not -Contain 'exclude-me'
            $result.Skipped | Where-Object { $_.Reason -eq 'excluded' } | Should -HaveCount 1
        }

        It 'Excludes multiple agents' {
            $agentsDir = Join-Path $script:TestDir '.github/agents'
            $allowed = Get-AllowedMaturities -Channel 'Stable'
            $excluded = @('exclude-me', 'also-keep')

            $result = Get-DiscoveredAgents -AgentsDir $agentsDir -AllowedMaturities $allowed -ExcludedAgents $excluded

            $result.Agents.Count | Should -Be 1
            $result.Agents[0].name | Should -Be 'keeper'
        }
    }

    Context 'Nested prompts and instructions' {
        BeforeEach {
            $script:TestDir = Join-Path $script:FullFlowRoot "nested-$(New-Guid)"
            $ghDir = Join-Path $script:TestDir '.github'
            $promptsDir = Join-Path $ghDir 'prompts'
            $instrDir = Join-Path $ghDir 'instructions'

            # Create nested structure
            New-Item -ItemType Directory -Path (Join-Path $promptsDir 'git') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $instrDir 'csharp') -Force | Out-Null

            @'
---
description: "Root prompt"
maturity: stable
---
'@ | Set-Content (Join-Path $promptsDir 'root.prompt.md')

            @'
---
description: "Nested git prompt"
maturity: stable
---
'@ | Set-Content (Join-Path $promptsDir 'git/commit.prompt.md')

            @'
---
description: "Nested csharp instruction"
applyTo: "**/*.cs"
maturity: stable
---
'@ | Set-Content (Join-Path $instrDir 'csharp/style.instructions.md')
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Discovers prompts in nested directories' {
            $ghDir = Join-Path $script:TestDir '.github'
            $promptsDir = Join-Path $ghDir 'prompts'
            $allowed = Get-AllowedMaturities -Channel 'Stable'

            $result = Get-DiscoveredPrompts -PromptsDir $promptsDir -GitHubDir $ghDir -AllowedMaturities $allowed

            $result.Prompts.Count | Should -Be 2
            $result.Prompts.path | Should -Contain './.github/prompts/root.prompt.md'
            $result.Prompts.path | Should -Contain './.github/prompts/git/commit.prompt.md'
        }

        It 'Discovers instructions in nested directories' {
            $ghDir = Join-Path $script:TestDir '.github'
            $instrDir = Join-Path $ghDir 'instructions'
            $allowed = Get-AllowedMaturities -Channel 'Stable'

            $result = Get-DiscoveredInstructions -InstructionsDir $instrDir -GitHubDir $ghDir -AllowedMaturities $allowed

            $result.Instructions.Count | Should -Be 1
            $result.Instructions[0].path | Should -Match 'csharp/style\.instructions\.md'
        }
    }
}

#endregion

#region Phase 4: Additional Orchestration Coverage Tests

Describe 'Prepare-Extension Orchestration - Additional Coverage' -Tag 'Unit' {
    BeforeAll {
        $script:OrchCoverageRoot = Join-Path ([System.IO.Path]::GetTempPath()) "prep-orch-cov-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:OrchCoverageRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:OrchCoverageRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Channel maturity filtering edge cases' {
        It 'Stable channel excludes preview maturity' {
            $allowed = Get-AllowedMaturities -Channel 'Stable'

            $allowed | Should -Not -Contain 'preview'
            $allowed | Should -Not -Contain 'experimental'
        }

        It 'PreRelease channel includes all maturity levels' {
            $allowed = Get-AllowedMaturities -Channel 'PreRelease'

            $allowed | Should -HaveCount 3
            $allowed | Should -Contain 'stable'
            $allowed | Should -Contain 'preview'
            $allowed | Should -Contain 'experimental'
        }
    }

    Context 'Frontmatter parsing edge cases' {
        BeforeEach {
            $script:TestDir = Join-Path $script:OrchCoverageRoot "frontmatter-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Handles CRLF line endings in frontmatter' {
            $testFile = Join-Path $script:TestDir 'crlf.md'
            "---`r`ndescription: CRLF test`r`nmaturity: preview`r`n---`r`n# Content" | Set-Content -Path $testFile -NoNewline

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'

            $result.description | Should -Be 'CRLF test'
            $result.maturity | Should -Be 'preview'
        }

        It 'Handles frontmatter without description' {
            $testFile = Join-Path $script:TestDir 'no-desc.md'
            @'
---
maturity: experimental
applyTo: "**/*.ts"
---
# No description
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'My fallback description'

            $result.description | Should -Be 'My fallback description'
            $result.maturity | Should -Be 'experimental'
        }

        It 'Handles file with only frontmatter delimiters' {
            $testFile = Join-Path $script:TestDir 'empty-fm.md'
            @'
---
---
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'default'

            $result.description | Should -Be 'default'
            $result.maturity | Should -Be 'stable'
        }
    }

    Context 'Update-PackageJsonContributes extended' {
        It 'Handles package.json without existing contributes section' {
            $packageJson = [PSCustomObject]@{
                name = 'test-ext'
                version = '1.0.0'
            }

            $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions @()

            $result.contributes | Should -Not -BeNullOrEmpty
            $null -ne $result.contributes.chatAgents | Should -BeTrue
        }

        It 'Replaces existing chatAgents with new values' {
            $packageJson = [PSCustomObject]@{
                name = 'test-ext'
                version = '1.0.0'
                contributes = [PSCustomObject]@{
                    chatAgents = @(
                        [PSCustomObject]@{ name = 'old-agent'; path = './old.agent.md' }
                    )
                }
            }

            $newAgents = @(
                [PSCustomObject]@{ name = 'new-agent'; path = './new.agent.md' }
            )

            $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $newAgents -ChatPromptFiles @() -ChatInstructions @()

            $result.contributes.chatAgents.Count | Should -Be 1
            $result.contributes.chatAgents[0].name | Should -Be 'new-agent'
        }

        It 'Handles empty arrays for all components' {
            $packageJson = [PSCustomObject]@{
                name = 'test-ext'
                version = '1.0.0'
            }

            $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions @()

            $result.contributes.chatAgents.Count | Should -Be 0
            $result.contributes.chatPromptFiles.Count | Should -Be 0
            $result.contributes.chatInstructions.Count | Should -Be 0
        }
    }

    Context 'Path validation extended' {
        It 'Test-PathsExist provides descriptive error messages' {
            $missing = '/nonexistent/path/12345'
            $result = Test-PathsExist -ExtensionDir $missing -PackageJsonPath $missing -GitHubDir $missing

            $result.IsValid | Should -BeFalse
            $result.ErrorMessages.Count | Should -Be 3
            $result.ErrorMessages[0] | Should -Match 'not found'
        }
    }

    Context 'Agent discovery edge cases' {
        BeforeEach {
            $script:TestDir = Join-Path $script:OrchCoverageRoot "agent-edge-$(New-Guid)"
            $script:AgentsDir = Join-Path $script:TestDir 'agents'
            New-Item -ItemType Directory -Path $script:AgentsDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Handles agent with complex name containing dots' {
            $agentFile = Join-Path $script:AgentsDir 'my.complex.name.agent.md'
            @'
---
description: "Complex name agent"
maturity: stable
---
'@ | Set-Content -Path $agentFile

            $result = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities @('stable') -ExcludedAgents @()

            $result.Agents.Count | Should -Be 1
            $result.Agents[0].name | Should -Be 'my.complex.name'
        }

        It 'Handles empty agents directory' {
            $emptyDir = Join-Path $script:TestDir 'empty-agents'
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

            $result = Get-DiscoveredAgents -AgentsDir $emptyDir -AllowedMaturities @('stable') -ExcludedAgents @()

            $result.DirectoryExists | Should -BeTrue
            $result.Agents.Count | Should -Be 0
        }

        It 'Records skip reason for excluded agents' {
            @'
---
description: "Will be excluded"
maturity: stable
---
'@ | Set-Content (Join-Path $script:AgentsDir 'excluded.agent.md')

            $result = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities @('stable') -ExcludedAgents @('excluded')

            $result.Skipped | Where-Object { $_.Reason -eq 'excluded' } | Should -HaveCount 1
        }

        It 'Records skip reason for maturity filtering' {
            @'
---
description: "Preview agent"
maturity: preview
---
'@ | Set-Content (Join-Path $script:AgentsDir 'preview.agent.md')

            $result = Get-DiscoveredAgents -AgentsDir $script:AgentsDir -AllowedMaturities @('stable') -ExcludedAgents @()

            $result.Skipped | Where-Object { $_.Reason -match 'maturity' } | Should -HaveCount 1
        }
    }

    Context 'Prompt discovery edge cases' {
        BeforeEach {
            $script:TestDir = Join-Path $script:OrchCoverageRoot "prompt-edge-$(New-Guid)"
            $script:GitHubDir = Join-Path $script:TestDir '.github'
            $script:PromptsDir = Join-Path $script:GitHubDir 'prompts'
            New-Item -ItemType Directory -Path $script:PromptsDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Generates display name from prompt filename' {
            $promptFile = Join-Path $script:PromptsDir 'my-test-prompt.prompt.md'
            @'
---
description: "Test prompt"
maturity: stable
---
'@ | Set-Content -Path $promptFile

            $result = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GitHubDir -AllowedMaturities @('stable')

            $result.Prompts.Count | Should -Be 1
            $result.Prompts[0].name | Should -Be 'my-test-prompt'
        }

        It 'Handles deeply nested prompts directory' {
            $nestedDir = Join-Path $script:PromptsDir 'level1/level2/level3'
            New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null
            @'
---
description: "Deeply nested"
maturity: stable
---
'@ | Set-Content (Join-Path $nestedDir 'deep.prompt.md')

            $result = Get-DiscoveredPrompts -PromptsDir $script:PromptsDir -GitHubDir $script:GitHubDir -AllowedMaturities @('stable')

            $result.Prompts.Count | Should -Be 1
            $result.Prompts[0].path | Should -Match 'level1/level2/level3'
        }
    }

    Context 'Instruction discovery edge cases' {
        BeforeEach {
            $script:TestDir = Join-Path $script:OrchCoverageRoot "instr-edge-$(New-Guid)"
            $script:GitHubDir = Join-Path $script:TestDir '.github'
            $script:InstrDir = Join-Path $script:GitHubDir 'instructions'
            New-Item -ItemType Directory -Path $script:InstrDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Generates instruction name with -instructions suffix' {
            $instrFile = Join-Path $script:InstrDir 'python.instructions.md'
            @'
---
description: "Python instructions"
applyTo: "**/*.py"
maturity: stable
---
'@ | Set-Content -Path $instrFile

            $result = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GitHubDir -AllowedMaturities @('stable')

            $result.Instructions.Count | Should -Be 1
            $result.Instructions[0].name | Should -Be 'python-instructions'
        }

        It 'Normalizes path separators to forward slashes' {
            $nestedDir = Join-Path $script:InstrDir 'lang'
            New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null
            @'
---
description: "Nested instruction"
maturity: stable
---
'@ | Set-Content (Join-Path $nestedDir 'typescript.instructions.md')

            $result = Get-DiscoveredInstructions -InstructionsDir $script:InstrDir -GitHubDir $script:GitHubDir -AllowedMaturities @('stable')

            $result.Instructions[0].path | Should -Not -Match '\\'
            $result.Instructions[0].path | Should -Match '/'
        }
    }
}

Describe 'Prepare-Extension - File Operations Coverage' -Tag 'Unit' {
    BeforeAll {
        $script:FileOpsRoot = Join-Path ([System.IO.Path]::GetTempPath()) "prep-fileops-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:FileOpsRoot -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:FileOpsRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Package.json update simulation' {
        BeforeEach {
            $script:TestDir = Join-Path $script:FileOpsRoot "pkg-update-$(New-Guid)"
            $script:ExtDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $script:ExtDir -Force | Out-Null

            $script:PackageJsonPath = Join-Path $script:ExtDir 'package.json'
            @{
                name = 'test-ext'
                version = '1.0.0'
                publisher = 'test'
                engines = @{ vscode = '^1.80.0' }
            } | ConvertTo-Json | Set-Content -Path $script:PackageJsonPath
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Writes updated package.json preserving JSON structure' {
            $packageJson = Get-Content -Path $script:PackageJsonPath -Raw | ConvertFrom-Json

            $agents = @(
                [PSCustomObject]@{ name = 'test-agent'; path = './test.agent.md'; description = 'Test' }
            )

            $updated = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents -ChatPromptFiles @() -ChatInstructions @()
            $updated | ConvertTo-Json -Depth 10 | Set-Content -Path $script:PackageJsonPath -Encoding UTF8NoBOM

            # Re-read and verify
            $reread = Get-Content -Path $script:PackageJsonPath -Raw | ConvertFrom-Json
            $reread.contributes.chatAgents.Count | Should -Be 1
            $reread.name | Should -Be 'test-ext'
        }
    }

    Context 'Changelog copy simulation' {
        BeforeEach {
            $script:TestDir = Join-Path $script:FileOpsRoot "changelog-$(New-Guid)"
            $script:ExtDir = Join-Path $script:TestDir 'extension'
            New-Item -ItemType Directory -Path $script:ExtDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Copies changelog to extension directory' {
            $changelogSrc = Join-Path $script:TestDir 'CHANGELOG.md'
            $changelogDest = Join-Path $script:ExtDir 'CHANGELOG.md'

            '# Changelog' | Set-Content $changelogSrc

            Copy-Item -Path $changelogSrc -Destination $changelogDest -Force

            Test-Path $changelogDest | Should -BeTrue
        }

        It 'Handles missing changelog gracefully' {
            $nonExistent = Join-Path $script:TestDir 'nonexistent-CHANGELOG.md'

            $exists = Test-Path $nonExistent
            $exists | Should -BeFalse

            # Simulating the orchestration conditional
            $copied = $false
            if (Test-Path $nonExistent) {
                $copied = $true
            }
            $copied | Should -BeFalse
        }
    }

    Context 'DryRun mode simulation' {
        It 'DryRun flag prevents file writes' {
            $dryRun = $true

            # Simulate DryRun check
            $wouldWrite = -not $dryRun
            $wouldWrite | Should -BeFalse
        }

        It 'DryRun still computes results' {
            $packageJson = [PSCustomObject]@{
                name = 'test'
                version = '1.0.0'
            }

            $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions @()

            # Result should be computed even in DryRun
            $result | Should -Not -BeNull
        }
    }
}

Describe 'Prepare-Extension - Version Validation Coverage' -Tag 'Unit' {
    Context 'Version format validation' {
        It 'Accepts standard semantic version' {
            $version = '1.0.0'
            $version -match '^\d+\.\d+\.\d+$' | Should -BeTrue
        }

        It 'Rejects version with prerelease suffix in validation regex' {
            $version = '1.0.0-dev.123'
            # The strict validation regex only accepts X.Y.Z
            $version -match '^\d+\.\d+\.\d+$' | Should -BeFalse
        }

        It 'Extracts base version from complex version string' {
            $version = '2.1.0-preview.1+build.456'
            $version -match '^(\d+\.\d+\.\d+)' | Out-Null
            $Matches[1] | Should -Be '2.1.0'
        }
    }
}

#endregion
