# ============================================================================
#  config.ps1 - shared configuration + host-toolchain autodetection for SecLab12.
#
#  Dot-sourced by env.ps1, setup.ps1, every scripts/NN-*.ps1 step, and the
#  launcher. Defines paths + helper functions only (no side effects), so it is
#  safe to source repeatedly. NOTHING here is machine-specific: every path is
#  auto-detected or overridable via environment variables, so the repo is
#  portable to any Windows machine with Android Studio + the SDK.
# ============================================================================
# NOTE: deliberately NOT 'Stop'. Native tools (adb, avdmanager, rootAVD) write
# normal status to stderr, and in Windows PowerShell 5.1 'Stop' turns any such
# stderr line into a fatal error (e.g. adb's "su: invalid uid/gid" during the
# not-yet-rooted check aborts step 3). The scripts stop on real failures via
# explicit `throw` + checks instead, which fire regardless of this setting.
$ErrorActionPreference = 'Continue'

# --- Repo root = this file's directory --------------------------------------
$SecLabRoot = $PSScriptRoot

# --- Lab identity (override via env before sourcing to customize) -----------
$AvdName    = if ($env:SECLAB_AVD)          { $env:SECLAB_AVD }          else { 'SecLab12' }
$SdkImage   = if ($env:SECLAB_IMAGE)        { $env:SECLAB_IMAGE }        else { 'system-images;android-31;google_apis;x86_64' }
$DeviceDef  = if ($env:SECLAB_DEVICE)       { $env:SECLAB_DEVICE }       else { 'pixel_5' }
# Play system image to extract the Play Store (Phonesky) APK from. The API-31
# google_apis_playstore image ships a Phonesky guaranteed compatible with our
# Android-12 lab.
$PlayImage  = if ($env:SECLAB_PLAY_IMAGE)   { $env:SECLAB_PLAY_IMAGE }   else { 'system-images;android-31;google_apis_playstore;x86_64' }
$FridaVer   = $env:SECLAB_FRIDA_VERSION   # empty => match host frida client, else fall back to $FridaFallback
$FridaFallback = '17.3.2'

# --- Android SDK ------------------------------------------------------------
function Resolve-Sdk {
    $cands = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME,
               "$env:LOCALAPPDATA\Android\Sdk",
               "$env:USERPROFILE\AppData\Local\Android\Sdk")
    foreach ($c in $cands) {
        if ($c -and (Test-Path "$c\platform-tools\adb.exe")) { return $c }
    }
    throw "Android SDK not found. Install it via Android Studio, or set ANDROID_SDK_ROOT to the folder that contains platform-tools\adb.exe."
}
$Sdk = Resolve-Sdk
$Adb = "$Sdk\platform-tools\adb.exe"
$Emu = "$Sdk\emulator\emulator.exe"

function Resolve-CmdlineTool([string]$name) {
    $cands = @("$Sdk\cmdline-tools\latest\bin\$name.bat",
               "$Sdk\cmdline-tools\bin\$name.bat")
    $cands += (Get-ChildItem "$Sdk\cmdline-tools" -Directory -ErrorAction SilentlyContinue |
               ForEach-Object { "$($_.FullName)\bin\$name.bat" })
    foreach ($c in $cands) { if (Test-Path $c) { return $c } }
    throw "$name not found under $Sdk\cmdline-tools. Install 'Android SDK Command-line Tools (latest)' in Android Studio > SDK Manager > SDK Tools."
}
$Sdkmanager = Resolve-CmdlineTool 'sdkmanager'
$Avdmanager = Resolve-CmdlineTool 'avdmanager'

# --- JDK --------------------------------------------------------------------
function Resolve-Jdk {
    if ($env:JAVA_HOME -and (Test-Path "$env:JAVA_HOME\bin\java.exe")) { return $env:JAVA_HOME }
    # Android Studio bundles a JBR - the safest default.
    $studio = @("$env:LOCALAPPDATA\Programs\Android Studio\jbr",
                "$env:ProgramFiles\Android\Android Studio\jbr")
    foreach ($j in $studio) { if (Test-Path "$j\bin\java.exe") { return $j } }
    $found = Get-ChildItem "$env:ProgramFiles\Java" -Directory -ErrorAction SilentlyContinue |
             Where-Object { Test-Path "$($_.FullName)\bin\java.exe" } |
             Sort-Object Name -Descending | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null   # let the tool's own JAVA_HOME logic try
}
$Jdk = Resolve-Jdk

# --- openssl (needed only for the Burp CA hash; bundled with Git for Windows) --
function Resolve-OpenSslDir {
    $cands = @("$env:ProgramFiles\Git\usr\bin", "${env:ProgramFiles(x86)}\Git\usr\bin")
    foreach ($c in $cands) { if (Test-Path "$c\openssl.exe") { return $c } }
    $g = Get-Command openssl -ErrorAction SilentlyContinue
    if ($g) { return (Split-Path $g.Source) }
    return $null
}
$OpenSslDir = Resolve-OpenSslDir

# --- export the toolchain so child tools (avdmanager/sdkmanager/emulator) see it --
# Every step dot-sources this file, so setting these here makes `setup.ps1` work
# standalone (no need to dot-source env.ps1 first).
$env:ANDROID_SDK_ROOT = $Sdk
$env:ANDROID_HOME      = $Sdk
if ($Jdk) { $env:JAVA_HOME = $Jdk }
# sdkmanager/avdmanager have an over-strict Java-version check that mis-fires on
# JDK 20+ ("Java version 17 or higher is required"). This is Android's official
# override and is harmless on supported JDKs.
$env:SKIP_JDK_VERSION_CHECK = '1'

# --- Helpers ----------------------------------------------------------------
function Get-SecLabSerial {
    # Returns the emulator-XXXX serial whose AVD name is $AvdName, or $null.
    $devs = (& $Adb devices) | Select-String '^(emulator-\d+)\s+device' |
            ForEach-Object { $_.Matches[0].Groups[1].Value }
    foreach ($d in $devs) {
        if ((& $Adb -s $d emu avd name 2>$null | Select-Object -First 1) -eq $AvdName) { return $d }
    }
    return $null
}

function Wait-Boot([string]$Serial, [int]$Retries = 90) {
    for ($i = 0; $i -lt $Retries; $i++) {
        # During a reboot adb returns nothing (null); Out-String makes .Trim() safe.
        $bc = (& $Adb -s $Serial shell getprop sys.boot_completed 2>$null | Out-String).Trim()
        if ($bc -eq '1') { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

function Say([string]$m)  { Write-Host "  $m" -ForegroundColor Cyan }
function Ok([string]$m)   { Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
