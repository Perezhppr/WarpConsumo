# WarpConsumo — botón en la barra de Warp con el uso de Claude

## Qué es
Herramienta personal de Hugo (no es de un cliente). Dibuja un botón pequeño sobre la barra superior de Warp, a la izquierda del ícono «±», con el uso de Claude: ventana de 5 h y semana. Al pasar el mouse despliega un panel con el detalle (porcentajes, cuándo se reinicia cada límite y datos de la última sesión de Claude Code).

- Stack: Swift (AppKit + SwiftUI) en un solo archivo, compilado con `swiftc`, sin Xcode project. Un script de bash con `jq` para capturar los datos.
- Carpeta: `~/Desktop/Proyectos/WarpConsumo`. La app, su identificador (`pe.hugorocha.usoclaudewarp`) y la carpeta de datos (`~/.claude/uso-claude/`) conservan el nombre original «UsoClaudeWarp».
- Repo: `Perezhppr/WarpConsumo` (privado), rama `main`.
- No se publica en ningún lado: corre en la Mac de Hugo.

## Estado actual (2026-11-10)
- Funciona: el botón aparece sobre Warp, muestra los datos reales de la cuenta y abre el panel al pasar el mouse. Se esconde cuando Warp no es la app al frente. Uso de CPU en reposo: ~0.3 %.
- Corre desde `build/UsoClaudeWarp.app` (abierta a mano con `./construir.sh --abrir`). **No arranca sola al iniciar sesión**: falta que Hugo corra `./instalar.sh`.
- El status line de Claude Code está activado en `~/.claude/settings.json` y apunta a `~/.claude/uso-claude/statusline.sh`.
- Sin verificar: que el panel se cierre solo al sacar el mouse. En la primera prueba no se cerró; se reescribió esa lógica (ahora decide por la posición real del cursor) pero no se pudo repetir la prueba porque Hugo estaba en otra app.

## Decisiones y porqués
- **Ventana flotante y no un botón dentro de Warp**: Warp no tiene API de plugins ni forma de agregar botones a su barra. La app sigue la ventana de Warp con `CGWindowListCopyWindowInfo` (no pide permisos de Accesibilidad ni de Grabación de pantalla) y coloca un `NSPanel` sin borde encima.
- **Datos desde el status line de Claude Code**: es la vía documentada para leer `rate_limits.five_hour` y `rate_limits.seven_day`. No se usa el token de la cuenta ni endpoints no documentados. Consecuencia: los números solo se actualizan cuando Claude Code responde algo; lo usado en claude.ai o en la app de escritorio aparece recién en la siguiente respuesta de Claude Code.
- **El script no borra límites**: una sesión recién abierta todavía no trae `rate_limits`, así que se conserva el último valor guardado. La app muestra 0 % cuando ya pasó la hora de reinicio.
- **Se esconde mientras Warp se mueve** y reaparece al quedar quieta, en vez de seguirla con retraso.
- **Hover por posición del cursor** (monitor global de movimiento + tick), no solo por áreas de seguimiento: las áreas perdían el evento de salida.
- **Ritmo adaptativo**: revisa la ventana 30 veces por segundo solo mientras se mueve y 4 por segundo en reposo. Con 30 fijas gastaba ~5 % de CPU.
- **«Costo equivalente (API)»**: es el estimado que da Claude Code a precio de lista, no un cobro real de la suscripción.
- **Arranque automático pendiente**: el modo automático de Claude Code bloqueó instalar el LaunchAgent, así que lo corre Hugo.

## Cómo trabajar aquí
- `./construir.sh` compila en `build/`. `./construir.sh --abrir` además cierra la copia que esté corriendo y abre la nueva.
- `./instalar.sh` compila, copia la app a `~/Applications`, copia `statusline.sh` a `~/.claude/uso-claude/` y registra el LaunchAgent `pe.hugorocha.usoclaudewarp` para que arranque al iniciar sesión. `./instalar.sh --quitar` lo cierra y quita el arranque.
- Si se edita `statusline.sh`, hay que volver a copiarlo a `~/.claude/uso-claude/` (lo hace `instalar.sh`).
- Archivos: `app/main.swift` (toda la app), `app/Info.plist`, `statusline.sh`.
- Datos: `~/.claude/uso-claude/estado.json` (lo escribe el status line, lo lee la app cada 2 s).
- Posición del botón: `defaults write pe.hugorocha.usoclaudewarp derecha -float 96` (distancia al borde derecho de la ventana) y `arriba -float 7`; reiniciar la app después.
- Salir de la app: clic derecho sobre el botón › «Salir de Uso Claude».
- Cuidado: la posición está calculada para la barra actual de Warp (versión 0.2026.10.21). Si Warp cambia su barra, hay que reajustar `derecha` y `arriba`.

## Pendiente
- Correr `./instalar.sh` para que arranque sola al iniciar sesión (Hugo).
- Confirmar que el panel se cierra al sacar el mouse (Hugo; si falla, Claude lo revisa).

## Registro
- 2026-11-10: Hugo pidió un botón en Warp para ver su uso al pasar el mouse, con un panel tipo saldo. Se creó el proyecto, el status line y la app. Costó: Warp no admite botones propios (se resolvió con una ventana flotante), el panel no se cerraba al salir (se cambió a hover por posición del cursor) y la primera versión gastaba ~5 % de CPU (se bajó a ~0.3 % con ritmo adaptativo). El arranque automático quedó para Hugo porque el modo automático bloqueó el LaunchAgent.
- 2026-11-10: Hugo pidió guardar todo en la carpeta `WarpConsumo` (creada por él dentro de Proyectos) y subir el código a GitHub. Se movió el proyecto desde `UsoClaudeWarp`, se reabrió la app desde la nueva ruta y se subió al repo privado `Perezhppr/WarpConsumo`.
