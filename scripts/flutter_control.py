#!/usr/bin/env python3
"""
Control a running Flutter app via its VM Service (Dart VM Service Protocol).
Usage:
  python flutter_control.py reload    <- hot reload
  python flutter_control.py restart   <- hot restart (hard reset)
"""
import sys
import json
import asyncio
import pathlib

VM_FILE = pathlib.Path(__file__).parent / ".vm_service_uri"


async def send_command(uri: str, method: str):
    try:
        import websockets
    except ImportError:
        print("Installing websockets...")
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "websockets", "-q"])
        import websockets

    # Convert http:// VM service URI to ws://
    ws_uri = uri.strip().replace("http://", "ws://")
    if not ws_uri.endswith("/ws"):
        ws_uri = ws_uri.rstrip("/") + "/ws"

    print(f"Connecting to {ws_uri} ...")
    async with websockets.connect(ws_uri) as ws:
        # Get the VM to find the isolate ID
        await ws.send(json.dumps({"jsonrpc": "2.0", "id": "1", "method": "getVM", "params": {}}))
        vm_resp = json.loads(await ws.recv())
        isolates = vm_resp["result"]["isolates"]
        if not isolates:
            print("No isolates found.")
            return
        isolate_id = isolates[0]["id"]

        # Send flutter.* extension (web uses flutter extension RPCs)
        ext_method = "ext.flutter.hotRestart" if method == "restart" else "ext.flutter.reassemble"
        payload = {
            "jsonrpc": "2.0",
            "id": "2",
            "method": "callServiceExtension",
            "params": {"isolateId": isolate_id, "method": ext_method},
        }
        await ws.send(json.dumps(payload))
        resp = json.loads(await ws.recv())
        if "error" in resp:
            print(f"Error: {resp['error']}")
        else:
            print(f"Success: {method} triggered.")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("reload", "restart"):
        print("Usage: python flutter_control.py [reload|restart]")
        sys.exit(1)

    if not VM_FILE.exists():
        print(f"VM service file not found: {VM_FILE}")
        print("Make sure the Flutter app is running via scripts/run_web.sh")
        sys.exit(1)

    uri = VM_FILE.read_text().strip()
    if not uri:
        print("VM service URI file is empty. App may still be starting up.")
        sys.exit(1)

    print(f"VM service URI: {uri}")
    asyncio.run(send_command(uri, sys.argv[1]))


if __name__ == "__main__":
    main()
