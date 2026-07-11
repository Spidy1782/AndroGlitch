# Step 4 - inject YOUR Burp/proxy CA into the system trust store so HTTPS is
# intercepted with no TLS warning (Android 12 ignores user-added CAs for most
# apps; a system CA is trusted app-wide).
#
# Provide your CA in assets\  as burp.der (DER) or burp.pem/burp.crt (PEM).
# In Burp: Proxy > Proxy settings > Import/export CA certificate >
#          "Certificate in DER format"  ->  save as assets\burp.der.
. "$PSScriptRoot\..\config.ps1"

$assets = "$SecLabRoot\assets"
$src = @("$assets\burp.der","$assets\burp.pem","$assets\burp.crt","$assets\cacert.der") |
       Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $src) {
    Warn "No CA found. Export your Burp CA (DER) to assets\burp.der, then re-run: .\setup.ps1 -Only 4"
    Warn "Skipping Burp CA install."
    return
}
if (-not $OpenSslDir) { throw "openssl not found (install Git for Windows, or put openssl on PATH)." }
$openssl = "$OpenSslDir\openssl.exe"

# Normalize to PEM, then compute the legacy subject hash Android names the file by.
$pem = "$assets\_burp.pem"
if ($src -like '*.der') { & $openssl x509 -inform DER -in $src -out $pem }
else                    { Copy-Item $src $pem -Force }
$hash = (& $openssl x509 -inform PEM -subject_hash_old -noout -in $pem).Trim()
if (-not $hash) { throw "could not compute subject_hash_old from $src" }
$certFile = "$assets\$hash.0"
Copy-Item $pem $certFile -Force
Ok "CA hashed -> $hash.0"

$serial = Get-SecLabSerial
if (-not $serial) { throw "$AvdName not running - launch it first (launch\start-seclab.bat)." }
& $Adb -s $serial root 2>$null | Out-Null; Start-Sleep 2
& $Adb -s $serial remount 2>$null | Out-Null

& $Adb -s $serial push $certFile /data/local/tmp/$hash.0 | Out-Null
& $Adb -s $serial push "$SecLabRoot\scripts\device\install-burp-ca.sh" /data/local/tmp/ | Out-Null
& $Adb -s $serial shell "su -c 'sh /data/local/tmp/install-burp-ca.sh $hash.0'"
Ok "Burp CA installed. Newly-launched apps trust it (no reboot needed)."
