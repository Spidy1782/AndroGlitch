@echo off
REM Restart frida-server as root (use after a reboot, or if `frida -U` complains
REM about "jailed Android / need Gadget" — that means it isn't running as root).
set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"
"%ADB%" root
"%ADB%" wait-for-device
"%ADB%" shell chmod 755 /data/local/tmp/frida-server
"%ADB%" shell "su -c 'pkill -f frida-server' 2>/dev/null"
"%ADB%" shell "su -c 'setsid /data/local/tmp/frida-server >/dev/null 2>&1 &'"
echo Waiting for frida-server...
ping -n 4 127.0.0.1 >nul
"%ADB%" shell "ps -A -o USER,PID,NAME | grep frida"
echo.
echo If a 'root ... frida-server' line appears above, you're good: run  frida-ps -U
