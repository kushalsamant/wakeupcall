# build-and-package-wakeupcall.ps1
# Author: Kushal Samant with assistance from Grok 3
# Purpose: Build and package the WakeUpCall Android app for Google Play without Android Studio
# Requirements: Windows, PowerShell, Internet connection
# Project: https://github.com/kushalsamant/wakeupcall

# Configuration
$ErrorActionPreference = "Stop"
$projectDir = "$env:USERPROFILE\Documents\GitHub\wakeupcall"
$keystoreFile = "my-release-key.jks"
$keystoreAlias = "wakeupcall"
$apkInputPath = "android\app\build\outputs\apk\release\app-release.apk"
$apkOutputPath = "final-release.apk"
$androidSdkPath = "$env:LOCALAPPDATA\Android\Sdk"
$buildToolsVersion = "33.0.2"

# Function to check if a command exists
function Test-CommandExists {
    param ($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Step 1: Verify Prerequisites
# Check Node.js
if (-Not (Test-CommandExists "node")) {
    Invoke-Expression "winget install OpenJS.NodeJS"
}

# Check Java JDK
if (-Not (Test-CommandExists "java")) {
    Invoke-Expression "winget install Oracle.JDK.11"
}

# Check Android SDK
if (-Not (Test-Path $androidSdkPath)) {
    Invoke-Expression "winget install Google.AndroidSDK.CommandLineTools"
    $env:ANDROID_HOME = $androidSdkPath
    [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidSdkPath, "User")
    $env:PATH += ";$androidSdkPath\cmdline-tools\latest\bin;$androidSdkPath\platform-tools"
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "User")
    Invoke-Expression "sdkmanager 'platform-tools' 'platforms;android-33' 'build-tools;$buildToolsVersion'"
}

# Check Python
if (-Not (Test-CommandExists "python")) {
    Invoke-Expression "winget install Python.Python.3.10"
}

# Step 2: Navigate to Project Directory
if (-Not (Test-Path $projectDir)) {
    New-Item -Path $projectDir -ItemType Directory -Force
    Set-Location $projectDir\..
    Invoke-Expression "git clone https://github.com/kushalsamant/wakeupcall.git"
}
Set-Location $projectDir

# Step 3: Install Node.js Dependencies
Invoke-Expression "npm install"
if ($LASTEXITCODE -ne 0) {
    exit 1
}

# Step 4: Build Frontend (web → www)
if (Test-Path "web") {
    Push-Location "web"
    Invoke-Expression "npm install"
    Invoke-Expression "npm run build"
    Pop-Location
}

# Step 5: Capacitor Sync
Invoke-Expression "npx cap copy"
Invoke-Expression "npx cap sync android"
if ($LASTEXITCODE -ne 0) {
    exit 1
}

# Step 6: Build Backend (Flask, Twilio, Supabase)
if (Test-Path "backend") {
    Invoke-Expression "python -m venv venv"
    . .\venv\Scripts\Activate.ps1
    Invoke-Expression "pip install flask twilio supabase python-dotenv"
    if (-Not (Test-Path ".env")) {
        New-Item -Path .\.env -ItemType File
    }
}

# Step 7: Build Unsigned APK
Set-Location "android"
Invoke-Expression ".\gradlew assembleRelease"
Set-Location ".."
if (-Not (Test-Path $apkInputPath)) {
    exit 1
}

# Step 8: Generate or Use Keystore
if (-Not (Test-Path $keystoreFile)) {
    Invoke-Expression "keytool -genkey -v -keystore $keystoreFile -alias $keystoreAlias -keyalg RSA -keysize 2048 -validity 10000"
}

# Step 9: Sign APK
Invoke-Expression "jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore $keystoreFile $apkInputPath $keystoreAlias"

# Step 10: Zipalign APK
$zipalign = "$androidSdkPath\build-tools\$buildToolsVersion\zipalign.exe"
if (-Not (Test-Path $zipalign)) {
    Copy-Item $apkInputPath $apkOutputPath
} else {
    Start-Process -FilePath $zipalign -ArgumentList "-v 4 $apkInputPath $apkOutputPath" -Wait -NoNewWindow
}

# Step 11: Verify APK Signature
$apksigner = "$androidSdkPath\build-tools\$buildToolsVersion\apksigner.bat"
if (Test-Path $apksigner) {
    Start-Process -FilePath $apksigner -ArgumentList "verify $apkOutputPath" -Wait -NoNewWindow
}

# Step 12: Clean up
if (Test-CommandExists "deactivate") {
    deactivate
}