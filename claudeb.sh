#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVA_SH="$SCRIPT_DIR/deva.sh"

echo "[claudeb.sh] Deprecated: use deva.sh --auth-with bedrock ..." >&2
exec "$DEVA_SH" --auth-with bedrock "$@"
