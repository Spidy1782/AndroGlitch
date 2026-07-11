# ============================================================================
#  env.ps1 - dot-source at the start of a session to load the toolchain.
#     . .\env.ps1
#  Sets ANDROID_SDK_ROOT / JAVA_HOME, prepends SDK tool dirs + openssl to PATH,
#  works around the sdkmanager JDK-version-check bug (SKIP_JDK_VERSION_CHECK),
#  and pins ANDROID_SERIAL to the running AndroGlitch (SecLab12) emulator so adb
#  is unambiguous even if another AVD is running.
# ============================================================================
. "$PSScriptRoot\config.ps1"

$env:ANDROID_SDK_ROOT       = $Sdk
$env:ANDROID_HOME           = $Sdk
if ($Jdk) { $env:JAVA_HOME  = $Jdk }
$env:SKIP_JDK_VERSION_CHECK = '1'
$env:Path = "$Sdk\platform-tools;$Sdk\emulator;$(Split-Path $Sdkmanager);$env:JAVA_HOME\bin;$env:Path"
if ($OpenSslDir) { $env:Path = "$OpenSslDir;$env:Path" }

Remove-Item Env:\ANDROID_SERIAL -ErrorAction SilentlyContinue
$serial = Get-SecLabSerial
if ($serial) {
    $env:ANDROID_SERIAL = $serial
    Write-Host "ANDROID_SERIAL pinned to $AvdName = $serial" -ForegroundColor Green
} else {
    Write-Host "$AvdName emulator not running (ANDROID_SERIAL unset). Launch it with launch\start-seclab.bat." -ForegroundColor Yellow
}
Write-Host "AndroGlitch env ready: SDK=$Sdk  JAVA_HOME=$env:JAVA_HOME" -ForegroundColor Cyan
