' Launch AndroGlitch with NO visible console window (self-locating — works from
' any path). Runs start-seclab.ps1 hidden; only the emulator GUI appears, so
' there is no console to accidentally close (which would kill the emulator).
' Progress -> logs\launch.log.
Dim fso, here, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
here = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File """ & here & "\start-seclab.ps1"""
CreateObject("WScript.Shell").Run cmd, 0, False
