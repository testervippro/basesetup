
# Configuration
$cacheDir = "$env:TEMP\java-maven-install-cache"
$jdkUrl = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10+7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.10_7.msi"
$jdkInstaller = "$cacheDir\OpenJDK17.msi"
$jdkInstallPath = "C:\Program Files\Eclipse Adoptium\jdk-17.0.10.7-hotspot"

$mavenUrl = "https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip"
$mavenZip = "$cacheDir\apache-maven-3.9.9.zip"
$mavenInstallPath = "C:\Program Files\apache-maven-3.9.9"

# Create cache directory if it doesn't exist
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}

# Function to clean up old installations
function Cleanup-OldInstallation {
    param (
        [string]$installPath
    )

    if (Test-Path $installPath) {
        Write-Host "Removing old installation at $installPath..."
        try {
            Remove-Item -Path $installPath -Recurse -Force -ErrorAction Stop
            Write-Host "Cleanup complete."
            return $true
        }
        catch {
            Write-Warning "Failed to remove old installation: $_"
            return $false
        }
    }
    return $true
}

# JDK 17 Installation
if (-not (Test-Path $jdkInstallPath)) {
    # Download JDK if not in cache
    if (-not (Test-Path $jdkInstaller)) {
        Write-Host "Downloading JDK 17..."
        try {
            Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkInstaller -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to download JDK: $_"
            exit 1
        }
    } else {
        Write-Host "Using cached JDK installer..."
    }

    # Cleanup old installation
    Cleanup-OldInstallation -installPath $jdkInstallPath

    # Install JDK
    Write-Host "Installing JDK 17..."
    try {
        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$jdkInstaller`" /quiet ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome" -ErrorAction Stop
        Write-Host "JDK installation completed successfully."
    }
    catch {
        Write-Error "Failed to install JDK: $_"
        exit 1
    }
} else {
    Write-Host "JDK already installed at $jdkInstallPath"
}

# Maven Installation
if (-not (Test-Path $mavenInstallPath)) {
    # Download Maven if not in cache
    if (-not (Test-Path $mavenZip)) {
        Write-Host "Downloading Maven 3.9.9..."
        try {
            Invoke-WebRequest -Uri $mavenUrl -OutFile $mavenZip -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to download Maven: $_"
            exit 1
        }
    } else {
        Write-Host "Using cached Maven zip..."
    }

    # Cleanup old installation
    Cleanup-OldInstallation -installPath $mavenInstallPath

    # Install Maven
    Write-Host "Installing Maven 3.9.9..."
    try {
        # Extract to temporary location first
        $tempMavenPath = "$cacheDir\maven-temp"
        if (Test-Path $tempMavenPath) {
            Remove-Item -Path $tempMavenPath -Recurse -Force
        }
        
        Expand-Archive -Path $mavenZip -DestinationPath $tempMavenPath -Force -ErrorAction Stop
        
        # Get the extracted folder name (since it's inside the zip)
        $extractedFolder = Get-ChildItem -Path $tempMavenPath -Directory | Select-Object -First 1
        
        if ($extractedFolder) {
            # Move to final location
            Move-Item -Path $extractedFolder.FullName -Destination $mavenInstallPath -Force -ErrorAction Stop
            Write-Host "Maven installation completed successfully."
        } else {
            throw "No directory found in the Maven zip file"
        }
        
        # Cleanup temp
        Remove-Item -Path $tempMavenPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error "Failed to install Maven: $_"
        exit 1
    }
} else {
    Write-Host "Maven already installed at $mavenInstallPath"
}

# Set Environment Variables
Write-Host "Setting environment variables..."

# Set JAVA_HOME
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, "Machine")
Write-Host "JAVA_HOME set to: $jdkInstallPath"

# Set MAVEN_HOME
[Environment]::SetEnvironmentVariable("MAVEN_HOME", $mavenInstallPath, "Machine")
Write-Host "MAVEN_HOME set to: $mavenInstallPath"

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine") -split ';'
$newPath = $currentPath | Where-Object { $_ -ne $null -and $_ -ne '' }

# Add JDK bin if not already in PATH
if ($newPath -notcontains "$jdkInstallPath\bin") {
    $newPath += "$jdkInstallPath\bin"
}

# Add Maven bin if not already in PATH
if ($newPath -notcontains "$mavenInstallPath\bin") {
    $newPath += "$mavenInstallPath\bin"
}

# Update PATH
[Environment]::SetEnvironmentVariable("Path", ($newPath -join ';'), "Machine")

Write-Host "Installation and configuration complete!"
Write-Host "You may need to restart your terminal or computer for changes to take effect."

# Verify installation
try {
    Write-Host "`nVerifying installations..."
    $javaVersion = & "$jdkInstallPath\bin\java.exe" -version 2>&1 | Select-String "version"
    Write-Host "Java version: $($javaVersion -join ' ')"

    $mavenVersion = & "$mavenInstallPath\bin\mvn.cmd" --version 2>&1 | Select-String "Apache Maven"
    Write-Host "Maven version: $($mavenVersion -join ' ')"
}
catch {
    Write-Warning "Verification failed: $_"
    Write-Warning "Please restart your terminal or computer and try verification again."
}


# ------------------ Config ------------------
$nodeInstallerUrl = "https://nodejs.org/dist/v20.19.0/node-v20.19.0-x64.msi"
$nodeInstallerPath = "$env:TEMP\node-v20.19.0-x64.msi"
$nodeInstallDir = "${env:ProgramFiles}\nodejs"
$npmGlobalDir = "$env:APPDATA\npm"
$appiumCacheDir = "$env:LOCALAPPDATA\appium-cache"

# ------------------ Clean Up Old Versions ------------------
Write-Host "Removing old Node.js & Appium..."
Remove-Item -Recurse -Force "$nodeInstallDir" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$npmGlobalDir\appium*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$appiumCacheDir" -ErrorAction SilentlyContinue

# ------------------ Download Node.js ------------------
Write-Host "Downloading Node.js v20.19.0..."
Invoke-WebRequest -Uri $nodeInstallerUrl -OutFile $nodeInstallerPath

# ------------------ Install Node.js ------------------
Write-Host "Installing Node.js silently..."
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$nodeInstallerPath`" /qn" -Wait

# ------------------ Add to PATH ------------------
$nodePath = "${env:ProgramFiles}\nodejs"
if (-not ($env:Path -like "*$nodePath*")) {
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$nodePath;$npmGlobalDir", [System.EnvironmentVariableTarget]::Machine)
    $env:Path += ";$nodePath;$npmGlobalDir"
    Write-Host " Node.js path added to system PATH"
}

# ------------------ Install Appium & Appium Doctor ------------------
Write-Host " Installing Appium and Appium Doctor globally..."
npm install -g appium appium-doctor

# ------------------ Cache Appium Tools ------------------
Write-Host "Caching Appium tools..."
New-Item -ItemType Directory -Force -Path $appiumCacheDir | Out-Null
Copy-Item "$npmGlobalDir\appium*" -Destination $appiumCacheDir -Recurse -Force

# ------------------ Verify Installation ------------------
Write-Host "Verifying versions..."
node -v
npm -v
appium -v
appium-doctor

Write-Host "Setup completed successfully!"


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
Write-Host "Cleaning previous SDK setup..."
if (Test-Path $androidHome) {
    Remove-Item -Recurse -Force $androidHome
}
New-Item -ItemType Directory -Path $androidHome -Force | Out-Null

if (Test-Path $tempExtractPath) {
    Remove-Item -Recurse -Force $tempExtractPath
}

# ------------------ Download Tools ------------------
if (-Not (Test-Path $zipPath)) {
    Write-Host "Downloading Android command-line tools..."
    Invoke-WebRequest -Uri $toolsZipUrl -OutFile $zipPath
} else {
    Write-Host " Using cached ZIP from: $zipPath"
}

# ------------------ Extract Tools ------------------
Write-Host "Extracting tools..."
Expand-Archive -Path $zipPath -DestinationPath $tempExtractPath -Force
New-Item -ItemType Directory -Path $toolsFinalPath -Force | Out-Null
Move-Item -Path "$tempExtractPath\cmdline-tools\*" -Destination $toolsFinalPath -Force

# ------------------ Set Environment Variables ------------------
Write-Host "Setting environment variables..."
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "Machine")
[System.Environment]::SetEnvironmentVariable("ANDROID_USER_HOME", "$androidHome\.android", "Machine")
[System.Environment]::SetEnvironmentVariable("ANDROID_AVD_HOME", "$androidHome\.android\avd", "Machine")

# ------------------ Clean & Update System PATH ------------------
Write-Host "Updating system PATH..."

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
Write-Host "Installing SDK components..."
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" `
    "platform-tools" "emulator" "build-tools;$buildToolsVersion"

# ------------------ Accept Licenses (Manual) ------------------
Write-Host "Accepting licenses (manual input required)..."
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" --licenses

# ------------------ Verify adb ------------------
Write-Host " Verifying adb..."
$adbPath = Join-Path -Path $androidHome -ChildPath "platform-tools\adb.exe"
if (Test-Path $adbPath) {
    & $adbPath version
} else {
    Write-Host " adb not found"
}

# ------------------ Verify aapt2 ------------------
Write-Host " Verifying aapt2..."
$aapt2Path = Join-Path -Path $androidHome -ChildPath "build-tools\$buildToolsVersion\aapt2.exe"
if (Test-Path $aapt2Path) {
    & $aapt2Path version
} else {
    Write-Host " aapt2 not found"
}

Write-Host " Verifying Emulator..."
$emulator = Join-Path -Path $androidHome -ChildPath "emulator\emulator.exe"
if (Test-Path $emulator) {
    & $emulator -list-avds
} else {
    Write-Host " emulator not found"
}
# ------------------ Done ------------------
Write-Host " Android SDK setup completed successfully!"
Write-Host " SDK location: $androidHome"

# ------------------ Config ------------------
$appiumInstallerUrl = "https://github.com/appium/appium-inspector/releases/download/v2025.3.1/Appium-Inspector-2025.3.1-win.exe"
$appiumInstallerPath = "$env:TEMP\Appium-Inspector-2025.3.1-win.exe"
# --------------------------------------------

# ------------------ Check if Appium Installer Exists ------------------
if (-Not (Test-Path $appiumInstallerPath)) {
    # ------------------ Download Appium Inspector ------------------
    Write-Host "⬇ Downloading Appium Inspector..."
    Invoke-WebRequest -Uri $appiumInstallerUrl -OutFile $appiumInstallerPath
} else {
    Write-Host " Using cached Appium Inspector installer: $appiumInstallerPath"
}

# ------------------ Install Appium Inspector Silently ------------------
Write-Host " Installing Appium Inspector silently..."
Start-Process -FilePath $appiumInstallerPath -ArgumentList "/S" -NoNewWindow -Wait

# ------------------ Done ------------------
Write-Host " Appium Inspector installation completed successfully!"

# ------------------ Done ------------------
Write-Host " Android SDK setup completed successfully!"
Write-Host "SDK location: $androidHome"


# ------------------ Done ------------------
Write-Host " Android SDK setup completed successfully!"
Write-Host " SDK location: $androidHome"

