#!/bin/bash
# Status line de Claude Code para UsoClaudeWarp.
# Recibe por stdin el JSON de la sesión, guarda el uso (ventana de 5 h y semana)
# en ~/.claude/uso-claude/estado.json para el botón de Warp, e imprime una línea corta.
#
# Cada sesión de Claude Code trae la "foto" del uso de su última respuesta, y vuelve a
# enviarla cada vez que su status line se redibuja (por ejemplo al cambiar de pestaña).
# Con varias sesiones abiertas, una sesión inactiva traería una foto vieja. Por eso
# los límites se fusionan en vez de pisarse:
#   - si los números de ESTA sesión cambiaron desde su último aviso, acaba de responder:
#     es el dato más nuevo y se acepta (aunque sea menor);
#   - si no cambiaron, es solo un redibujo: no aporta nada y se ignora;
#   - si la sesión es desconocida (primera vez que avisa), solo se acepta si es de una
#     ventana más nueva o si, en la misma ventana, el porcentaje es mayor o igual.

input=$(cat)
DIR="$HOME/.claude/uso-claude"
FILE="$DIR/estado.json"
JQ=$(command -v jq || echo /opt/homebrew/bin/jq)
[ -x "$JQ" ] || exit 0
mkdir -p "$DIR"

prev=$("$JQ" -c . "$FILE" 2>/dev/null) || prev='{}'
[ -n "$prev" ] || prev='{}'
now=$(date +%s)

nuevo=$(printf '%s' "$input" | "$JQ" -c --argjson prev "$prev" --argjson now "$now" '
  def valido: type == "object" and .used_percentage != null;
  def cambio($n; $a):
    ($n | valido) and ($a | valido)
    and ($n.used_percentage != $a.used_percentage or $n.resets_at != $a.resets_at);
  def fusion($n; $v; $a):
    if ($n | valido | not) then $v
    elif ($v | valido | not) then $n
    elif cambio($n; $a) then $n
    elif ($a | valido) then $v
    elif ($n.resets_at != null and $v.resets_at != null and $n.resets_at > $v.resets_at + 60) then $n
    elif ($n.resets_at != null and $v.resets_at != null and $n.resets_at < $v.resets_at - 60) then $v
    elif $n.used_percentage >= $v.used_percentage then $n
    else $v end;

  . as $in
  | ($in.rate_limits // {}) as $rl
  | ($in.session_id // "") as $sid
  | ($prev.sesiones // {}) as $ses
  | ($ses[$sid] // {}) as $antes
  | fusion($rl.five_hour; $prev.five_hour; $antes.five_hour) as $h5
  | fusion($rl.seven_day; $prev.seven_day; $antes.seven_day) as $d7
  | ((($rl.five_hour | valido) and $h5 == $rl.five_hour)
     or (($rl.seven_day | valido) and $d7 == $rl.seven_day)) as $vigente
  | {
      updated_at: $now,
      five_hour: $h5,
      seven_day: $d7,
      limits_updated_at: (if $vigente then $now else $prev.limits_updated_at end),
      session: {
        model: ($in.model.display_name // null),
        cost_usd: ($in.cost.total_cost_usd // null),
        context_pct: ($in.context_window.used_percentage // null),
        dir: (($in.workspace.current_dir // $in.cwd // "") | split("/") | last)
      },
      sesiones: (
        ($ses | with_entries(select((.value.visto // 0) > $now - 691200)))
        + (if $sid != "" and (($rl.five_hour | valido) or ($rl.seven_day | valido))
           then {($sid): {
                  five_hour: ($rl.five_hour // $antes.five_hour),
                  seven_day: ($rl.seven_day // $antes.seven_day),
                  visto: $now }}
           else {} end)
      )
    }' 2>/dev/null)

if [ -n "$nuevo" ]; then
  tmp=$(mktemp "$DIR/.estado.XXXXXX") && printf '%s\n' "$nuevo" > "$tmp" && mv -f "$tmp" "$FILE"
else
  nuevo="$prev"
fi

# Línea que se ve dentro de Claude Code: usa los límites ya fusionados, así todas
# las sesiones muestran el mismo número que el botón.
printf '%s' "$input" | "$JQ" -r --argjson e "$nuevo" --argjson now "$now" '
  def pct: if . == null then empty else "\(. | round)%" end;
  def usado: if type != "object" or .used_percentage == null then null
             elif .resets_at != null and .resets_at <= $now then 0
             else .used_percentage end;
  [ (.model.display_name // empty),
    ($e.five_hour | usado | pct | "5h \(.)"),
    ($e.seven_day | usado | pct | "sem \(.)"),
    (.context_window.used_percentage | pct | "ctx \(.)")
  ] | join(" · ")' 2>/dev/null

exit 0
