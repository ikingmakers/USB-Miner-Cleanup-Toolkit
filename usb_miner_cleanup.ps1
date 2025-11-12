# usb_miner_cleanup.ps1
# Запускать из-под администратора. Лог: usb_miner_cleanup.log в каталоге скрипта.

$logPath = Join-Path $PSScriptRoot "usb_miner_cleanup.log"

function Get-System32Path {
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        return Join-Path $env:windir "Sysnative"
    }
    return Join-Path $env:windir "System32"
}

function Clear-ItemAttributes {
    param([string]$TargetPath)
    try {
        $item = Get-Item -LiteralPath $TargetPath -Force -ErrorAction Stop
        $items = @($item)
        if ($item.PSIsContainer) {
            $items += Get-ChildItem -LiteralPath $TargetPath -Force -Recurse -ErrorAction Stop
        }
        foreach ($entry in $items) {
            if ($entry.Attributes -band ([IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System)) {
                $entry.Attributes = [IO.FileAttributes]::Normal
            }
        }
        Write-Log "Attributes reset to Normal (recursive): $TargetPath"
    } catch {
        Write-Log "Failed to reset attributes on ${TargetPath}: $($_.Exception.Message)"
    }
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp`t$Message" | Out-File -FilePath $logPath -Encoding UTF8 -Append
}

function Select-UsbDrive {
    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.Name -ne 'C:\' }

    if (-not $drives) {
        Write-Host "No available drives (other than C:) were detected." -ForegroundColor Yellow
        Write-Log "USB drive cleanup cancelled: no drives detected."
        return $null
    }

    Write-Host "Available drives:" -ForegroundColor Cyan
    foreach ($drive in $drives) {
        $label = if ($drive.VolumeLabel) { $drive.VolumeLabel } else { "NoLabel" }
        Write-Host "  $($drive.Name.TrimEnd('\'))  Type: $($drive.DriveType)  Label: $label  Free: $([Math]::Round($drive.AvailableFreeSpace/1GB,2)) GB"
    }

    while ($true) {
        $selection = Read-Host "Enter drive letter (e.g. E) or Q to cancel"
        if (-not $selection) { continue }
        if ($selection -match '^[Qq]$') {
            Write-Log "USB drive cleanup cancelled by user."
            return $null
        }

        $letter = $selection.Trim().TrimEnd(':').ToUpperInvariant()
        if ($letter.Length -ne 1) {
            Write-Host "Please enter a single drive letter." -ForegroundColor Yellow
            continue
        }

        $match = $drives | Where-Object { $_.Name.StartsWith("$letter`:\") }
        if ($match) {
            return $match
        }

        Write-Host "Drive ${letter}: not found in list. Try again." -ForegroundColor Yellow
    }
}

function Clear-UsbDrive {
    Write-Log "=== USB drive cleanup started ==="
    $drive = Select-UsbDrive
    if (-not $drive) {
        Write-Host "USB drive cleanup cancelled."
        return
    }

    $driveRoot = $drive.Name
    Write-Log "Selected drive: $driveRoot (Type: $($drive.DriveType); Label: $($drive.VolumeLabel))"

    $removedItems = @()
    $failedItems = @()
    $missingItems = @()
    $removedShortcuts = @()
    $failedShortcuts = @()

    try {
        $attribArgs = @("/c", "attrib", "-h", "-r", "-s", "/s", "/d", "${driveRoot}*.*")
        $attribResult = & cmd.exe $attribArgs 2>&1
        if ($attribResult) {
            foreach ($line in $attribResult) {
                Write-Log "attrib: $line"
            }
        } else {
            Write-Log "attrib command executed without output."
        }
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Attribute reset command failed: $errorMessage"
        Write-Host "Attribute reset command failed: $errorMessage" -ForegroundColor Red
        $failedItems += "attrib reset ($errorMessage)"
    }

    $sysvolumePath = Join-Path -Path $driveRoot -ChildPath "sysvolume"
    if (Test-Path -LiteralPath $sysvolumePath) {
        try {
            Clear-ItemAttributes -TargetPath $sysvolumePath
            Remove-Item -LiteralPath $sysvolumePath -Recurse -Force -ErrorAction Stop
            Write-Log "Removed folder: $sysvolumePath"
            $removedItems += $sysvolumePath
        } catch {
            $errorMessage = $_.Exception.Message
            Write-Log "Error removing folder ${sysvolumePath}: $errorMessage"
            Write-Host "Error removing folder ${sysvolumePath}: $errorMessage" -ForegroundColor Red
            $failedItems += "$sysvolumePath ($errorMessage)"
        }
    } else {
        Write-Log "Folder not found (skipped): $sysvolumePath"
        $missingItems += $sysvolumePath
    }

    try {
        $shortcuts = Get-ChildItem -Path $driveRoot -Filter '*.lnk' -Force -Recurse -ErrorAction Stop
        if ($shortcuts) {
            foreach ($shortcut in $shortcuts) {
                try {
                    Clear-ItemAttributes -TargetPath $shortcut.FullName
                    Remove-Item -LiteralPath $shortcut.FullName -Force -ErrorAction Stop
                    Write-Log "Removed shortcut: $($shortcut.FullName)"
                    $removedShortcuts += $shortcut.FullName
                } catch {
                    $errorMessage = $_.Exception.Message
                    Write-Log "Error removing shortcut $($shortcut.FullName): $errorMessage"
                    Write-Host "Error removing shortcut $($shortcut.FullName): $errorMessage" -ForegroundColor Red
                    $failedShortcuts += "$($shortcut.FullName) ($errorMessage)"
                }
            }
        } else {
            Write-Log "No shortcut files found on $driveRoot."
        }
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Failed to enumerate shortcuts on ${driveRoot}: $errorMessage"
        Write-Host "Failed to enumerate shortcuts: $errorMessage" -ForegroundColor Red
        $failedShortcuts += "Shortcut scan failed ($errorMessage)"
    }

    if ($removedItems.Count -gt 0) {
        Write-Host "`nRemoved items:" -ForegroundColor Green
        $removedItems | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    }
    if ($missingItems.Count -gt 0) {
        Write-Host "`nNot found (already missing):" -ForegroundColor Yellow
        $missingItems | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }
    if ($failedItems.Count -gt 0) {
        Write-Host "`nFailed to remove:" -ForegroundColor Red
        $failedItems | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
    if ($removedShortcuts.Count -gt 0) {
        Write-Host "`nRemoved shortcuts:" -ForegroundColor Green
        $removedShortcuts | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    }
    if ($failedShortcuts.Count -gt 0) {
        Write-Host "`nFailed to remove shortcuts:" -ForegroundColor Red
        $failedShortcuts | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }

    Write-Log "=== USB drive cleanup completed ==="
    Write-Host "`nUSB drive cleanup completed for $driveRoot. Log file: $logPath"
}

function Remove-MalwareRegistry {
    Write-Log "=== Registry and scheduled task cleanup started ==="
    $serviceRoot = "HKLM:\SYSTEM\CurrentControlSet\Services"

    try {
        $targets = Get-ChildItem -Path $serviceRoot -ErrorAction Stop |
            Where-Object { $_.PSChildName -match '^[Uu]\d{6}$' }

        if ($targets) {
            foreach ($item in $targets) {
                try {
                    Remove-Item -Path $item.PSPath -Recurse -Force -ErrorAction Stop
                    Write-Log "Removed service registry key: $($item.PSChildName)"
                } catch {
                    Write-Log "Error removing service key $($item.PSChildName): $($_.Exception.Message)"
                }
            }
        } else {
            Write-Log "No matching service keys found."
        }
    } catch {
        Write-Log "Failed to enumerate Services branch: $($_.Exception.Message)"
    }

    try {
        Get-ScheduledTask -TaskName 'svctrl64' -ErrorAction Stop | Out-Null
        Unregister-ScheduledTask -TaskName 'svctrl64' -Confirm:$false -ErrorAction Stop
        Write-Log "Removed scheduled task: svctrl64"
    } catch {
        Write-Log "Scheduled task svctrl64 not removed (possibly missing): $($_.Exception.Message)"
    }

    Write-Log "=== Cleanup complete. System reboot initiated. ==="
    Write-Host "Action completed. The computer will reboot in 5 seconds..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}

function Remove-MalwareFiles {
    Write-Log "=== File cleanup in System32 started ==="
    $system32 = [string](Get-System32Path)
    Write-Log "Resolved System32 path: $system32"

    $removedItems = @()
    $failedItems = @()
    $missingItems = @()

    try {
        $proc = Get-Process -Name 'svctrl64' -ErrorAction SilentlyContinue
        if ($proc) {
            $proc | Stop-Process -Force -ErrorAction Stop
            Write-Log "Stopped running process: svctrl64.exe"
        } else {
            Write-Log "Process svctrl64.exe not running."
        }
    } catch {
        Write-Log "Failed to stop svctrl64.exe: $($_.Exception.Message)"
    }

    $paths = @(
        (Join-Path -Path $system32 -ChildPath "svctrl64.exe")
        (Join-Path -Path $system32 -ChildPath "wsvcz")
    )

    foreach ($path in $paths) {
        if (Test-Path -Path $path) {
            try {
                Clear-ItemAttributes -TargetPath $path
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-Log "Removed item: $path"
                $removedItems += $path
            } catch {
                $errorMessage = $_.Exception.Message
                Write-Log "Error removing ${path}: $errorMessage"
                Write-Host "Error removing ${path}: $errorMessage" -ForegroundColor Red
                $failedItems += "$path ($errorMessage)"
            }
        } else {
            Write-Log "Item not found (skipped): $path"
            $missingItems += $path
        }
    }

    try {
        $dlls = Get-ChildItem -Path $system32 -Filter 'U*.dll' -File -ErrorAction Stop |
            Where-Object { $_.BaseName -match '^[Uu]\d{6}$' }

        if ($dlls) {
            foreach ($dll in $dlls) {
                try {
                    Clear-ItemAttributes -TargetPath $dll.FullName
                    Remove-Item -Path $dll.FullName -Force -ErrorAction Stop
                    Write-Log "Removed DLL file: $($dll.FullName)"
                    $removedItems += $dll.FullName
                } catch {
                    $errorMessage = $_.Exception.Message
                    Write-Log "Error removing DLL $($dll.FullName): $errorMessage"
                    Write-Host "Error removing DLL $($dll.FullName): $errorMessage" -ForegroundColor Red
                    $failedItems += "$($dll.FullName) ($errorMessage)"
                }
            }
        } else {
            Write-Log "No matching DLL files found."
        }
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Failed to enumerate DLL files: $errorMessage"
        Write-Host "Failed to enumerate DLL files: $errorMessage" -ForegroundColor Red
        $failedItems += "DLL scan failed ($errorMessage)"
    }

    if ($removedItems.Count -gt 0) {
        Write-Host "`nRemoved items:" -ForegroundColor Green
        $removedItems | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    }
    if ($missingItems.Count -gt 0) {
        Write-Host "`nNot found (already missing):" -ForegroundColor Yellow
        $missingItems | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }
    if ($failedItems.Count -gt 0) {
        Write-Host "`nFailed to remove:" -ForegroundColor Red
        $failedItems | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }

    Write-Log "=== File cleanup completed ==="
    Write-Host "File cleanup completed. Log file: $logPath"
}

function Show-Menu {
    Clear-Host
    Write-Host "=== USB Miner Cleanup ==="
    Write-Host "1 - Remove registry entries and scheduled task (will reboot)"
    Write-Host "2 - Remove files from C:\Windows\System32"
    Write-Host "3 - Clean USB drive (remove attributes, sysvolume, shortcuts)"
    Write-Host "0 - Exit"
    Write-Host ""
    return Read-Host "Select action"
}

while ($true) {
    switch (Show-Menu) {
        '1' { Remove-MalwareRegistry; break }
        '2' { Remove-MalwareFiles }
        '3' { Clear-UsbDrive }
        '0' { Write-Host "Exit. Log file: $logPath"; break }
        default { Write-Host "Unknown choice. Try again." }
    }
}