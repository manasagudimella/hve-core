#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for Invoke-PSScriptAnalyzer.ps1 script
.DESCRIPTION
    Tests for PSScriptAnalyzer wrapper script:
    - Parameter validation
    - Module availability checks
    - ChangedFilesOnly filtering
    - GitHub Actions integration
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Invoke-PSScriptAnalyzer.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1'

    # Import LintingHelpers for mocking
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module LintingHelpers -Force -ErrorAction SilentlyContinue
}

#region Parameter Validation Tests

Describe 'Invoke-PSScriptAnalyzer Parameter Validation' -Tag 'Unit' {
    Context 'ChangedFilesOnly parameter' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-ChangedFilesFromGit { @('script.ps1') }
            Mock Get-FilesRecursive { @() }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Accepts ChangedFilesOnly switch' {
            { & $script:ScriptPath -ChangedFilesOnly } | Should -Not -Throw
        }

        It 'Accepts BaseBranch with ChangedFilesOnly' {
            { & $script:ScriptPath -ChangedFilesOnly -BaseBranch 'develop' } | Should -Not -Throw
        }
    }

    Context 'ConfigPath parameter' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-FilesRecursive { @() }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Uses default config path when not specified' {
            # Script defaults to scripts/linting/PSScriptAnalyzer.psd1
            { & $script:ScriptPath } | Should -Not -Throw
        }

        It 'Accepts custom config path' {
            $configPath = Join-Path $PSScriptRoot '../../linting/PSScriptAnalyzer.psd1'
            { & $script:ScriptPath -ConfigPath $configPath } | Should -Not -Throw
        }
    }

    Context 'OutputPath parameter' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-FilesRecursive { @() }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Accepts custom output path' {
            $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) 'test-output.json'
            { & $script:ScriptPath -OutputPath $outputPath } | Should -Not -Throw
        }
    }
}

#endregion

#region Module Availability Tests

Describe 'PSScriptAnalyzer Module Availability' -Tag 'Unit' {
    Context 'Module not installed' {
        BeforeEach {
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Install-Module {} -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Import-Module { throw 'Module not found' } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Write-Error {}
        }

        It 'Reports error when module unavailable' {
            { & $script:ScriptPath } | Should -Throw
        }
    }

    Context 'Module installed' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-FilesRecursive { @() }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Proceeds when module available' {
            { & $script:ScriptPath } | Should -Not -Throw
        }
    }
}

#endregion

#region File Discovery Tests

Describe 'File Discovery' -Tag 'Unit' {
    Context 'All files mode' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Uses Get-FilesRecursive for all files' {
            Mock Get-FilesRecursive {
                return @('script1.ps1', 'script2.ps1')
            }

            & $script:ScriptPath
            Should -Invoke Get-FilesRecursive -Times 1
        }
    }

    Context 'Changed files only mode' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Get-FilesRecursive { @() }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Uses Get-ChangedFilesFromGit when ChangedFilesOnly specified' {
            Mock Get-ChangedFilesFromGit {
                return @('changed.ps1')
            }

            & $script:ScriptPath -ChangedFilesOnly
            Should -Invoke Get-ChangedFilesFromGit -Times 1
        }

        It 'Passes BaseBranch to Get-ChangedFilesFromGit' {
            Mock Get-ChangedFilesFromGit {
                return @('changed.ps1')
            }

            & $script:ScriptPath -ChangedFilesOnly -BaseBranch 'develop'
            Should -Invoke Get-ChangedFilesFromGit -Times 1 -ParameterFilter {
                $BaseBranch -eq 'develop'
            }
        }
    }
}

#endregion

#region GitHub Actions Integration Tests

Describe 'GitHub Actions Integration' -Tag 'Unit' {
    Context 'Write-GitHubAnnotation calls' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Get-FilesRecursive { @('test.ps1') }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Calls Write-GitHubAnnotation for each issue' {
            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        ScriptPath  = 'test.ps1'
                        Line        = 10
                        Column      = 5
                        RuleName    = 'PSAvoidUsingInvokeExpression'
                        Severity    = 'Warning'
                        Message     = 'Avoid using Invoke-Expression'
                    }
                )
            }

            & $script:ScriptPath
            Should -Invoke Write-GitHubAnnotation -Times 1
        }

        It 'Sets GitHub output for file count' {
            Mock Invoke-ScriptAnalyzer { @() }

            & $script:ScriptPath
            Should -Invoke Set-GitHubOutput -Times 1 -ParameterFilter {
                $Name -eq 'count'
            }
        }
    }
}

#endregion

#region Output Tests

Describe 'Output Generation' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'JSON output file' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Get-FilesRecursive { @('test.ps1') }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}

            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        ScriptPath  = 'test.ps1'
                        Line        = 10
                        Column      = 5
                        RuleName    = 'TestRule'
                        Severity    = 'Warning'
                        Message     = 'Test message'
                    }
                )
            }

            $script:OutputFile = Join-Path $script:TempDir 'output.json'
        }

        It 'Creates JSON output file' {
            & $script:ScriptPath -OutputPath $script:OutputFile
            Test-Path $script:OutputFile | Should -BeTrue
        }

        It 'Output file contains valid JSON' {
            & $script:ScriptPath -OutputPath $script:OutputFile
            { Get-Content $script:OutputFile | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}

#endregion

#region Exit Code Tests

Describe 'Exit Code Handling' -Tag 'Unit' {
    Context 'No issues found' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Get-FilesRecursive { @() }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
            Mock Invoke-ScriptAnalyzer { @() }
        }

        It 'Returns success when no issues' {
            { & $script:ScriptPath } | Should -Not -Throw
        }
    }

    Context 'Issues found' {
        BeforeEach {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
            Mock Get-FilesRecursive { @('test.ps1') }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}

            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        ScriptPath = 'test.ps1'
                        Severity   = 'Error'
                        RuleName   = 'TestRule'
                        Message    = 'Error found'
                        Line       = 1
                        Column     = 1
                    }
                )
            }
        }

        It 'Script completes with issues in output' {
            { & $script:ScriptPath } | Should -Not -Throw
        }
    }
}

#endregion

#region Invoke-PSScriptAnalysis Function Tests

Describe 'Invoke-PSScriptAnalysis Function' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        $script:logsDir = Join-Path $script:TempDir 'logs'
        New-Item -ItemType Directory -Path $script:logsDir -Force | Out-Null

        # Dot-source the script to load the function
        . $script:ScriptPath
    }

    AfterAll {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Return value for success' {
        BeforeEach {
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Returns 0 when no issues found' {
            $testFile = Join-Path $script:TempDir 'clean.ps1'
            'Write-Host "test"' | Set-Content $testFile
            $outPath = Join-Path $script:logsDir 'results.json'
            $configPath = Join-Path $PSScriptRoot '../../linting/PSScriptAnalyzer.psd1'

            $result = Invoke-PSScriptAnalysis -FilesToAnalyze @($testFile) -ConfigPath $configPath -OutputPath $outPath
            $result | Should -Be 0
        }
    }

    Context 'Return value for errors' {
        BeforeEach {
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Returns 1 when errors found' {
            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{
                        ScriptPath = 'test.ps1'
                        Severity   = 'Error'
                        RuleName   = 'PSAvoidUsingInvokeExpression'
                        Message    = 'Error message'
                        Line       = 1
                        Column     = 1
                    }
                )
            }

            $testFile = Join-Path $script:TempDir 'errors.ps1'
            'Invoke-Expression "bad"' | Set-Content $testFile
            $outPath = Join-Path $script:logsDir 'error-results.json'
            $configPath = Join-Path $PSScriptRoot '../../linting/PSScriptAnalyzer.psd1'

            $result = Invoke-PSScriptAnalysis -FilesToAnalyze @($testFile) -ConfigPath $configPath -OutputPath $outPath
            $result | Should -Be 1
        }
    }

    Context 'Summary generation' {
        BeforeEach {
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Counts warnings correctly' {
            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{ Severity = 'Warning'; RuleName = 'Rule1'; Message = 'Warn1'; Line = 1; Column = 1 },
                    [PSCustomObject]@{ Severity = 'Warning'; RuleName = 'Rule2'; Message = 'Warn2'; Line = 2; Column = 1 }
                )
            }

            $testFile = Join-Path $script:TempDir 'warnings.ps1'
            'Write-Host "test"' | Set-Content $testFile
            $outPath = Join-Path $script:logsDir 'warn-results.json'
            $configPath = Join-Path $PSScriptRoot '../../linting/PSScriptAnalyzer.psd1'

            Invoke-PSScriptAnalysis -FilesToAnalyze @($testFile) -ConfigPath $configPath -OutputPath $outPath
            Should -Invoke Set-GitHubOutput -ParameterFilter { $Name -eq 'warnings' -and $Value -eq 2 }
        }

        It 'Creates summary file' {
            Mock Invoke-ScriptAnalyzer { @() }

            $testFile = Join-Path $script:TempDir 'summary.ps1'
            'Write-Host "test"' | Set-Content $testFile
            $outPath = Join-Path $script:logsDir 'summary-results.json'
            $configPath = Join-Path $PSScriptRoot '../../linting/PSScriptAnalyzer.psd1'

            Invoke-PSScriptAnalysis -FilesToAnalyze @($testFile) -ConfigPath $configPath -OutputPath $outPath
            Test-Path 'logs/psscriptanalyzer-summary.json' | Should -BeTrue
        }
    }

    Context 'Environment variable setting' {
        BeforeEach {
            Mock Set-GitHubOutput {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Sets PSSCRIPTANALYZER_FAILED when errors found' {
            Mock Set-GitHubEnv {}
            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{ Severity = 'Error'; RuleName = 'Rule1'; Message = 'Error'; Line = 1; Column = 1 }
                )
            }

            $testFile = Join-Path $script:TempDir 'env-test.ps1'
            'Write-Host "test"' | Set-Content $testFile
            $outPath = Join-Path $script:logsDir 'env-results.json'
            $configPath = Join-Path $PSScriptRoot '../../linting/PSScriptAnalyzer.psd1'

            Invoke-PSScriptAnalysis -FilesToAnalyze @($testFile) -ConfigPath $configPath -OutputPath $outPath
            Should -Invoke Set-GitHubEnv -ParameterFilter { $Name -eq 'PSSCRIPTANALYZER_FAILED' -and $Value -eq 'true' }
        }
    }

    Context 'FileInfo handling' {
        BeforeEach {
            Mock Invoke-ScriptAnalyzer { @() }
            Mock Set-GitHubOutput {}
            Mock Set-GitHubEnv {}
            Mock Write-GitHubStepSummary {}
            Mock Write-GitHubAnnotation {}
        }

        It 'Handles FileInfo objects in FilesToAnalyze' {
            $testFile = Join-Path $script:TempDir 'fileinfo.ps1'
            'Write-Host "test"' | Set-Content $testFile
            $fileInfo = Get-Item $testFile
            $outPath = Join-Path $script:logsDir 'fileinfo-results.json'
            $configPath = Join-Path $PSScriptRoot '../../linting/PSScriptAnalyzer.psd1'

            { Invoke-PSScriptAnalysis -FilesToAnalyze @($fileInfo) -ConfigPath $configPath -OutputPath $outPath } | Should -Not -Throw
        }
    }
}

#endregion

