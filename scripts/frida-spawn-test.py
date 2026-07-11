import frida, sys
try:
    dev = frida.get_usb_device(timeout=5)
    pid = dev.spawn(["com.android.settings"])
    print(f"spawned pid={pid}")
    dev.resume(pid)
    import time; time.sleep(1)
    dev.kill(pid)
    print("SPAWN_OK (rooted frida-server injection works)")
except Exception as e:
    print(f"SPAWN_FAIL: {type(e).__name__}: {e}")
    sys.exit(1)
