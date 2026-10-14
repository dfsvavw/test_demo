# VS Code Portable fixed-directory updater (Windows PowerShell 5.1+)
# Edit ONLY this version before each upgrade.
$TargetVersion = '1.137.0'

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InstallDir = 'E:\VSCode'
$BackupDir = 'E:\VSCode_backup'
$SourceDir = "E:\tools\VSCode-win32-x64-$TargetVersion"
$CodeExe = Join-Path $InstallDir 'Code.exe'
$CodeCli = Join-Path $InstallDir 'bin\code.cmd'
$PortableData = Join-Path $InstallDir 'data'
$BackupData = Join-Path $BackupDir 'data'

function Assert-PathExists {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description not found: $Path"
    }
}

# Running in the VS Code integrated terminal is unsafe: closing Code
# would terminate the shell executing this script.
if ($env:TERM_PROGRAM -eq 'vscode') {
    throw 'Run this script in a SEPARATE PowerShell window, not the VS Code integrated terminal.'
}

Write-Host "Target version: $TargetVersion"
Write-Host "Source: $SourceDir"
Write-Host "Install: $InstallDir"
Write-Host ''

# Preflight: never overwrite an existing backup or Portable data.
Assert-PathExists $SourceDir 'Extracted version directory'
Assert-PathExists (Join-Path $SourceDir 'Code.exe') 'New Code.exe'
Assert-PathExists $InstallDir 'Existing VS Code directory'
Assert-PathExists (Join-Path $InstallDir 'Code.exe') 'Existing Code.exe'
Assert-PathExists $PortableData 'Current Portable data directory'
Assert-PathExists (Join-Path $PortableData 'user-data') 'Portable user-data'
Assert-PathExists (Join-Path $PortableData 'extensions') 'Portable extensions'

if (Test-Path -LiteralPath $BackupDir) {
    throw "Backup directory already exists: $BackupDir. Inspect it before retrying."
}
if (Test-Path -LiteralPath (Join-Path $SourceDir 'data')) {
    throw 'The new version already contains a data directory. Resolve this before upgrading.'
}
if ($SourceDir.TrimEnd('\') -eq $InstallDir.TrimEnd('\')) {
    throw 'Source and destination directories must differ.'
}

# Never silently discard unsaved editor work.
$runningCode = @(Get-Process -Name Code -ErrorAction SilentlyContinue)
if ($runningCode.Count -gt 0) {
    Write-Warning 'VS Code is running. Save all files before continuing.'
    $answer = Read-Host 'Type CLOSE to terminate all Code processes (anything else cancels)'
    if ($answer -cne 'CLOSE') { throw 'Cancelled; no files changed.' }
    $runningCode | Stop-Process -Force
    Start-Sleep -Seconds 2
}

if (@(Get-Process -Name Code -ErrorAction SilentlyContinue).Count -gt 0) {
    throw 'VS Code is still running; no files changed.'
}

$backupCreated = $false
try {
    # 1. Back up the complete old installation, including its data directory.
    Write-Host '[1/4] Backing up existing installation...'
    Rename-Item -LiteralPath $InstallDir -NewName (Split-Path $BackupDir -Leaf)
    $backupCreated = $true

    # 2. Copy new program into the permanent path.
    Write-Host '[2/4] Copying new version...'
    Copy-Item -LiteralPath $SourceDir -Destination $InstallDir -Recurse
    Assert-PathExists $CodeExe 'Copied Code.exe'
    Assert-PathExists $CodeCli 'Copied code.cmd'

    # 3. Restore Portable settings/extensions; avoid resetting the profile.
    Write-Host '[3/4] Restoring Portable data...'
    Move-Item -LiteralPath $BackupData -Destination $PortableData
    Assert-PathExists (Join-Path $PortableData 'user-data') 'Restored user-data'
    Assert-PathExists (Join-Path $PortableData 'extensions') 'Restored extensions'

    # 4. Validate the new CLI and extension discovery.
    Write-Host '[4/4] Verifying the new version and extensions...'
    $versionOutput = @(& $CodeCli --version)
    if ($LASTEXITCODE -ne 0 -or $versionOutput.Count -eq 0) {
        throw 'VS Code version command failed.'
    }
    $actualVersion = [string]$versionOutput[0]
    if ($actualVersion.Trim() -ne $TargetVersion) {
        throw "Version mismatch: expected $TargetVersion, actual $actualVersion"
    }

    $installedExtensions = @(& $CodeCli --list-extensions)
    if ($LASTEXITCODE -ne 0) {
        throw 'Extension list command failed.'
    }
    $extensionFolders = @(Get-ChildItem -LiteralPath (Join-Path $PortableData 'extensions') -Directory)
    if ($extensionFolders.Count -gt 0 -and $installedExtensions.Count -eq 0) {
        throw 'Portable extensions exist on disk but VS Code did not detect any.'
    }
}
catch {
    $failureMessage = $_.Exception.Message
    Write-Warning "Upgrade error: $failureMessage"
    if ($backupCreated) {
        Write-Warning 'Attempting to restore the previous version...'
        try {
            if ((Test-Path -LiteralPath $PortableData) -and
                -not (Test-Path -LiteralPath $BackupData)) {
                Move-Item -LiteralPath $PortableData -Destination $BackupData
            }
            if (Test-Path -LiteralPath $BackupData) {
                if (Test-Path -LiteralPath $InstallDir) {
                    Remove-Item -LiteralPath $InstallDir -Recurse -Force
                }
                Rename-Item -LiteralPath $BackupDir -NewName (Split-Path $InstallDir -Leaf)
                Write-Warning 'Previous installation restored.'
            }
            else {
                Write-Warning 'Automatic rollback is unsafe: Portable data not found in backup. Inspect both directories manually.'
            }
        }
        catch {
            Write-Warning "Rollback could not complete: $($_.Exception.Message)"
            Write-Warning "Do not delete $BackupDir or $InstallDir."
        }
    }
    throw "Upgrade failed: $failureMessage"
}

Write-Host ''
Write-Host "CLI verification passed: $actualVersion"
Write-Host "Extensions listed: $($installedExtensions.Count)"
Write-Host "CLI path: $CodeCli"
Write-Host "Portable data: $PortableData"
Write-Host ''

try {
    Start-Process -FilePath $CodeExe
    Write-Host 'VS Code has been launched for GUI verification.'
}
catch {
    Write-Warning "Could not launch VS Code automatically: $($_.Exception.Message)"
    Write-Warning "Launch $CodeExe manually."
}

Write-Host 'Verify user settings, extensions, and OpenAI/Codex in the GUI.'
Write-Host "The old installation is still available at: $BackupDir"
Write-Host ''
$cleanupAnswer = Read-Host 'ONLY after GUI verification, type CLEAN to remove backup and extracted source (anything else keeps them)'
if ($cleanupAnswer -ceq 'CLEAN') {
    Remove-Item -LiteralPath $BackupDir -Recurse -Force
    Remove-Item -LiteralPath $SourceDir -Recurse -Force
    Write-Host 'Upgrade complete; backup and extracted source removed.'
}
else {
    Write-Host "Upgrade complete; backup kept at: $BackupDir"
    Write-Host "Extracted source kept at: $SourceDir"
}
