# assets/

Drop your **local, private** inputs here. Nothing in this folder is committed
(see `.gitignore`) — the files are either machine-specific secrets or large
binaries that `setup.ps1` downloads/generates.

| File | Used by | How to get it |
|---|---|---|
| `burp.der` | step 4 (Burp CA) | Burp → Proxy → Proxy settings → Import/export CA certificate → **Certificate in DER format** → save here as `burp.der`. (Any HTTPS proxy CA works — save its DER/PEM as `burp.der`/`burp.pem`.) |
| `boot.png` | step 6 (boot animation, optional) | Any logo PNG. Or a folder `boot-frames/` of numbered frames (`0001.png`, `0002.png`, …). Skipped if absent. |
| `playstore.apk` | step 5 (optional) | Leave empty — step 5 **extracts** it from a Google Play system image automatically. Only drop your own here if you want a specific version. |
| `frida-server` | step 7 (auto) | Leave empty — step 7 downloads the version matching your host `frida` client. |

Generated here at setup (all git-ignored): `<hash>.0`, `bootanimation.zip`,
`frida-server`, `frida-server-*.xz`.
