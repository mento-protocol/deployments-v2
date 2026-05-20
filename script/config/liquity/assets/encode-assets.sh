#!/bin/bash
# One-time script to base64-encode all SVG assets.
# Run this after adding or updating SVG files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

os="$(uname)"
for svg in "${SCRIPT_DIR}"/*.svg; do
    [[ -f "${svg}" ]] || continue
    if [[ "${os}" == "Darwin" ]]; then
        base64 -i "${svg}" | tr -d '\n' > "${svg}.b64"
    else
        base64 -w 0 "${svg}" > "${svg}.b64"
    fi
    name="$(basename "${svg}")"
    echo "Encoded: ${name} -> ${name}.b64"
done
