// UsoClaudeWarp — botón flotante sobre la barra superior de Warp que muestra
// el uso de Claude (ventana de 5 h y semana) y despliega un panel al pasar el mouse.
// Lee ~/.claude/uso-claude/estado.json, que escribe statusline.sh desde Claude Code.

import AppKit
import SwiftUI

// MARK: - Datos

struct Ventana: Decodable {
    let used_percentage: Double?
    let resets_at: Double?
}

struct Sesion: Decodable {
    let model: String?
    let cost_usd: Double?
    let context_pct: Double?
    let dir: String?
}

struct Estado: Decodable {
    let updated_at: Double?
    let five_hour: Ventana?
    let seven_day: Ventana?
    let limits_updated_at: Double?
    let session: Sesion?
}

final class Uso: ObservableObject {
    @Published var estado: Estado?
    @Published var ahora = Date()

    private let archivo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/uso-claude/estado.json")
    private var ultimaFecha: Date?

    /// `relojFino`: con el panel abierto la hora se refresca en cada llamada; si no, cada 20 s.
    func refrescar(relojFino: Bool = true) {
        if relojFino || Date().timeIntervalSince(ahora) >= 20 { ahora = Date() }
        let fecha = (try? FileManager.default.attributesOfItem(atPath: archivo.path))?[.modificationDate] as? Date
        guard fecha != ultimaFecha else { return }
        ultimaFecha = fecha
        if let datos = try? Data(contentsOf: archivo),
           let nuevo = try? JSONDecoder().decode(Estado.self, from: datos) {
            estado = nuevo
        } else if fecha == nil {
            estado = nil
        }
    }

    /// Porcentaje usado; 0 si la ventana ya se reinició, nil si no hay dato.
    func porcentaje(_ v: Ventana?) -> Double? {
        guard let v, let p = v.used_percentage else { return nil }
        if reiniciada(v) { return 0 }
        return min(max(p, 0), 100)
    }

    func reiniciada(_ v: Ventana?) -> Bool {
        guard let r = v?.resets_at else { return false }
        return Date(timeIntervalSince1970: r) <= ahora
    }
}

// MARK: - Textos

enum Formato {
    private static let local = Locale(identifier: "es_PE")

    private static func fecha(_ plantilla: String, _ d: Date) -> String {
        let f = DateFormatter()
        f.locale = local
        f.setLocalizedDateFormatFromTemplate(plantilla)
        return f.string(from: d)
    }

    static func pct(_ p: Double?) -> String {
        guard let p else { return "—" }
        return "\(Int(p.rounded()))%"
    }

    static func cuando(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "a las \(fecha("hmma", d))" }
        if cal.isDateInTomorrow(d) { return "mañana a las \(fecha("hmma", d))" }
        return "el \(fecha("EEEdMMMhmma", d))"
    }

    static func falta(_ ahora: Date, _ d: Date) -> String {
        let s = Int(d.timeIntervalSince(ahora))
        let dias = s / 86400, horas = (s % 86400) / 3600, min = (s % 3600) / 60
        if dias > 0 { return "en \(dias) d \(horas) h" }
        if horas > 0 { return "en \(horas) h \(min) min" }
        return "en \(max(min, 1)) min"
    }

    static func hace(_ ahora: Date, _ d: Date) -> String {
        let s = Int(ahora.timeIntervalSince(d))
        if s < 60 { return "hace un momento" }
        if s < 3600 { return "hace \(s / 60) min" }
        if s < 86400 { return "hace \(s / 3600) h" }
        return "hace \(s / 86400) d"
    }

    static func dolares(_ v: Double) -> String { String(format: "$%.2f", v) }
}

// MARK: - Estilo

extension Color {
    static let fondoBoton = Color(red: 0.118, green: 0.125, blue: 0.157)
    static let fondoPanel = Color(red: 0.086, green: 0.094, blue: 0.118)
    static let azul = Color(red: 0.27, green: 0.49, blue: 1.0)
    static let ambar = Color(red: 1.0, green: 0.70, blue: 0.20)
    static let rojo = Color(red: 1.0, green: 0.36, blue: 0.36)
    static let tenue = Color.white.opacity(0.55)
}

func colorNivel(_ p: Double?) -> Color {
    guard let p else { return .azul }
    return p >= 90 ? .rojo : (p >= 70 ? .ambar : .azul)
}

struct Rayas: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color.opacity(0.28)))
            var trazo = Path()
            var x = -size.height
            while x < size.width {
                trazo.move(to: CGPoint(x: x, y: size.height))
                trazo.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 5
            }
            ctx.stroke(trazo, with: .color(color), lineWidth: 2)
        }
    }
}

struct Barra: View {
    let fraccion: Double
    let color: Color
    let rayado: Bool

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.09))
                Group {
                    if rayado { Rayas(color: color) } else { color }
                }
                .frame(width: fraccion > 0 ? max(g.size.width * fraccion, 7) : 0)
                .clipShape(Capsule())
            }
        }
        .frame(height: 7)
    }
}

// MARK: - Botón

struct BotonVista: View {
    @ObservedObject var uso: Uso

    var body: some View {
        HStack(spacing: 0) {
            if uso.estado == nil {
                Text("Claude —")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.tenue)
                    .padding(.horizontal, 9)
            } else {
                segmento("5h", uso.porcentaje(uso.estado?.five_hour), principal: true)
                Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1)
                segmento("sem", uso.porcentaje(uso.estado?.seven_day), principal: false)
            }
        }
        .frame(height: 22)
        .background(Color.fondoBoton)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .fixedSize()
    }

    private func segmento(_ etiqueta: String, _ p: Double?, principal: Bool) -> some View {
        let alerta = (p ?? 0) >= 70
        return HStack(spacing: 4) {
            Text(etiqueta)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.tenue)
            Text(Formato.pct(p))
                .font(.system(size: 11.5, weight: .bold))
                .monospacedDigit()
                .foregroundColor(alerta ? colorNivel(p) : .white.opacity(principal ? 1 : 0.72))
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        .background(principal ? Color.white.opacity(0.05) : Color.clear)
    }
}

// MARK: - Panel

struct PanelVista: View {
    @ObservedObject var uso: Uso

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Uso de Claude")
                    .font(.system(size: 12))
                    .foregroundColor(.tenue)
                Spacer()
                if let modelo = uso.estado?.session?.model {
                    Text(modelo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            if let e = uso.estado {
                limite("Sesión de 5 h", e.five_hour, rayado: false)
                limite("Semana", e.seven_day, rayado: true)
                separador
                sesion(e.session)
                separador
                Text(pie(e))
                    .font(.system(size: 11).italic())
                    .foregroundColor(.tenue)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Todavía no hay datos. Envía un mensaje en Claude Code y aparecerán aquí.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
        .background(Color.fondoPanel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var separador: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
    }

    private func limite(_ titulo: String, _ v: Ventana?, rayado: Bool) -> some View {
        let p = uso.porcentaje(v)
        let color = colorNivel(p)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Group {
                    if rayado { Rayas(color: color) } else { color }
                }
                .frame(width: 11, height: 11)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                Text(titulo)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(Formato.pct(p))
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor((p ?? 0) >= 70 ? color : .white)
            }
            Barra(fraccion: (p ?? 0) / 100, color: color, rayado: rayado)
            Text(detalle(v))
                .font(.system(size: 11.5))
                .foregroundColor(.tenue)
        }
    }

    private func detalle(_ v: Ventana?) -> String {
        guard let v, v.used_percentage != nil else { return "Sin datos todavía" }
        if uso.reiniciada(v) { return "Ya se reinició: sin uso en la ventana nueva" }
        guard let r = v.resets_at else { return "Usado en esta ventana" }
        let d = Date(timeIntervalSince1970: r)
        return "Se reinicia \(Formato.cuando(d)) · \(Formato.falta(uso.ahora, d))"
    }

    private func sesion(_ s: Sesion?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Última sesión de Claude Code")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            fila("Carpeta", s?.dir.flatMap { $0.isEmpty ? nil : $0 } ?? "—")
            fila("Contexto usado", Formato.pct(s?.context_pct))
            fila("Costo equivalente (API)", s?.cost_usd.map(Formato.dolares) ?? "—")
        }
    }

    private func fila(_ nombre: String, _ valor: String) -> some View {
        HStack(spacing: 8) {
            Circle().strokeBorder(Color.azul, lineWidth: 1.5).frame(width: 7, height: 7)
            Text(nombre)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(valor)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
        }
    }

    private func pie(_ e: Estado) -> String {
        let marca = e.limits_updated_at ?? e.updated_at
        let cuando = marca.map { Formato.hace(uso.ahora, Date(timeIntervalSince1970: $0)) } ?? "sin fecha"
        return "Actualizado \(cuando). Clic para fijar el panel, clic derecho para salir."
    }
}

// MARK: - Vista contenedora (hover y clics aunque la app no esté activa)

final class Contenedor: NSView {
    var alEntrar: (() -> Void)?
    var alSalir: (() -> Void)?
    var alClic: (() -> Void)?
    var alClicDerecho: ((NSEvent) -> Void)?

    private let anfitrion: NSView
    private var area: NSTrackingArea?

    init<V: View>(_ vista: V) {
        anfitrion = NSHostingView(rootView: vista)
        super.init(frame: .zero)
        anfitrion.autoresizingMask = [.width, .height]
        addSubview(anfitrion)
    }

    required init?(coder: NSCoder) { fatalError("no se usa") }

    var tamano: NSSize { anfitrion.fittingSize }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let nueva = NSTrackingArea(rect: .zero,
                                   options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                   owner: self, userInfo: nil)
        addTrackingArea(nueva)
        area = nueva
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { alEntrar?() }
    override func mouseExited(with event: NSEvent) { alSalir?() }
    override func mouseDown(with event: NSEvent) { alClic?() }
    override func rightMouseDown(with event: NSEvent) { alClicDerecho?(event) }
}

// MARK: - Controlador

final class Controlador: NSObject, NSApplicationDelegate {
    private let uso = Uso()
    private var boton: NSPanel!
    private var panel: NSPanel!
    private var botonVista: Contenedor!
    private var panelVista: Contenedor!

    private var warp: NSRunningApplication?
    private var seguimiento: Timer?
    private var monitor: Any?
    private var ventanaID: CGWindowID?
    private var marco = CGRect.null
    private var quieto = 0
    private var ultimaBusqueda: TimeInterval = 0
    private var ultimoArrastre: TimeInterval = 0

    private var cierre: Timer?
    private var fijado = false
    private var encima = false
    private var botonVisible = false
    private var panelVisible = false

    // Ritmo de revisión de la ventana de Warp: rápido mientras se mueve, lento cuando está quieta.
    private let rapido: TimeInterval = 1.0 / 30.0
    private let lento: TimeInterval = 0.25

    // Posición del botón respecto a la esquina superior derecha de la ventana de Warp.
    // Se puede ajustar con: defaults write pe.hugorocha.usoclaudewarp derecha -float 100
    private var derecha: CGFloat { ajuste("derecha", 96) }
    private var arriba: CGFloat { ajuste("arriba", 7) }

    private func ajuste(_ clave: String, _ porDefecto: CGFloat) -> CGFloat {
        UserDefaults.standard.object(forKey: clave) == nil ? porDefecto : CGFloat(UserDefaults.standard.double(forKey: clave))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        botonVista = Contenedor(BotonVista(uso: uso))
        panelVista = Contenedor(PanelVista(uso: uso))
        boton = crearPanel(botonVista, sombra: false)
        panel = crearPanel(panelVista, sombra: true)

        for vista in [botonVista!, panelVista!] {
            vista.alEntrar = { [weak self] in self?.actualizarHover() }
            vista.alSalir = { [weak self] in self?.actualizarHover() }
        }
        botonVista.alClic = { [weak self] in self?.alternarFijado() }
        botonVista.alClicDerecho = { [weak self] evento in self?.menu(evento) }

        uso.refrescar()
        let datos = Timer(timeInterval: 2, target: self, selector: #selector(refrescarDatos), userInfo: nil, repeats: true)
        RunLoop.main.add(datos, forMode: .common)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(cambioDeApp(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        evaluar(NSWorkspace.shared.frontmostApplication)
    }

    private func crearPanel(_ contenido: NSView, sombra: Bool) -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = sombra
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.contentView = contenido
        p.alphaValue = 0
        return p
    }

    // MARK: Seguimiento de Warp

    @objc private func cambioDeApp(_ n: Notification) {
        evaluar(n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
    }

    private func evaluar(_ app: NSRunningApplication?) {
        guard let app else { detener(); return }
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return }
        if app.bundleIdentifier?.hasPrefix("dev.warp.") == true {
            warp = app
            iniciar()
        } else {
            detener()
        }
    }

    private func iniciar() {
        guard seguimiento == nil else { return }
        ventanaID = nil
        marco = .null
        quieto = 0
        ultimaBusqueda = 0
        ritmo(rapido)
        // Mientras Warp está al frente: el movimiento del mouse decide el hover y
        // un arrastre obliga a revisar al instante si la ventana se movió.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] evento in
            guard let self else { return }
            if evento.type == .mouseMoved {
                self.actualizarHover()
            } else if evento.timestamp - self.ultimoArrastre > 0.03 {
                self.ultimoArrastre = evento.timestamp
                self.revisar()
            }
        }
    }

    private func detener() {
        seguimiento?.invalidate()
        seguimiento = nil
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        esconderTodo()
    }

    private func ritmo(_ intervalo: TimeInterval) {
        if let s = seguimiento, s.isValid, s.timeInterval == intervalo { return }
        seguimiento?.invalidate()
        let t = Timer(timeInterval: intervalo, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        t.tolerance = intervalo * 0.2
        RunLoop.main.add(t, forMode: .common)
        seguimiento = t
    }

    @objc private func tick() { revisar() }

    private func revisar() {
        guard let warp, !warp.isTerminated else { detener(); return }
        // La ventana frontal se vuelve a buscar como mucho dos veces por segundo.
        let ahora = ProcessInfo.processInfo.systemUptime
        if ahora - ultimaBusqueda > 0.5 {
            ultimaBusqueda = ahora
            ventanaID = Self.ventanaFrontal(pid: warp.processIdentifier)
        }
        guard let id = ventanaID, let actual = Self.marco(de: id) else {
            ventanaID = nil
            marco = .null
            esconderTodo()
            ritmo(lento)
            return
        }
        if actual != marco {
            // Warp se está moviendo o cambió de ventana: se esconde y reaparece al quedar quieto.
            marco = actual
            quieto = 0
            esconderTodo()
            ritmo(rapido)
            return
        }
        quieto += 1
        if quieto == 3 {
            mostrarBoton()
            ritmo(lento)
        }
        actualizarHover()
    }

    private static func ventanaFrontal(pid: pid_t) -> CGWindowID? {
        guard let lista = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        for v in lista {
            guard (v[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (v[kCGWindowLayer as String] as? Int) == 0,
                  let limites = v[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: limites),
                  r.width >= 400, r.height >= 200,
                  let id = v[kCGWindowNumber as String] as? UInt32 else { continue }
            return id
        }
        return nil
    }

    private static func marco(de id: CGWindowID) -> CGRect? {
        guard let lista = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let v = lista.first,
              (v[kCGWindowIsOnscreen as String] as? Bool) == true,
              let limites = v[kCGWindowBounds as String] as? NSDictionary,
              let r = CGRect(dictionaryRepresentation: limites) else { return nil }
        return r
    }

    // MARK: Botón

    /// Marco del botón en coordenadas de AppKit (origen abajo a la izquierda de la pantalla principal).
    private func marcoBoton() -> NSRect? {
        guard !marco.isNull, let principal = NSScreen.screens.first else { return nil }
        let t = botonVista.tamano
        let x = marco.maxX - derecha - t.width
        let y = principal.frame.height - (marco.minY + arriba) - t.height
        return NSRect(x: x.rounded(), y: y.rounded(), width: ceil(t.width), height: ceil(t.height))
    }

    private func mostrarBoton() {
        guard let m = marcoBoton() else { return }
        boton.setFrame(m, display: true)
        boton.orderFrontRegardless()
        botonVisible = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            boton.animator().alphaValue = 1
        }
    }

    private func esconderTodo() {
        cierre?.invalidate()
        fijado = false
        encima = false
        if panelVisible { panel.orderOut(nil); panel.alphaValue = 0; panelVisible = false }
        if botonVisible { boton.orderOut(nil); boton.alphaValue = 0; botonVisible = false }
    }

    @objc private func refrescarDatos() {
        uso.refrescar(relojFino: panelVisible)
        // El texto pudo cambiar de ancho: se recoloca lo que esté a la vista.
        if botonVisible, let m = marcoBoton(), m != boton.frame { boton.setFrame(m, display: true) }
        if panelVisible { colocarPanel() }
    }

    // MARK: Panel

    private func colocarPanel() {
        let t = panelVista.tamano
        let b = boton.frame
        var x = b.maxX - t.width
        var y = b.minY - 6 - t.height
        if let pantalla = boton.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            x = min(max(x, pantalla.minX + 8), pantalla.maxX - t.width - 8)
            y = max(y, pantalla.minY + 8)
        }
        panel.setFrame(NSRect(x: x.rounded(), y: y.rounded(), width: ceil(t.width), height: ceil(t.height)), display: true)
    }

    /// Decide por la posición real del cursor si está sobre el botón o el panel.
    /// Lo llaman el monitor de movimiento, las áreas de seguimiento y el tick, así
    /// el panel se cierra aunque se pierda algún evento de salida.
    private func actualizarHover() {
        guard botonVisible else { return }
        let p = NSEvent.mouseLocation
        let b = boton.frame
        var dentro = b.insetBy(dx: -2, dy: -2).contains(p)
        if !dentro, panelVisible {
            let f = panel.frame
            let hueco = NSRect(x: b.minX, y: f.maxY, width: b.width, height: max(b.minY - f.maxY, 0))
            dentro = f.contains(p) || hueco.contains(p)
        }
        guard dentro != encima else { return }
        encima = dentro
        if dentro { entrar() } else { salir() }
    }

    private func entrar() {
        cierre?.invalidate()
        guard botonVisible, !panelVisible else { return }
        uso.refrescar()
        colocarPanel()
        panel.orderFrontRegardless()
        panelVisible = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    private func salir() {
        guard !fijado else { return }
        cierre?.invalidate()
        cierre = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(cerrarPanel),
                                      userInfo: nil, repeats: false)
    }

    @objc private func cerrarPanel() {
        guard panelVisible else { return }
        panelVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.10
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.panelVisible else { return }
            self.panel.orderOut(nil)
        })
    }

    private func alternarFijado() {
        fijado.toggle()
        if fijado { entrar() } else if !encima { salir() }
    }

    private func menu(_ evento: NSEvent) {
        let m = NSMenu()
        let salirItem = NSMenuItem(title: "Salir de Uso Claude", action: #selector(salirDeLaApp), keyEquivalent: "")
        salirItem.target = self
        m.addItem(salirItem)
        NSMenu.popUpContextMenu(m, with: evento, for: botonVista)
    }

    @objc private func salirDeLaApp() { NSApp.terminate(nil) }
}

// MARK: - Arranque

let propio = Bundle.main.bundleIdentifier ?? "pe.hugorocha.usoclaudewarp"
if NSRunningApplication.runningApplications(withBundleIdentifier: propio).count > 1 { exit(0) }

let app = NSApplication.shared
let controlador = Controlador()
app.delegate = controlador
app.setActivationPolicy(.accessory)
app.run()
