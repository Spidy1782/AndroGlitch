# Step 7 - stage frida-server on the device (matched to your host frida client).
#
# The server major/minor MUST match your host `frida` client, or injection
# fails. We read the host client version, download the matching
# frida-server-<ver>-android-x86_64.xz from GitHub, decompress it, and push it.
# The launcher (start-seclab.ps1) starts it as root on every boot.
. "$PSScriptRoot\..\config.ps1"

# --- pick a version ---------------------------------------------------------
$ver = $FridaVer
if (-not $ver) {
    try { $ver = (& python -c "import frida,sys;sys.stdout.write(frida.__version__)" 2>$null).Trim() } catch {}
}
if (-not $ver) {
    $ver = $FridaFallback
    Warn "host frida client not detected; using $ver. Install matching client: pip install frida-tools==$ver"
} else { Ok "matching host frida client version $ver" }

$assets = "$SecLabRoot\assets"
$bin = "$assets\frida-server"
if (-not (Test-Path $bin)) {
    $xz = "$assets\frida-server-$ver-android-x86_64.xz"
    if (-not (Test-Path $xz)) {
        $url = "https://github.com/frida/frida/releases/download/$ver/frida-server-$ver-android-x86_64.xz"
        Say "downloading $url ..."
        Invoke-WebRequest -Uri $url -OutFile $xz
    }
    Say "decompressing..."
    & python -c "import lzma,shutil;shutil.copyfileobj(lzma.open(r'$xz'),open(r'$bin','wb'))"
    if (-not (Test-Path $bin)) { throw "failed to decompress frida-server" }
}
Ok "frida-server binary ready ($([math]::Round((Get-Item $bin).Length/1MB)) MB)"

$serial = Get-SecLabSerial
if (-not $serial) { Warn "$AvdName not running - it will be pushed on next launch by start-seclab.ps1."; return }
& $Adb -s $serial root 2>$null | Out-Null; Start-Sleep 2
& $Adb -s $serial push $bin /data/local/tmp/frida-server | Out-Null
& $Adb -s $serial shell chmod 755 /data/local/tmp/frida-server
& $Adb -s $serial shell "su -c 'pkill -f frida-server' 2>/dev/null"
& $Adb -s $serial shell "su -c 'setsid /data/local/tmp/frida-server >/dev/null 2>&1 &'"
Start-Sleep 3
$p = (& $Adb -s $serial shell "ps -A -o USER,PID,NAME | grep frida").Trim()
if ($p) { Ok "frida-server running: $p" } else { Warn "frida-server not confirmed; run launch\restart-frida.bat" }
