<#
.SYNOPSIS
    Installs JDK 17 and Maven 3.9.9 with proper environment variable configuration
.DESCRIPTION
    Downloads and installs Temurin JDK 17 and Apache Maven 3.9.9,
    sets JAVA_HOME and MAVEN_HOME, and adds them to PATH.
    Implements caching to avoid re-downloading if files exist.
.NOTES
    Requires PowerShell to be run as Administrator
#>

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
