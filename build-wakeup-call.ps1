#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a standalone Android wake-up call application and generates a signed APK.
    The app uses Kotlin, Android Studio project structure (managed by script),
    AlarmManager, and the user's default ringtone. No external services.
.DESCRIPTION
    This script automates the following:
    1. Checks for and installs Android Studio and JDK 17 if missing.
    2. Creates the Android project directory structure for "WakeUpCall".
    3. Writes necessary Kotlin source files (MainActivity.kt, AlarmReceiver.kt, CallActivity.kt).
    4. Writes layout XML files (activity_main.xml, activity_call.xml).
    5. Writes the AndroidManifest.xml.
    6. Writes build.gradle, settings.gradle, and other necessary Gradle files.
    7. Creates a keystore for signing the APK.
    8. Builds the release APK using Gradle.
    9. Signs the APK using jarsigner.
    10. Aligns the APK using zipalign.
.NOTES
    Author: Grok
    Date: May 23, 2025
    Prerequisites: Windows PowerShell, Internet for first-time tool setup.
    Run this script from the directory where it is saved (e.g., C:\Users\Kushal\Documents\GitHub\wakeupcall).
#>

# --- Configuration ---
$projectName = "WakeUpCall"
$packageName = "com.kushal.wakeupcall" # Changed to match your GitHub path and previous examples
$baseDir = "$env:USERPROFILE\Documents\GitHub\$projectName"
$keystoreFile = "wakeupcall.keystore"
$keystoreAlias = "wakeupcall"
$keystorePassword = "wakeupcall123" # Keep this secure if for actual release

# --- Helper Functions ---
function Test-CommandExists {
    param ($command)
    return $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

function Install-WingetPackage {
    param ($packageId, $packageNameForLog)
    Write-Host "Checking for $packageNameForLog..."
    if (-not (Test-CommandExists ($packageId.Split('.')[0]))) { # Basic check if main command exists
        Write-Host "Attempting to install $packageNameForLog via winget..."
        try {
            winget install --id $packageId --accept-package-agreements --accept-source-agreements --silent
            Write-Host "$packageNameForLog installed successfully via winget."
        } catch {
            Write-Error "Failed to install $packageNameForLog via winget: $_"
            Write-Host "Please install $packageNameForLog manually and ensure it's in your PATH."
            exit 1
        }
    } else {
        Write-Host "$packageNameForLog found."
    }
}

# --- Script Body ---
Write-Host "Starting the WakeUpCall APK build process..."
Start-Transcript -Path "$baseDir\build.log" -Append -Force

# Step 0: Clean up old project directory if it exists, then create it
Write-Host "Preparing project directory: $baseDir"
if (Test-Path $baseDir) {
    Write-Host "Removing existing project directory: $baseDir"
    Remove-Item -Path $baseDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path $baseDir -ItemType Directory -Force | Out-Null
Set-Location -Path $baseDir

# Step 1: Install Dependencies (Android Studio, JDK 17, Git)
Install-WingetPackage "Google.AndroidStudio" "Android Studio"
Install-WingetPackage "EclipseAdoptium.Temurin.17.JDK" "JDK 17"
Install-WingetPackage "Git.Git" "Git"

# Set JAVA_HOME environment variable if not set or incorrect
$jdk17Path = (Get-Command java | Select-Object -ExpandProperty Source | Split-Path -Parent | Split-Path -Parent)
if ($env:JAVA_HOME -ne $jdk17Path -or -not $env:JAVA_HOME) {
    Write-Host "Setting JAVA_HOME to $jdk17Path"
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk17Path, "User")
    $env:JAVA_HOME = $jdk17Path
    $env:PATH = "$env:JAVA_HOME\bin;$env:PATH" # Ensure JDK bin is in PATH for current session
    Write-Host "JAVA_HOME set. Please restart PowerShell if you encounter issues in a new session."
}
Write-Host "JAVA_HOME is currently: $env:JAVA_HOME"
if (-not (Test-Path "$env:JAVA_HOME\bin\java.exe")) {
    Write-Error "JAVA_HOME might not be set correctly or JDK is not found. Please verify JDK 17 installation and PATH."
    exit 1
}

# Step 2: Create Android Project Structure
Write-Host "Creating Android project structure..."
$appDir = Join-Path -Path $baseDir -ChildPath "app"
$srcDir = Join-Path -Path $appDir -ChildPath "src"
$mainDir = Join-Path -Path $srcDir -ChildPath "main"
$javaDir = Join-Path -Path $mainDir -ChildPath "java"
$packagePath = $packageName.Replace(".", "\")
$fullPackageDir = Join-Path -Path $javaDir -ChildPath $packagePath
$resDir = Join-Path -Path $mainDir -ChildPath "res"
$layoutDir = Join-Path -Path $resDir -ChildPath "layout"
$mipmapDirAnyDpi = Join-Path -Path $resDir -ChildPath "mipmap-anydpi-v26"
$mipmapDirHdpi = Join-Path -Path $resDir -ChildPath "mipmap-hdpi"
# Add other mipmap directories as needed (mdpi, xhdpi, xxhdpi, xxxhdpi)

New-Item -Path $appDir, $srcDir, $mainDir, $javaDir, $fullPackageDir, $resDir, $layoutDir, $mipmapDirAnyDpi, $mipmapDirHdpi -ItemType Directory -Force | Out-Null

# Step 3: Create AndroidManifest.xml
Write-Host "Creating AndroidManifest.xml..."
$manifestContent = @"
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$packageName">

    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />


    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.AppCompat.Light.NoActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <activity
            android:name=".CallActivity"
            android:exported="true"
            android:showWhenLocked="true"
            android:turnScreenOn="true"
            android:launchMode="singleTop"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar.FullScreen">
        </activity>
        <receiver android:name=".AlarmReceiver" android:exported="false" />
    </application>
</manifest>
"@
Set-Content -Path (Join-Path -Path $mainDir -ChildPath "AndroidManifest.xml") -Value $manifestContent

# Step 4: Create Kotlin Source Files
Write-Host "Creating Kotlin source files..."
# MainActivity.kt
$mainActivityContent = @"
package $packageName

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TimePicker
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import java.util.Calendar

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val timePicker = findViewById<TimePicker>(R.id.timePicker)
        val setButton = findViewById<Button>(R.id.setAlarmButton)

        setButton.setOnClickListener {
            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, timePicker.hour)
                set(Calendar.MINUTE, timePicker.minute)
                set(Calendar.SECOND, 0)
                if (before(Calendar.getInstance())) {
                    add(Calendar.DATE, 1)
                }
            }

            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                    Toast.makeText(this, "Alarm set for " + String.format("%02d:%02d", timePicker.hour, timePicker.minute), Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(this, "Permission to schedule exact alarms not granted.", Toast.LENGTH_LONG).show()
                    // Optionally, guide user to settings:
                    // startActivity(Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
                }
            } else {
                 alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
                Toast.makeText(this, "Alarm set for " + String.format("%02d:%02d", timePicker.hour, timePicker.minute), Toast.LENGTH_SHORT).show()
            }
        }
    }
}
"@
Set-Content -Path (Join-Path -Path $fullPackageDir -ChildPath "MainActivity.kt") -Value $mainActivityContent

# AlarmReceiver.kt
$alarmReceiverContent = @"
package $packageName

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.PowerManager
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.d("AlarmReceiver", "Alarm received!")

        // Acquire a wake lock to ensure CPU is running
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName::WakeLockTag")
        wakeLock.acquire(10*60*1000L /*10 minutes*/) // Timeout for the wakelock

        try {
            val callIntent = Intent(context, CallActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP) // Ensures CallActivity is brought to front
            }
            context.startActivity(callIntent)
            Log.d("AlarmReceiver", "CallActivity started")
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error starting CallActivity", e)
        } finally {
            wakeLock.release() // Release the wake lock
            Log.d("AlarmReceiver", "WakeLock released")
        }
    }
}
"@
Set-Content -Path (Join-Path -Path $fullPackageDir -ChildPath "AlarmReceiver.kt") -Value $alarmReceiverContent

# CallActivity.kt
$callActivityContent = @"
package $packageName

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Bundle
import android.os.Vibrator
import android.view.WindowManager
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import android.util.Log

class CallActivity : AppCompatActivity() {
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("CallActivity", "onCreate called")

        // Show activity over lock screen and turn screen on
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or // Keep screen on while this activity is visible
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD // Dismiss keyguard if unsecured
            )
        }
        // For full screen experience
        window.setFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)


        setContentView(R.layout.activity_call)
        Log.d("CallActivity", "Layout set")

        val acceptButton = findViewById<Button>(R.id.acceptButton)
        val declineButton = findViewById<Button>(R.id.declineButton)

        acceptButton.setOnClickListener {
            Log.d("CallActivity", "Accept button clicked")
            stopAlarm()
            finish()
        }

        declineButton.setOnClickListener {
            Log.d("CallActivity", "Decline button clicked")
            stopAlarm()
            finish()
        }

        playAlarm()
    }

    private fun playAlarm() {
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(this, ringtoneUri)
            ringtone?.let {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    it.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                }
                it.play()
                Log.d("CallActivity", "Ringtone playing")
            }

            // Vibrate
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (vibrator?.hasVibrator() == true) {
                val pattern = longArrayOf(0, 1000, 1000) // Vibrate for 1s, pause for 1s
                 if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    vibrator?.vibrate(android.os.VibrationEffect.createWaveform(pattern, 0)) // Repeat indefinitely
                 } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(pattern, 0)
                 }
                Log.d("CallActivity", "Vibrating")
            }
        } catch (e: Exception) {
            Log.e("CallActivity", "Error playing alarm", e)
        }
    }

    private fun stopAlarm() {
        ringtone?.stop()
        vibrator?.cancel()
        Log.d("CallActivity", "Alarm stopped")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarm() // Ensure alarm stops if activity is destroyed
        Log.d("CallActivity", "onDestroy called, alarm stopped")
    }
}
"@
Set-Content -Path (Join-Path -Path $fullPackageDir -ChildPath "CallActivity.kt") -Value $callActivityContent

# Step 5: Create Layout XML Files
Write-Host "Creating layout XML files..."
# activity_main.xml
$mainLayoutContent = @"
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center"
    android:padding="16dp"
    tools:context=".MainActivity">

    <TimePicker
        android:id="@+id/timePicker"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:timePickerMode="spinner"/>

    <Button
        android:id="@+id/setAlarmButton"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="24dp"
        android:text="Set Wake-Up Call"/>
</LinearLayout>
"@
Set-Content -Path (Join-Path -Path $layoutDir -ChildPath "activity_main.xml") -Value $mainLayoutContent

# activity_call.xml
$callLayoutContent = @"
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#E6000000" 
    android:padding="16dp">

    <TextView
        android:id="@+id/callStatusText"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_centerHorizontal="true"
        android:layout_marginTop="100dp"
        android:text="Incoming Wake-Up Call"
        android:textColor="@android:color/white"
        android:textSize="28sp"
        android:textStyle="bold"/>

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_alignParentBottom="true"
        android:layout_marginBottom="50dp"
        android:orientation="horizontal">

        <Button
            android:id="@+id/acceptButton"
            android:layout_width="0dp"
            android:layout_height="60dp"
            android:layout_weight="1"
            android:layout_marginEnd="8dp"
            android:backgroundTint="#4CAF50"
            android:text="Dismiss"
            android:textColor="@android:color/white"/>

        <Button
            android:id="@+id/declineButton"
            android:layout_width="0dp"
            android:layout_height="60dp"
            android:layout_weight="1"
            android:layout_marginStart="8dp"
            android:backgroundTint="#F44336"
            android:text="Stop Alarm"
            android:textColor="@android:color/white"/>
    </LinearLayout>
</RelativeLayout>
"@
Set-Content -Path (Join-Path -Path $layoutDir -ChildPath "activity_call.xml") -Value $callLayoutContent

# Step 6: Create Basic Resource Files (strings.xml, colors.xml, themes.xml)
Write-Host "Creating resource files (strings, colors, themes)..."
$valuesDir = Join-Path -Path $resDir -ChildPath "values"
New-Item -Path $valuesDir -ItemType Directory -Force | Out-Null

Set-Content -Path (Join-Path $valuesDir "strings.xml") -Value '<resources><string name="app_name">WakeUpCall</string></resources>'
Set-Content -Path (Join-Path $valuesDir "colors.xml") -Value '<resources><color name="black">#FF000000</color><color name="white">#FFFFFFFF</color></resources>'
# Basic Theme (Light.NoActionBar)
$themesContent = @"
<resources xmlns:tools="http://schemas.android.com/tools">
    <style name="Theme.WakeUpCall" parent="Theme.MaterialComponents.DayNight.NoActionBar">
        <item name="colorPrimary">@color/black</item>
        <item name="colorPrimaryVariant">@color/black</item>
        <item name="colorOnPrimary">@color/white</item>
        <item name="colorSecondary">@color/black</item>
        <item name="colorSecondaryVariant">@color/black</item>
        <item name="colorOnSecondary">@color/black</item>
        <item name="android:statusBarColor" tools:targetApi="l">?attr/colorPrimaryVariant</item>
        </style>
    <style name="Theme.AppCompat.Light.NoActionBar.FullScreen" parent="@style/Theme.AppCompat.Light.NoActionBar">
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionBar">false</item>
        <item name="android:windowFullscreen">true</item>
        <item name="android:windowContentOverlay">@null</item>
    </style>
</resources>
"@
Set-Content -Path (Join-Path $valuesDir "themes.xml") -Value $themesContent

# Create dummy launcher icons (replace with your actual icons)
Write-Host "Creating dummy launcher icons..."
Set-Content -Path (Join-Path $mipmapDirAnyDpi "ic_launcher.xml") -Value '<?xml version="1.0" encoding="utf-8"?><adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@android:color/black"/><foreground android:drawable="@android:color/white"/></adaptive-icon>'
# Create a simple ic_launcher_round.xml for mipmap-anydpi-v26
Set-Content -Path (Join-Path $mipmapDirAnyDpi "ic_launcher_round.xml") -Value '<?xml version="1.0" encoding="utf-8"?><adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@android:color/black"/><foreground android:drawable="@mipmap/ic_launcher_foreground_dummy_round"/></adaptive-icon>'
# Create a dummy foreground for round icon (simple white circle)
New-Item -Path (Join-Path $resDir -ChildPath "drawable") -ItemType Directory -Force | Out-Null
Set-Content -Path (Join-Path $resDir -ChildPath "drawable\ic_launcher_foreground_dummy_round.xml") -Value '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:height="108dp" android:width="108dp" android:viewportHeight="108" android:viewportWidth="108"><path android:fillColor="#FFF" android:pathData="M54,54m-40,0a40,40 0,1 1,80 0a40,40 0,1 1,-80 0"/></vector>'
# Create a placeholder ic_launcher.png in mipmap-hdpi (and other density folders if needed)
# For simplicity, this script only creates hdpi. A real app needs icons for all densities.
# This is a simple placeholder. You'd replace this with an actual 72x72 PNG.
New-Item -Path (Join-Path $mipmapDirHdpi "ic_launcher.png") -ItemType File -Force | Out-Null
New-Item -Path (Join-Path $mipmapDirHdpi "ic_launcher_round.png") -ItemType File -Force | Out-Null


# Step 7: Create Gradle Files (build.gradle, settings.gradle, local.properties, gradle.properties)
Write-Host "Creating Gradle files..."
# settings.gradle
$settingsGradleContent = @"
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "$projectName"
include ':app'
"@
Set-Content -Path (Join-Path $baseDir "settings.gradle") -Value $settingsGradleContent

# build.gradle (Project level)
$projectBuildGradleContent = @"
// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    id 'com.android.application' version '8.2.0' apply false // Use a recent stable version
    id 'org.jetbrains.kotlin.android' version '1.9.22' apply false // Match Kotlin version
}
"@
Set-Content -Path (Join-Path $baseDir "build.gradle") -Value $projectBuildGradleContent

# build.gradle (App level)
$appBuildGradleContent = @"
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    namespace '$packageName'
    compileSdk 34 // Target latest stable SDK

    defaultConfig {
        applicationId "$packageName"
        minSdk 26 // Android 8.0 Oreo - for exact alarms & modern features
        targetSdk 34
        versionCode 1
        versionName "1.0"

        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            minifyEnabled false // Set to true for production to shrink APK
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
     buildFeatures {
        viewBinding true // If you plan to use view binding
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.12.0' // Use recent stable versions
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.11.0'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4' // If using ConstraintLayout
    testImplementation 'junit:junit:4.13.2'
    androidTestImplementation 'androidx.test.ext:junit:1.1.5'
    androidTestImplementation 'androidx.test.espresso:espresso-core:3.5.1'
}
"@
Set-Content -Path (Join-Path $appDir "build.gradle") -Value $appBuildGradleContent

# proguard-rules.pro (empty for now)
Set-Content -Path (Join-Path $appDir "proguard-rules.pro") -Value "# Add project specific ProGuard rules here."

# gradle.properties
$gradlePropertiesContent = @"
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
# Kotlin version for the plugin if not managed by AGP
# kotlin.code.style=official
# Version of Compose, if used (not used in this script)
# android.defaults.buildfeatures.compose=true
# androidx.compose.compiler.plugins.kotlin: ĀP_KOTLIN_COMPILER_EXTENSION_VERSION
# androidx.compose.compiler.plugins.kotlin: ĀP_COMPOSE_COMPILER_VERSION
"@
Set-Content -Path (Join-Path $baseDir "gradle.properties") -Value $gradlePropertiesContent

# local.properties (pointing to Android SDK)
$sdkDir = $env:ANDROID_SDK_ROOT # Use ANDROID_SDK_ROOT if set
if (-not $sdkDir) {
    $sdkDir = "$env:LOCALAPPDATA\Android\Sdk" # Default location
}
$sdkDir = $sdkDir.Replace("\", "/") # Use forward slashes for properties file
$localPropertiesContent = @"
## This file is automatically generated by Gradle.
##
## More information about how to configure Gradle can befound at https://docs.gradle.org/current/userguide/configuring_gradle.html
## For more details on how to specify Android SDK build tools and NDK details, see:
## https://developer.android.com/studio/build/gradle-tips
#
## Location of the SDK. This is only used by Gradle.
## IMPORTANT: This path can be computed by the Gradle build system.
## (This means that you do not need to keep this file in your source control system,
## if you are using a Gradle version that supports this.)
sdk.dir=$sdkDir
"@
Set-Content -Path (Join-Path $baseDir "local.properties") -Value $localPropertiesContent


# Step 8: Create Gradle Wrapper
Write-Host "Creating Gradle wrapper..."
# Check if Android Studio is installed to get cmdline-tools path; otherwise, this step might require manual setup or a full AS install.
# For simplicity, we assume gradlew will be generated by a full Android Studio CLI or that 'gradle wrapper' command is available.
# If building in an environment without Android Studio fully set up for CLI project creation, this might be tricky.
# A common way is to copy gradlew files from a known-good project or ensure 'gradle' command itself is on PATH.
# This script will attempt to use 'gradle wrapper', assuming 'gradle' command is available.
if (Test-CommandExists "gradle") {
    try {
        Invoke-Expression "gradle wrapper --gradle-version 8.4 --distribution-type bin" # Use a recent Gradle version
        Write-Host "Gradle wrapper created."
    } catch {
        Write-Warning "Failed to create Gradle wrapper using 'gradle wrapper'. Ensure Gradle is installed and in PATH, or create wrapper manually."
        Write-Warning "Attempting to proceed, but build might fail if gradlew is missing."
    }
} else {
     Write-Warning "'gradle' command not found. Cannot create Gradle wrapper automatically. Build might fail if gradlew is missing."
     Write-Host "You might need to open the project in Android Studio once to generate the wrapper, or copy gradlew files from another project."
}
# If gradlew.bat does not exist after trying, copy a placeholder or exit
if (-not (Test-Path (Join-Path $baseDir "gradlew.bat"))) {
    Write-Warning "gradlew.bat not found. Please ensure it's created (e.g., by opening project in Android Studio once or copying from another project)."
    # As a last resort, if you have a template gradlew.bat, you can copy it here.
    # For now, we will proceed, but the build will likely fail.
}


# Step 9: Build the APK
Write-Host "Building the APK using Gradle..."
Push-Location $baseDir
try {
    if (Test-Path ".\gradlew.bat") {
        Invoke-Expression ".\gradlew.bat app:assembleRelease"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Gradle build failed. Check logs."
            Stop-Transcript
            exit 1
        }
        Write-Host "Gradle build successful."
    } else {
        Write-Error "gradlew.bat not found. Cannot build APK."
        Stop-Transcript
        exit 1
    }
} catch {
    Write-Error "Exception during Gradle build: $_"
    Stop-Transcript
    exit 1
}
Pop-Location

# Step 10: Generate Keystore (if it doesn't exist)
$keystorePath = Join-Path -Path $appDir -ChildPath $keystoreFile
Write-Host "Checking for keystore: $keystorePath"
if (-not (Test-Path $keystorePath)) {
    Write-Host "Keystore not found. Generating new keystore..."
    $dname = "CN=$($env:USERNAME), OU=Development, O=Personal, L=YourCity, ST=YourState, C=YourCountryCode" # Customize this
    try {
        Invoke-Expression "keytool -genkeypair -v -keystore `"$keystorePath`" -alias $keystoreAlias -keyalg RSA -keysize 2048 -validity 10000 -storepass $keystorePassword -keypass $keystorePassword -dname `"$dname`""
        Write-Host "Keystore generated successfully."
    } catch {
        Write-Error "Failed to generate keystore: $_"
        Stop-Transcript
        exit 1
    }
} else {
    Write-Host "Using existing keystore."
}

# Step 11: Sign the APK
Write-Host "Signing the APK..."
$unsignedApkPath = Join-Path -Path $appDir -ChildPath "build\outputs\apk\release\app-release-unsigned.apk" # Gradle usually outputs unsigned here
$signedApkPath = Join-Path -Path $appDir -ChildPath "build\outputs\apk\release\app-release-signed.apk"   # We will create this

if (-not (Test-Path $unsignedApkPath)) {
    Write-Warning "Unsigned APK not found at $unsignedApkPath. It might be directly created as signed or build failed."
    # Check if app-release.apk exists, maybe it's already signed or is the one to be signed
    $unsignedApkPath = Join-Path -Path $appDir -ChildPath "build\outputs\apk\release\app-release.apk"
    if (-not (Test-Path $unsignedApkPath)) {
        Write-Error "Release APK not found at $unsignedApkPath. Build might have failed."
        Stop-Transcript
        exit 1
    }
    Write-Host "Found app-release.apk, will attempt to sign it."
}

# Remove old signed APK if it exists to avoid jarsigner error
if (Test-Path $signedApkPath) { Remove-Item $signedApkPath -Force }

try {
    Invoke-Expression "jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore `"$keystorePath`" -storepass $keystorePassword `"$unsignedApkPath`" $keystoreAlias"
    Write-Host "APK signed successfully (intermediate step, will be overwritten by zipalign)."
    # jarsigner might modify in-place or require output. If it modifies in-place, $unsignedApkPath is now signed.
    # Let's assume it modifies in-place for simplicity now, then zipalign creates the final $signedApkPath.
    # For safety, copy to what zipalign expects as input if jarsigner modified in-place
    Copy-Item $unsignedApkPath $unsignedApkPath -Force # No real copy, but ensures variable is what zipalign will use.

} catch {
    Write-Error "Failed to sign APK: $_"
    Stop-Transcript
    exit 1
}

# Step 12: Zipalign the APK
Write-Host "Zipaligning the APK..."
$zipalignPath = Join-Path -Path $env:ANDROID_SDK_ROOT -ChildPath "build-tools"
# Find the latest build-tools version
$latestBuildTools = Get-ChildItem $zipalignPath | Where-Object {$_.PSIsContainer} | Sort-Object Name -Descending | Select-Object -First 1
$zipalignExe = Join-Path -Path $latestBuildTools.FullName -ChildPath "zipalign.exe"

if (-not (Test-Path $zipalignExe)) {
    Write-Error "zipalign.exe not found in $latestBuildTools.FullName. Please check Android SDK Build-Tools installation."
    Stop-Transcript
    exit 1
}

# Zipalign to the final signed APK path
if (Test-Path $signedApkPath) { Remove-Item $signedApkPath -Force } # Ensure zipalign can create the output file
try {
    Invoke-Expression "& `"$zipalignExe`" -v 4 `"$unsignedApkPath`" `"$signedApkPath`"" # unsignedApkPath is now the signed one from jarsigner
    Write-Host "APK aligned successfully: $signedApkPath"
} catch {
    Write-Error "Failed to zipalign APK: $_"
    Stop-Transcript
    exit 1
}

# Final Step: Output
Write-Host "--------------------------------------------------"
Write-Host "Standalone WakeUpCall APK build complete!"
Write-Host "Signed APK ready at: $signedApkPath"
Write-Host "Keystore location: $keystorePath"
Write-Host "--------------------------------------------------"
Write-Host "To install on a connected device/emulator: adb install `"$signedApkPath`""

Stop-Transcript
Write-Host "Build log saved to: $baseDir\build.log"

