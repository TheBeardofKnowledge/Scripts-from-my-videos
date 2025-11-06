# Auto-elevate to Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting script as Administrator..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Set the Installer folder path
$InstallerPath = "$env:WINDIR\Installer"

# Section 1: Scanning installer files
$installerFilesRaw = Get-ChildItem -Path $InstallerPath -Filter *.ms? -File
$total1 = $installerFilesRaw.Count
$counter1 = 0
$installerFiles = @()

foreach ($file in $installerFilesRaw) {
    $counter1++
    Write-Progress -Activity "Step 1 of 4: Scanning installer files" `
                   -Status "Processing $($file.Name) ($counter1 of $total1)" `
                   -PercentComplete (($counter1 / $total1) * 100)
    $installerFiles += $file.Name
}
Write-Progress -Activity "Step 1 of 4: Scanning installer files" -Completed

# Section 2: Identifying used installer files via COM object
$installer = New-Object -ComObject WindowsInstaller.Installer
$products = $installer.ProductsEx("", "", 7)
$total2 = $products.Count
$counter2 = 0
$usedFiles = @()

foreach ($product in $products) {
    $counter2++
    Write-Progress -Activity "Step 2 of 4: Identifying used installer files" `
                   -Status "Checking product ($counter2 of $total2)" `
                   -PercentComplete (($counter2 / $total2) * 100)

    try {
        $localPackage = $product.InstallProperty("LocalPackage")
        if ($localPackage -match "\\Windows\\Installer\\") {
            $usedFiles += (Split-Path $localPackage -Leaf)
        }
    } catch {
        continue
    }
}
Write-Progress -Activity "Step 2 of 4: Identifying used installer files" -Completed

# Section 3: Filtering orphaned files
$total3 = $installerFiles.Count
$counter3 = 0
$orphanedFiles = @()

foreach ($file in $installerFiles) {
    $counter3++
    Write-Progress -Activity "Step 3 of 4: Filtering orphaned files" `
                   -Status "Checking $file ($counter3 of $total3)" `
                   -PercentComplete (($counter3 / $total3) * 100)

    if (($file -notin $usedFiles) -and ($file -notmatch "Adobe")) {
        $orphanedFiles += $file
    }
}
Write-Progress -Activity "Step 3 of 4: Filtering orphaned files" -Completed

# Display orphaned files
Write-Host "`nOrphaned installer files found:`n"
$orphanedFiles | ForEach-Object { Write-Host $_ }

# Section 4: Deleting orphaned files with progress bar and tracking freed space
$total4 = $orphanedFiles.Count
$counter4 = 0
$totalFreedBytes = 0

foreach ($file in $orphanedFiles) {
    $counter4++
    $fullPath = Join-Path $InstallerPath $file

    Write-Progress -Activity "Step 4 of 4: Deleting orphaned files" `
                   -Status "Deleting $file ($counter4 of $total4)" `
                   -PercentComplete (($counter4 / $total4) * 100)

    try {
        $size = (Get-Item $fullPath).Length
        Remove-Item -Path $fullPath -Force
        $totalFreedBytes += $size
        Write-Host "Deleted: $file"
    } catch {
        Write-Warning "Failed to delete: $file"
        continue
    }
}
Write-Progress -Activity "Step 4 of 4: Deleting orphaned files" -Completed

# Calculate and display disk space freed
$totalFreedMB = [math]::Round($totalFreedBytes / 1MB, 2)
$totalFreedGB = [math]::Round($totalFreedBytes / 1GB, 2)
Write-Host "`nTotal disk space freed: $totalFreedMB MB ($totalFreedGB GB)"

# Prevent script from exiting immediately
Write-Host "`nScript completed. All orphaned files processed."
Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")