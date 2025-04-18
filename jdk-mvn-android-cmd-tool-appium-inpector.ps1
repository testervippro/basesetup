# Configuration
$cacheDir = "$env:TEMP\java-maven-install-cache"
$jdkUrl = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10+7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.10_7.msi"
$jdkInstaller = "$cacheDir\OpenJDK17.msi"
$jdkInstallPath = "C:\Program Files\Eclipse Adoptium\jdk-17.0.10.7-hotspot"

$mavenUrl = "https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip"
$mavenZip = "$cacheDir\apache-maven-3.9.9.zip"
$mavenInstallPath = "C:\Program Files\apache-maven-3.9.9"

# Create cache directory
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}

function Cleanup-OldInstallation {
    param ([string]$installPath)
    if (Test-Path $installPath) {
        try {
            Remove-Item -Path $installPath -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Warning "Failed to remove old installation: $_"
        }
    }
}

# Install JDK
if (-not (Test-Path $jdkInstallPath)) {
    if (-not (Test-Path $jdkInstaller)) {
        Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkInstaller -ErrorAction Stop
    }
    Cleanup-OldInstallation -installPath $jdkInstallPath
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$jdkInstaller`" /quiet ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome"
}

# Install Maven
if (-not (Test-Path $mavenInstallPath)) {
    if (-not (Test-Path $mavenZip)) {
        Invoke-WebRequest -Uri $mavenUrl -OutFile $mavenZip -ErrorAction Stop
    }
    Cleanup-OldInstallation -installPath $mavenInstallPath
    $tempMavenPath = "$cacheDir\maven-temp"
    Remove-Item -Path $tempMavenPath -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $mavenZip -DestinationPath $tempMavenPath -Force
    $extractedFolder = Get-ChildItem -Path $tempMavenPath -Directory | Select-Object -First 1
    if ($extractedFolder) {
        Move-Item -Path $extractedFolder.FullName -Destination $mavenInstallPath -Force
    }
    Remove-Item -Path $tempMavenPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Set environment variables
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, "Machine")
[Environment]::SetEnvironmentVariable("MAVEN_HOME", $mavenInstallPath, "Machine")

$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine") -split ';'
$newPath = $currentPath | Where-Object { $_ -ne $null -and $_ -ne '' }
if ($newPath -notcontains "$jdkInstallPath\bin") { $newPath += "$jdkInstallPath\bin" }
if ($newPath -notcontains "$mavenInstallPath\bin") { $newPath += "$mavenInstallPath\bin" }
[Environment]::SetEnvironmentVariable("Path", ($newPath -join ';'), "Machine")

# Verify installation
& "$jdkInstallPath\bin\java.exe" -version
& "$mavenInstallPath\bin\mvn.cmd" --version

# Node.js & Appium Configuration
$nodeInstallerUrl = "https://nodejs.org/dist/v20.19.0/node-v20.19.0-x64.msi"
$nodeInstallerPath = "$env:TEMP\node-v20.19.0-x64.msi"
$nodeInstallDir = "$env:ProgramFiles\nodejs"
$npmGlobalDir = "$env:APPDATA\npm"
$appiumCacheDir = "$env:LOCALAPPDATA\appium-cache"

Remove-Item -Recurse -Force "$nodeInstallDir" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$npmGlobalDir\appium*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$appiumCacheDir" -ErrorAction SilentlyContinue

Invoke-WebRequest -Uri $nodeInstallerUrl -OutFile $nodeInstallerPath
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$nodeInstallerPath`" /qn" -Wait

if (-not ($env:Path -like "*$nodeInstallDir*")) {
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$nodeInstallDir;$npmGlobalDir", "Machine")
    $env:Path += ";$nodeInstallDir;$npmGlobalDir"
}

npm install -g appium appium-doctor
New-Item -ItemType Directory -Force -Path $appiumCacheDir | Out-Null
Copy-Item "$npmGlobalDir\appium*" -Destination $appiumCacheDir -Recurse -Force

node -v
npm -v
appium -v
appium-doctor

# Android SDK Configuration
$androidHome = "C:\android_sdk"
$toolsZipUrl = "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
$zipPath = "$env:TEMP\commandlinetools.zip"
$tempExtractPath = "$env:TEMP\cmdline-tools-temp"
$toolsFinalPath = "$androidHome\cmdline-tools\latest"

Remove-Item -Recurse -Force $androidHome -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $androidHome -Force | Out-Null
Remove-Item -Recurse -Force $tempExtractPath -ErrorAction SilentlyContinue

if (-Not (Test-Path $zipPath)) {
    Invoke-WebRequest -Uri $toolsZipUrl -OutFile $zipPath
}

Expand-Archive -Path $zipPath -DestinationPath $tempExtractPath -Force
New-Item -ItemType Directory -Path $toolsFinalPath -Force | Out-Null
Move-Item -Path "$tempExtractPath\cmdline-tools\*" -Destination $toolsFinalPath -Force

[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "Machine")
[System.Environment]::SetEnvironmentVariable("ANDROID_USER_HOME", "$androidHome\.android", "Machine")

$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$newPaths = @(
    "$toolsFinalPath\bin",
    "$androidHome\platform-tools",
    "$androidHome\emulator",
    "$androidHome\tools",
    "$androidHome\tools\bin"
)

foreach ($path in $newPaths) {
    if ($currentPath -notlike "*$path*") {
        $currentPath += ";$path"
    }
}

[System.Environment]::SetEnvironmentVariable("Path", $currentPath, "Machine")

Write-Host "All installations and configurations completed successfully!"
