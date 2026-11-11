#!/bin/bash
# Compila UsoClaudeWarp, lo instala en ~/Applications, registra el status line
# de Claude Code y lo deja arrancando solo al iniciar sesión.
#   ./instalar.sh            compila, instala y abre
#   ./instalar.sh --quitar   lo cierra y quita el arranque automático
set -euo pipefail
cd "$(dirname "$0")"

ID="pe.hugorocha.usoclaudewarp"
APP="$HOME/Applications/UsoClaudeWarp.app"
AGENTE="$HOME/Library/LaunchAgents/$ID.plist"
DATOS="$HOME/.claude/uso-claude"
AJUSTES="$HOME/.claude/settings.json"
LINEA='~/.claude/uso-claude/statusline.sh'

cerrar() {
  launchctl bootout "gui/$(id -u)/$ID" 2>/dev/null || true
  pkill -x UsoClaudeWarp 2>/dev/null || true
}

# Registra el status line en los ajustes de Claude Code sin pisar uno que ya exista.
registrar_status_line() {
  if [ ! -f "$AJUSTES" ]; then
    mkdir -p "$(dirname "$AJUSTES")"
    jq -n --arg c "$LINEA" '{statusLine: {type: "command", command: $c}}' > "$AJUSTES"
    echo "Status line registrado en $AJUSTES."
    return
  fi
  if ! jq -e 'type == "object"' "$AJUSTES" >/dev/null 2>&1; then
    echo "AVISO: no pude leer $AJUSTES. Agrega a mano el bloque statusLine (ver README)."
    return
  fi
  local actual
  actual=$(jq -r '.statusLine.command // empty' "$AJUSTES")
  if [ "$actual" = "$LINEA" ]; then
    echo "El status line ya estaba registrado."
  elif [ -z "$actual" ]; then
    cp "$AJUSTES" "$AJUSTES.antes-de-warpconsumo"
    jq --arg c "$LINEA" '. + {statusLine: {type: "command", command: $c}}' "$AJUSTES.antes-de-warpconsumo" > "$AJUSTES.tmp"
    mv "$AJUSTES.tmp" "$AJUSTES"
    echo "Status line registrado en $AJUSTES (copia previa: $AJUSTES.antes-de-warpconsumo)."
  else
    echo "AVISO: ya tienes otro status line ($actual) y no lo toqué."
    echo "       Para alimentar el botón, llama a $LINEA desde tu script (ver README)."
  fi
}

if [ "${1:-}" = "--quitar" ]; then
  cerrar
  rm -f "$AGENTE"
  echo "Cerrado y sin arranque automático. La app sigue en $APP y el status line en $AJUSTES."
  exit 0
fi

command -v swiftc >/dev/null || { echo "Falta swiftc. Instala las herramientas de Xcode:  xcode-select --install"; exit 1; }
command -v jq >/dev/null || { echo "Falta jq. Instálalo con:  brew install jq"; exit 1; }

./construir.sh

echo "Instalando…"
cerrar
mkdir -p "$HOME/Applications" "$DATOS" "$HOME/Library/LaunchAgents"
rm -rf "$APP"
cp -R build/UsoClaudeWarp.app "$APP"
cp statusline.sh "$DATOS/statusline.sh"
chmod +x "$DATOS/statusline.sh"
registrar_status_line

cat > "$AGENTE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$ID</string>
	<key>ProgramArguments</key>
	<array>
		<string>$APP/Contents/MacOS/UsoClaudeWarp</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$AGENTE"
echo "Listo: UsoClaudeWarp está corriendo. Envía un mensaje en Claude Code para ver tus números."
