# ------------------ Config ------------------
$androidHome = "C:\android_sdk"
$toolsZipUrl = "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
$zipFileName = "commandlinetools.zip"
$zipPath = "$env:TEMP\$zipFileName"
$tempExtractPath = "$env:TEMP\cmdline-tools-temp"
$toolsFinalPath = "$androidHome\cmdline-tools\latest"
$buildToolsVersion = "34.0.0"
# --------------------------------------------

# ------------------ Clean Environment ------------------
Write-Host "🧹 Cleaning previous SDK setup..."
if (Test-Path $androidHome) {
    Remove-Item -Recurse -Force $androidHome
}
New-Item -ItemType Directory -Path $androidHome -Force | Out-Null

if (Test-Path $tempExtractPath) {
    Remove-Item -Recurse -Force $tempExtractPath
}

# ------------------ Download Tools ------------------
if (-Not (Test-Path $zipPath)) {
    Write-Host "⬇️ Downloading Android command-line tools..."
    Invoke-WebRequest -Uri $toolsZipUrl -OutFile $zipPath
} else {
    Write-Host "📦 Using cached ZIP from: $zipPath"
}

# ------------------ Extract Tools ------------------
Write-Host "📦 Extracting tools..."
Expand-Archive -Path $zipPath -DestinationPath $tempExtractPath -Force
New-Item -ItemType Directory -Path $toolsFinalPath -Force | Out-Null
Move-Item -Path "$tempExtractPath\cmdline-tools\*" -Destination $toolsFinalPath -Force

# ------------------ Set Environment Variables ------------------
Write-Host "⚙️ Setting environment variables..."
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "Machine")
[System.Environment]::SetEnvironmentVariable("ANDROID_USER_HOME", "$androidHome\.android", "Machine")

# ------------------ Clean & Update System PATH ------------------
Write-Host "🔄 Updating system PATH..."

# Get current system PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

# Define Android-related paths
$newPaths = @(
    "$toolsFinalPath\bin",
    "$androidHome\platform-tools",
    "$androidHome\build-tools\$buildToolsVersion"
)

# Remove any old Android SDK paths
$filteredPath = ($currentPath -split ";") | Where-Object {
    ($_ -notmatch "android_sdk") -and ($_ -ne "")
}

# Append fresh Android SDK paths
$updatedPath = ($filteredPath + $newPaths) -join ";"
[System.Environment]::SetEnvironmentVariable("Path", $updatedPath, "Machine")

# Apply for current session
$env:ANDROID_HOME = $androidHome
$env:ANDROID_USER_HOME = "$androidHome\.android"
$env:Path = $updatedPath

# ------------------ Install Components ------------------
Write-Host "📥 Installing SDK components..."
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" `
    "platform-tools" "emulator" "build-tools;$buildToolsVersion"

# ------------------ Accept Licenses (Manual) ------------------
Write-Host "✅ Accepting licenses (manual input required)..."
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" --licenses

# ------------------ Verify adb ------------------
Write-Host "`n🔍 Verifying adb..."
$adbPath = Join-Path -Path $androidHome -ChildPath "platform-tools\adb.exe"
if (Test-Path $adbPath) {
    & $adbPath version
} else {
    Write-Host "❌ adb not found"
}

# ------------------ Verify aapt2 ------------------
Write-Host "`n🔍 Verifying aapt2..."
$aapt2Path = Join-Path -Path $androidHome -ChildPath "build-tools\$buildToolsVersion\aapt2.exe"
if (Test-Path $aapt2Path) {
    & $aapt2Path version
} else {
    Write-Host "❌ aapt2 not found"
}

# ------------------ Done ------------------
Write-Host "`n🎉 Android SDK setup completed successfully!"
Write-Host "👉 SDK location: $androidHome"
