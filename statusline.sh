#!/bin/bash
# Status line de Claude Code para UsoClaudeWarp.
# Recibe por stdin el JSON de la sesión, guarda el uso (ventana de 5 h y semana)
# en ~/.claude/uso-claude/estado.json para el botón de Warp, e imprime una línea corta.

input=$(cat)
DIR="$HOME/.claude/uso-claude"
FILE="$DIR/estado.json"
JQ=$(command -v jq || echo /opt/homebrew/bin/jq)
[ -x "$JQ" ] || exit 0
mkdir -p "$DIR"

# Lo último guardado: una sesión recién abierta todavía no trae límites y no debe borrarlos.
prev=$("$JQ" -c . "$FILE" 2>/dev/null) || prev='{}'
[ -n "$prev" ] || prev='{}'

tmp=$(mktemp "$DIR/.estado.XXXXXX") || exit 0
if printf '%s' "$input" | "$JQ" --argjson prev "$prev" --argjson now "$(date +%s)" '
  . as $in
  | ($in.rate_limits // {}) as $rl
  | {
      updated_at: $now,
      five_hour: ($rl.five_hour // $prev.five_hour),
      seven_day: ($rl.seven_day // $prev.seven_day),
      limits_updated_at: (if ($rl.five_hour or $rl.seven_day) then $now else $prev.limits_updated_at end),
      session: {
        model: ($in.model.display_name // null),
        cost_usd: ($in.cost.total_cost_usd // null),
        context_pct: ($in.context_window.used_percentage // null),
        dir: (($in.workspace.current_dir // $in.cwd // "") | split("/") | last)
      }
    }' > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
  mv -f "$tmp" "$FILE"
else
  rm -f "$tmp"
fi

# Línea que se ve dentro de Claude Code.
printf '%s' "$input" | "$JQ" -r '
  def pct: if . == null then empty else "\(. | round)%" end;
  [ (.model.display_name // empty),
    (.rate_limits.five_hour.used_percentage | pct | "5h \(.)"),
    (.rate_limits.seven_day.used_percentage | pct | "sem \(.)"),
    (.context_window.used_percentage | pct | "ctx \(.)")
  ] | join(" · ")' 2>/dev/null

exit 0
