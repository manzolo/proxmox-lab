#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"${SCRIPT_DIR}/bin/proxmox-lab" --set USE_TAP_NETWORK=1 vm stop
"${SCRIPT_DIR}/bin/proxmox-lab" --set USE_TAP_NETWORK=1 network down
exec "${SCRIPT_DIR}/bin/proxmox-lab" --set USE_TAP_NETWORK=1 clean all "$@"
