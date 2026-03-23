#!/usr/bin/env bash
# Run Flutter app on web and save VM service URI for remote control
FLUTTER=/c/Users/LTC/flutter/bin/flutter
PROJECT=/c/Users/LTC/Syanat
VM_FILE="$PROJECT/scripts/.vm_service_uri"

cd "$PROJECT"
echo "Starting Flutter web on http://localhost:8080 ..."
echo "VM service URI will be saved to: $VM_FILE"
echo ""
echo "From another terminal, run:"
echo "  ./scripts/reload.sh     <- hot reload"
echo "  ./scripts/restart.sh    <- hard restart"
echo ""

"$FLUTTER" run -d web-server \
  --web-port 8080 \
  --vmservice-out-file "$VM_FILE"
