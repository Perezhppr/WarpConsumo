#!/bin/bash
# Compila UsoClaudeWarp en build/UsoClaudeWarp.app (no instala nada).
#   ./construir.sh           solo compila
#   ./construir.sh --abrir   compila, cierra la copia que esté corriendo y abre la nueva
set -euo pipefail
cd "$(dirname "$0")"

APP="build/UsoClaudeWarp.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/UsoClaudeWarp" app/main.swift
cp app/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Compilado: $APP"

if [ "${1:-}" = "--abrir" ]; then
  pkill -x UsoClaudeWarp 2>/dev/null || true
  sleep 0.5
  open "$APP"
  echo "Abierto."
fi
