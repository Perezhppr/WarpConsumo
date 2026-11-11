#!/bin/bash
# Compila UsoClaudeWarp, lo instala en ~/Applications, copia el status line
# y lo deja arrancando solo al iniciar sesión.
#   ./instalar.sh            compila, instala y abre
#   ./instalar.sh --quitar   lo cierra y quita el arranque automático
set -euo pipefail
cd "$(dirname "$0")"

ID="pe.hugorocha.usoclaudewarp"
APP="$HOME/Applications/UsoClaudeWarp.app"
AGENTE="$HOME/Library/LaunchAgents/$ID.plist"
DATOS="$HOME/.claude/uso-claude"

cerrar() {
  launchctl bootout "gui/$(id -u)/$ID" 2>/dev/null || true
  pkill -x UsoClaudeWarp 2>/dev/null || true
}

if [ "${1:-}" = "--quitar" ]; then
  cerrar
  rm -f "$AGENTE"
  echo "Cerrado y sin arranque automático. La app sigue en $APP y el status line en ~/.claude/settings.json."
  exit 0
fi

./construir.sh

echo "Instalando…"
cerrar
mkdir -p "$HOME/Applications" "$DATOS" "$HOME/Library/LaunchAgents"
rm -rf "$APP"
cp -R build/UsoClaudeWarp.app "$APP"
cp statusline.sh "$DATOS/statusline.sh"
chmod +x "$DATOS/statusline.sh"

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
echo "Listo: UsoClaudeWarp está corriendo."
