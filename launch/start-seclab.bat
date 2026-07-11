@echo off
REM ============================================================================
REM  Launch the AndroGlitch Android-12 security lab, then auto-start frida-server.
REM
REM  Use THIS (or the desktop shortcut), NOT Android Studio's play button:
REM  the Burp CA, Play Store, and boot animation live in the AVD writable-system
REM  overlay and only mount with  -writable-system  (which the play button omits).
REM
REM  Route through Burp only for interception (Play Store pins certs, so keep it
REM  OFF otherwise):
REM     adb shell settings put global http_proxy 10.0.2.2:8080     (off: ... :0)
REM ============================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-seclab.ps1"
