# build-and-package-wakeupcall.ps1
# Author: Kushal Samant with assistance from Grok 3
# Purpose: Build and package the WakeUpCall Android native app with local-only fake call notifications
# Requirements: Windows, PowerShell, Internet connection
# Project: https://github.com/kushalsamant/wakeupcall
# Note: No backend, Supabase, Twilio, or phone numbers; uses local notifications for fake calls
#       Overwrites web/src/App.js, web/src/App.css, capacitor.config.json, CallActivity.java, activity_call.xml every run
#       Generates tree.txt, overwriting each run
#       Includes debugging, checks, verifications, syncs, resyncs, troubleshooting, execution policy, cleanup
#       Automates all manual commands (JDK, Android SDK, web/android init, winget, keystore)

# Configuration
[CmdletBinding()]
param ()
$ErrorActionPreference = "Stop"
$projectDir = "$env:USERPROFILE\Documents\GitHub\wakeupcall"
$treeFile = "$projectDir\tree.txt"
$keystoreFile = "my-release-key.jks"
$keystoreAlias = "wakeupcall"
$keystorePassword = "wakeupcall123" # Default keystore password
$apkInputPath = "android\app\build\outputs\apk\release\app-release.apk"
$apkOutputPath = "final-release.apk"
$androidSdkPath = "$env:LOCALAPPDATA\Android\Sdk"
$buildToolsVersion = "33.0.2"
$max実
$maxRetries = 3

# Set execution policy
try {
    Write-Verbose "Setting execution policy to Bypass for current process..."
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    Write-Host "Execution policy set to Bypass."
} catch {
    Write-Host "Failed to set execution policy: $_"
    Write-Host "Please run 'Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force' manually."
    exit 1
}

# Ensure project directory exists
try {
    Write-Verbose "Ensuring project directory $projectDir exists..."
    if (-Not (Test-Path $projectDir)) {
        New-Item -Path $projectDir -ItemType Directory -Force | Out-Null
        Write-Host "Created project directory: $projectDir"
    }
} catch {
    Write-Host "Failed to create project directory $projectDir : $_"
    Write-Host "Please ensure you have write permissions to $env:USERPROFILE\Documents\GitHub"
    exit 1
}

# Function to check if a command exists
function Test-CommandExists {
    param ($command)
    Write-Verbose "Checking if command '$command' exists..."
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    Write-Verbose "Command '$command' exists: $exists"
    return $exists
}

# Function to find JDK path
function Find-JdkPath {
    Write-Verbose "Searching for JDK installation..."
    $possiblePaths = @(
        "C:\Program Files\Eclipse Adoptium\",
        "C:\Program Files\Java\",
        "C:\Program Files\AdoptOpenJDK\",
        "C:\Program Files\OpenJDK\",
        "C:\Program Files (x86)\Java\",
        "C:\Program Files\BellSoft\"
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $jdkDirs = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "jdk" }
            foreach ($jdkDir in $jdkDirs) {
                $javaExe = Join-Path $jdkDir.FullName "bin\java.exe"
                if (Test-Path $javaExe) {
                    Write-Verbose "Found JDK at $($jdkDir.FullName)"
                    return $jdkDir.FullName
                }
            }
        }
    }
    return $null
}

# Function to handle winget installations with retry
function Install-Package {
    param ($packageId, $name, $manualUrl)
    Write-Host "Installing $name..."
    $attempt = 0
    while ($attempt -lt $maxRetries) {
        try {
            Write-Verbose "Attempting to install $name (Attempt $attempt)..."
            Invoke-Expression "winget install --id $packageId --silent --accept-package-agreements --accept-source-agreements" -ErrorAction Stop
            Write-Host "$name installed successfully."
            return $true
        } catch {
            $attempt++
            Write-Host "Failed to install $name via winget (Attempt $attempt): $_"
            if ($attempt -eq $maxRetries) {
                Write-Host "Failed to install $name after $maxRetries attempts."
                Write-Host "Please install $name manually from $manualUrl and rerun the script."
                exit 1
            }
            Start-Sleep -Seconds 5
        }
    }
}

# Function to install and configure Android SDK
function Install-AndroidSDK {
    Write-Host "Installing Android SDK..."
    $cmdlineToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    $cmdlineToolsZip = "$env:TEMP\cmdline-tools.zip"
    $cmdlineToolsDir = "$androidSdkPath\cmdline-tools"
    $cmdlineToolsBin = "$cmdlineToolsDir\latest\bin\sdkmanager.bat"

    # Download command-line tools
    Write-Verbose "Downloading Android command-line tools..."
    try {
        Invoke-WebRequest -Uri $cmdlineToolsUrl -OutFile $cmdlineToolsZip -ErrorAction Stop
    } catch {
        Write-Host "Failed to download Android command-line tools: $_"
        Write-Host "Please download from https://developer.android.com/studio#downloads and extract to $cmdlineToolsDir\latest"
        exit 1
    }

    # Extract command-line tools
    Write-Verbose "Extracting Android command-line tools..."
    try {
        Expand-Archive -Path $cmdlineToolsZip -DestinationPath $cmdlineToolsDir -Force -ErrorAction Stop
        # Move contents to 'latest' subdirectory
        $extractedDir = Get-ChildItem -Path $cmdlineToolsDir -Directory | Select-Object -First 1
        Move-Item -Path "$cmdlineToolsDir\$($extractedDir.Name)\*" -Destination "$cmdlineToolsDir\latest" -Force
        Remove-Item -Path $cmdlineToolsZip -Force
    } catch {
        Write-Host "Failed to extract Android command-line tools: $_"
        exit 1
    }

    # Verify installation
    Write-Verbose "Verifying Android SDK installation..."
    if (-Not (Test-Path $cmdlineToolsBin)) {
        Write-Host "Android SDK installation failed: $cmdlineToolsBin not found."
        exit 1
    }

    # Set environment variables
    Write-Verbose "Setting Android SDK environment variables..."
    $env:ANDROID_HOME = $androidSdkPath
    [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidSdkPath, "User")
    $env:PATH += ";$androidSdkPath\cmdline-tools\latest\bin;$androidSdkPath\platform-tools"
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "User")

    # Install required components
    Write-Host "Installing Android SDK components..."
    try {
        # Accept licenses non-interactively
        Write-Output "y" | Invoke-Expression "sdkmanager --licenses" -ErrorAction Stop
        Invoke-Expression "sdkmanager 'platform-tools' 'platforms;android-33' 'build-tools;$buildToolsVersion'" -ErrorAction Stop
    } catch {
        Write-Host "Failed to install Android SDK components: $_"
        exit 1
    }
    Write-Host "Android SDK installed and configured."
    return $true
}

# Function to initialize web directory (React frontend)
function Initialize-WebDirectory {
    Write-Host "Initializing web directory (React frontend)..."
    try {
        Write-Verbose "Running npx create-react-app..."
        Invoke-Expression "npx create-react-app web --template minimal" -ErrorAction Stop
        Write-Host "Web directory initialized."
    } catch {
        Write-Host "Failed to initialize web directory: $_"
        Write-Host "Please manually run 'npx create-react-app web --template minimal' in the project directory."
        exit 1
    }
}

# Function to configure frontend (overwrite App.js and App.css)
function Configure-Frontend {
    Write-Host "Configuring frontend files (overwriting App.js and App.css)..."
    $appJsPath = "web\src\App.js"
    $appCssPath = "web\src\App.css"

    # Content for App.js
    $appJsContent = @"
import React, { useState } from 'react';
import { LocalNotifications } from '@capacitor/local-notifications';
import './App.css';

function App() {
  const [callTime, setCallTime] = useState('');
  const [message, setMessage] = useState('');

  const scheduleNotification = async (callTime) => {
    const scheduleTime = new Date(callTime).getTime();
    const now = new Date().getTime();
    if (scheduleTime <= now) {
      alert('Please select a future time');
      return false;
    }

    await LocalNotifications.requestPermissions();
    await LocalNotifications.schedule({
      notifications: [
        {
          id: Math.floor(Math.random() * 1000000),
          title: 'WakeUpCall',
          body: 'Incoming wake-up call',
          schedule: { at: new Date(scheduleTime) },
          actionTypeId: 'CALL_ACTION',
          extra: { activity: 'com.kushal.wakeupcall.CallActivity' }
        }
      ]
    });
    return true;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage('');
    try {
      const scheduled = await scheduleNotification(callTime);
      if (scheduled) {
        setMessage('Wake-up call scheduled successfully!');
      } else {
        setMessage('Error: Please select a future time');
      }
    } catch (error) {
      setMessage('Error: Failed to schedule call');
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>WakeUpCall</h1>
        <p>Schedule your wake-up call</p>
        <form onSubmit={handleSubmit}>
          <div>
            <label>Call Time: </label>
            <input
              type="datetime-local"
              value={callTime}
              onChange={(e) => setCallTime(e.target.value)}
              required
            />
          </div>
          <button type="submit">Schedule Call</button>
        </form>
        {message && <p>{message}</p>}
      </header>
    </div>
  );
}

export default App;
"@

    # Content for App.css
    $appCssContent = @"
.App {
  text-align: center;
}

.App-header {
  background-color: #282c34;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  font-size: calc(10px + 2vmin);
  color: white;
}

form {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

input, button {
  padding: 10px;
  font-size: 16px;
}

button {
  background-color: #61dafb;
  border: none;
  cursor: pointer;
}

button:hover {
  background-color: #21a1f1;
}
"@

    # Remove existing files to ensure clean overwrite
    Write-Verbose "Removing existing App.js and App.css if present..."
    Remove-Item -Path $appJsPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $appCssPath -Force -ErrorAction SilentlyContinue

    # Write files
    Write-Verbose "Creating web\src directory and overwriting frontend files..."
    New-Item -Path "web\src" -ItemType Directory -Force
    Set-Content -Path $appJsPath -Value $appJsContent
    Set-Content -Path $appCssPath -Value $appCssContent

    # Verify files
    if (Test-Path $appJsPath) {
        Write-Host "Verified: $appJsPath overwritten."
    } else {
        Write-Host "Error: $appJsPath was not created."
        exit 1
    }
    if (Test-Path $appCssPath) {
        Write-Host "Verified: $appCssPath overwritten."
    } else {
        Write-Host "Error: $appCssPath was not created."
        exit 1
    }
}

# Function to initialize Capacitor and Android platform
function Initialize-Capacitor {
    Write-Host "Initializing Capacitor and Android platform..."
    try {
        Write-Verbose "Clearing npm cache..."
        Invoke-Expression "npm cache clean --force" -ErrorAction Stop
        Write-Verbose "Installing Capacitor dependencies..."
        Invoke-Expression "npm install @capacitor/core @capacitor/cli@latest @capacitor/android @capacitor/local-notifications" -ErrorAction Stop
        Write-Verbose "Running npx cap init..."
        Invoke-Expression "npx cap init WakeUpCall com.kushal.wakeupcall --web-dir=web/build" -ErrorAction Stop
        # Overwrite capacitor.config.json with specified content
        $capConfig = @"
{
  "appId": "com.kushal.wakeupcall",
  "appName": "WakeUpCall",
  "webDir": "web/build",
  "bundledWebRuntime": false,
  "plugins": {
    "LocalNotifications": {
      "smallIcon": "ic_stat_notification",
      "iconColor": "#488AFF",
      "sound": "default"
    }
  }
}
"@
        Write-Verbose "Removing existing capacitor.config.json if present..."
        Remove-Item -Path "capacitor.config.json" -Force -ErrorAction SilentlyContinue
        Write-Verbose "Overwriting capacitor.config.json..."
        Set-Content -Path "capacitor.config.json" -Value $capConfig
        # Verify capacitor.config.json
        if (Test-Path "capacitor.config.json") {
            Write-Host "Verified: capacitor.config.json overwritten."
        } else {
            Write-Host "Error: capacitor.config.json was not created."
            exit 1
        }
        Write-Verbose "Running npx cap add android..."
        Invoke-Expression "npx cap add android" -ErrorAction Stop
        Write-Host "Capacitor and Android platform initialized."
    } catch {
        Write-Host "Failed to initialize Capacitor: $_"
        Write-Host "Please manually run 'npm install @capacitor/core @capacitor/cli@latest @capacitor/android @capacitor/local-notifications', 'npx cap init WakeUpCall com.kushal.wakeupcall --web-dir=web/build', and 'npx cap add android'."
        exit 1
    }
}

# Function to configure Android for CallActivity
function Configure-CallActivity {
    Write-Host "Configuring CallActivity for fake phone call..."
    $javaDir = "android\app\src\main\java\com\kushal\wakeupcall"
    $layoutDir = "android\app\src\main\res\layout"
    $manifestFile = "android\app\src\main\AndroidManifest.xml"
    $callActivityPath = "$javaDir\CallActivity.java"
    $layoutPath = "$layoutDir\activity_call.xml"

    # Remove existing CallActivity files to ensure clean overwrite
    Write-Verbose "Removing existing CallActivity.java and activity_call.xml if present..."
    Remove-Item -Path $callActivityPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $layoutPath -Force -ErrorAction SilentlyContinue

    # Create directories
    Write-Verbose "Creating directories for CallActivity..."
    New-Item -Path $javaDir -ItemType Directory -Force
    New-Item -Path $layoutDir -ItemType Directory -Force

    # Write CallActivity.java
    $callActivityContent = @"
package com.kushal.wakeupcall;

import android.os.Bundle;
import android.view.WindowManager;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

public class CallActivity extends AppCompatActivity {
    private Ringtone ringtone;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_call);

        // Show on lock screen
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON |
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD |
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);

        // Play ringtone
        ringtone = RingtoneManager.getRingtone(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE));
        if (ringtone != null) {
            ringtone.play();
        }

        // UI elements
        TextView callerText = findViewById(R.id.caller_text);
        callerText.setText("Incoming WakeUpCall");
        Button acceptButton = findViewById(R.id.accept_button);
        Button declineButton = findViewById(R.id.decline_button);

        acceptButton.setOnClickListener(v -> finish());
        declineButton.setOnClickListener(v -> finish());
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (ringtone != null && ringtone.isPlaying()) {
            ringtone.stop();
        }
    }
}
"@
    Write-Verbose "Writing CallActivity.java..."
    Set-Content -Path $callActivityPath -Value $callActivityContent

    # Write activity_call.xml
    $layoutContent = @"
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#FF000000">

    <TextView
        android:id="@+id/caller_text"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_centerInParent="true"
        android:text="Incoming Call"
        android:textColor="#FFFFFFFF"
        android:textSize="24sp" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_alignParentBottom="true"
        android:orientation="horizontal"
        android:padding="16dp">

        <Button
            android:id="@+id/accept_button"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Accept"
            android:backgroundTint="#FF00FF00" />

        <Button
            android:id="@+id/decline_button"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Decline"
            android:backgroundTint="#FFFF0000" />

    </LinearLayout>
</RelativeLayout>
"@
    Write-Verbose "Writing activity_call.xml..."
    Set-Content -Path $layoutPath -Value $layoutContent

    # Update AndroidManifest.xml
    Write-Verbose "Updating AndroidManifest.xml..."
    $manifestContent = Get-Content $manifestFile -Raw
    $newActivity = '<activity android:name=".CallActivity" android:screenOrientation="portrait" android:theme="@android:style/Theme.NoTitleBar.Fullscreen" />'
    if (-Not ($manifestContent -match "CallActivity")) {
        $manifestContent = $manifestContent -replace '</application>', "    $newActivity`n    </application>"
        $manifestContent = $manifestContent -replace '<manifest ', '<manifest android:installLocation="auto" '
        $manifestContent = $manifestContent -replace '<application ', '<application android:allowBackup="true" '
        Set-Content -Path $manifestFile -Value $manifestContent
    }

    # Add notification permission
    if (-Not ($manifestContent -match "POST_NOTIFICATIONS")) {
        $newPermission = '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />'
        $manifestContent = $manifestContent -replace '</manifest>', "$newPermission`n</manifest>"
        Set-Content -Path $manifestFile -Value $manifestContent
    }

    # Verify CallActivity files
    Write-Verbose "Verifying CallActivity files..."
    if (Test-Path $callActivityPath) {
        Write-Host "Verified: $callActivityPath overwritten."
    } else {
        Write-Host "Error: $callActivityPath was not created."
        exit 1
    }
    if (Test-Path $layoutPath) {
        Write-Host "Verified: $layoutPath overwritten."
    } else {
        Write-Host "Error: $layoutPath was not created."
        exit 1
    }
}

# Function to perform cleanup
function Perform-Cleanup {
    Write-Host "Performing cleanup..."
    Write-Verbose "Removing backend directory if present..."
    if (Test-Path "backend") {
        Remove-Item -Path "backend" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed backend directory."
    }
    Write-Verbose "Removing .env file if present..."
    if (Test-Path ".env") {
        Remove-Item -Path ".env" -Force -ErrorAction SilentlyContinue
        Write-Host "Removed .env file."
    }
    Write-Verbose "Checking android directory validity..."
    if (Test-Path "android") {
        if (-Not (Test-Path "android\app\src\main\AndroidManifest.xml")) {
            Write-Host "Invalid android directory detected. Removing..."
            Remove-Item -Path "android" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed invalid android directory."
        }
    }
}

# Function to update tree.txt
function Update-TreeFile {
    Write-Host "Updating tree.txt..."
    Write-Verbose "Generating directory tree..."
    try {
        Invoke-Expression "tree /f > $treeFile" -ErrorAction Stop
        if (Test-Path $treeFile) {
            Write-Host "Verified: $treeFile updated."
        } else {
            Write-Host "Error: $treeFile was not created."
            exit 1
        }
    } catch {
        Write-Host "Failed to update tree.txt: $_"
        exit 1
    }
}

# Step 1: Verify Prerequisites
Write-Host "Updating winget source..."
try {
    winget source update
} catch {
    Write-Host "Failed to update winget source: $_"
    Write-Host "Continuing, but winget installations may fail."
}

# Check Node.js
Write-Verbose "Checking Node.js..."
if (-Not (Test-CommandExists "node")) {
    Install-Package "OpenJS.NodeJS.LTS" "Node.js" "https://nodejs.org"
}

# Check Java JDK and JAVA_HOME
Write-Verbose "Checking Java JDK and JAVA_HOME..."
if (-Not (Test-CommandExists "java") -or -Not $env:JAVA_HOME -or -Not (Test-Path "$env:JAVA_HOME\bin\java.exe")) {
    Write-Host "Java JDK or JAVA_HOME not properly configured."
    # Attempt to find existing JDK
    $jdkPath = Find-JdkPath
    if ($jdkPath) {
        Write-Host "Setting JAVA_HOME to $jdkPath..."
        $env:JAVA_HOME = $jdkPath
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkPath, "User")
        $env:PATH += ";$jdkPath\bin"
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "User")
    } else {
        # Install JDK
        Install-Package "EclipseAdoptium.Temurin.21.JDK" "Java JDK" "https://adoptium.net/temurin/releases"
        # Try to find JDK again
        $jdkPath = Find-JdkPath
        if ($jdkPath) {
            Write-Host "Setting JAVA_HOME to $jdkPath..."
            $env:JAVA_HOME = $jdkPath
            [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkPath, "User")
            $env:PATH += ";$jdkPath\bin"
            [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "User")
        } else {
            Write-Host "Failed to locate JDK installation after installation."
            Write-Host "Please manually install JDK from https://adoptium.net/temurin/releases and set JAVA_HOME."
            exit 1
        }
    }
}
Write-Verbose "JAVA_HOME set to $env:JAVA_HOME"
Write-Verbose "Verifying Java version..."
Invoke-Expression "java -version"

# Check Android SDK
Write-Verbose "Checking Android SDK..."
if (-Not (Test-Path $androidSdkPath)) {
    Install-AndroidSDK
}

# Step 2: Navigate to Project Directory
Write-Verbose "Navigating to project directory..."
if (-Not (Test-Path $projectDir)) {
    Write-Host "Cloning repository..."
    New-Item -Path $projectDir -ItemType Directory -Force
    Set-Location $projectDir\..
    try {
        Invoke-Expression "git clone https://github.com/kushalsamant/wakeupcall.git" -ErrorAction Stop
    } catch {
        Write-Host "Failed to clone repository: $_"
        exit 1
    }
}
Set-Location $projectDir

# Step 3: Perform Cleanup
Perform-Cleanup

# Step 4: Check and Initialize Required Directories
Write-Verbose "Checking web directory..."
if (-Not (Test-Path "web")) {
    Write-Host "Web directory not found. Initializing React frontend..."
    Initialize-WebDirectory
}
# Configure frontend files
Configure-Frontend

# Step 5: Build Frontend (web → build)
Write-Host "Building frontend..."
Push-Location "web"
Write-Verbose "Installing frontend dependencies..."
Invoke-Expression "npm install" -ErrorAction Stop
Invoke-Expression "npm install @capacitor/local-notifications" -ErrorAction Stop
Write-Verbose "Fixing npm vulnerabilities..."
Invoke-Expression "npm audit fix" -ErrorAction Stop
Write-Verbose "Running npm run build..."
Invoke-Expression "npm run build" -ErrorAction Stop
Pop-Location
if (-Not (Test-Path "web/build")) {
    Write-Host "Frontend build failed. Please check 'web' directory and 'npm run build'."
    Write-Host "Troubleshooting: Run 'npm install', 'npm audit fix', and 'npm run build' in 'web/' manually."
    exit 1
}

# Step 6: Initialize Capacitor and Android Platform
Write-Verbose "Checking android directory..."
if (-Not (Test-Path "android")) {
    Write-Host "Android directory not found. Initializing Capacitor and Android platform..."
    Initialize-Capacitor
}

# Step 7: Configure Android CallActivity
if (Test-Path "android") {
    Configure-CallActivity
}

# Step 8: Update tree.txt
Update-TreeFile

# Step 9: Install Node.js Dependencies
Write-Host "Installing Node.js dependencies..."
$attempt = 0
while ($attempt -lt $maxRetries) {
    try {
        Write-Verbose "Installing npm dependencies (Attempt $attempt)..."
        Invoke-Expression "npm install" -ErrorAction Stop
        Invoke-Expression "npm install @capacitor/core @capacitor/cli@latest @capacitor/android @capacitor/local-notifications" -ErrorAction Stop
        Write-Verbose "Fixing npm vulnerabilities..."
        Invoke-Expression "npm audit fix" -ErrorAction Stop
        Write-Host "Node.js dependencies installed."
        break
    } catch {
        $attempt++
        Write-Host "npm install failed (Attempt $attempt): $_"
        if ($attempt -eq $maxRetries) {
            Write-Host "Failed to install Node.js dependencies after $maxRetries attempts."
            Write-Host "Troubleshooting: Run 'npm cache clean --force' and 'npm install' manually."
            exit 1
        }
        Start-Sleep -Seconds 5
    }
}

# Step 10: Capacitor Sync with Resync
Write-Host "Syncing Capacitor..."
$attempt = 0
while ($attempt -lt $maxRetries) {
    try {
        Write-Verbose "Running npx cap copy (Attempt $attempt)..."
        Invoke-Expression "npx cap copy" -ErrorAction Stop
        Write-Verbose "Running npx cap sync android (Attempt $attempt)..."
        Invoke-Expression "npx cap sync android" -ErrorAction Stop
        Write-Host "Capacitor synced successfully."
        break
    } catch {
        $attempt++
        Write-Host "Capacitor sync failed (Attempt $attempt): $_"
        if ($attempt -eq $maxRetries) {
            Write-Host "Failed to sync Capacitor after $maxRetries attempts."
            Write-Host "Troubleshooting: Run 'npx cap sync android' manually or check 'web/build'."
            exit 1
        }
        Write-Verbose "Attempting resync..."
        Start-Sleep -Seconds 5
    }
}

# Step 11: Build Unsigned APK
Write-Host "Building APK..."
Set-Location "android"
Write-Verbose "Running gradlew assembleRelease..."
Invoke-Expression ".\gradlew assembleRelease" -ErrorAction Stop
Set-Location ".."
if (-Not (Test-Path $apkInputPath)) {
    Write-Host "APK build failed."
    Write-Host "Troubleshooting: Run './gradlew assembleRelease' in 'android/' manually."
    exit 1
}

# Step 12: Generate or Use Keystore
Write-Host "Checking keystore..."
if (-Not (Test-Path $keystoreFile)) {
    Write-Host "Generating new keystore..."
    try {
        $keytoolCmd = "keytool -genkey -v -keystore $keystoreFile -alias $keystoreAlias -keyalg RSA -keysize 2048 -validity 10000 -storepass $keystorePassword -keypass $keystorePassword -dname 'CN=Kushal Samant, OU=WakeUpCall, O=Personal, L=Unknown, S=Unknown, C=Unknown'"
        Invoke-Expression $keytoolCmd -ErrorAction Stop
    } catch {
        Write-Host "Failed to generate keystore: $_"
        exit 1
    }
}

# Step 13: Sign APK
Write-Host "Signing APK..."
try {
    $jarsignerCmd = "jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore $keystoreFile -storepass $keystorePassword $apkInputPath $keystoreAlias"
    Invoke-Expression $jarsignerCmd -ErrorAction Stop
} catch {
    Write-Host "Failed to sign APK: $_"
    Write-Host "Troubleshooting: Verify keystore and password."
    exit 1
}

# Step 14: Zipalign APK
Write-Host "Zipaligning APK..."
$zipalign = "$androidSdkPath\build-tools\$buildToolsVersion\zipalign.exe"
if (-Not (Test-Path $zipalign)) {
    Write-Host "Zipalign not found. Copying unsigned APK..."
    Copy-Item $apkInputPath $apkOutputPath
} else {
    try {
        Start-Process -FilePath $zipalign -ArgumentList "-v 4 $apkInputPath $apkOutputPath" -Wait -NoNewWindow
    } catch {
        Write-Host "Zipalign failed: $_"
        Write-Host "Troubleshooting: Verify Android SDK build-tools installation."
        exit 1
    }
}

# Step 15: Verify APK Signature
Write-Host "Verifying APK signature..."
$apksigner = "$androidSdkPath\build-tools\$buildToolsVersion\apksigner.bat"
if (Test-Path $apksigner) {
    try {
        Start-Process -FilePath $apksigner -ArgumentList "verify $apkOutputPath" -Wait -NoNewWindow
    } catch {
        Write-Host "APK signature verification failed: $_"
        exit 1
    }
}

Write-Host "Build completed successfully. APK: $apkOutputPath"
Write-Host "Test the APK: adb install $apkOutputPath"
Write-Host "For Google Play, upload $apkOutputPath to the Play Console."