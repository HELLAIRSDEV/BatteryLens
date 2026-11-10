import Cocoa
import IOKit

// MARK: - Battery reading
//
// Данные берутся из IORegistry (AppleSmartBattery). Ключи отличаются между
// Apple Silicon и Intel: на Apple Silicon сырые ёмкости лежат в словаре
// BatteryData, на Intel — в корне сервиса, а CurrentCapacity/MaxCapacity
// означают миллиампер-часы, а не проценты. Ниже — единый разбор для обоих.

struct BatteryInfo {
    var percent: Int = 0
    var designCapacity: Int = 0
    var fullCapacity: Int = 0
    var cycles: Int = 0
    var remaining: Int = 0
    var voltage: Double = 0        // V
    var amperage: Double = 0       // A (signed)
    var isCharging: Bool = false
    var isPlugged: Bool = false
    var minutesLeft: Int = -1

    var health: Double {
        designCapacity > 0 ? Double(fullCapacity) / Double(designCapacity) * 100 : 0
    }

    var watts: Double {
        abs(voltage * amperage)
    }

    var verdict: String {
        if health >= 85 { return "Батарея в хорошем состоянии" }
        if health >= 80 { return "Износ заметный, но работать можно" }
        if health >= 70 { return "Пора планировать замену" }
        return "Батарею нужно менять"
    }
}

func signed64(_ n: Double) -> Double {
    // IORegistry хранит отрицательные значения как UInt64
    n > 9.2e18 ? n - 1.8446744073709552e19 : n
}

func readBattery() -> BatteryInfo? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }

    func raw(_ key: String) -> Any? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return value.takeRetainedValue()
    }
    func int(_ key: String) -> Int? {
        (raw(key) as? NSNumber)?.intValue
    }
    func dbl(_ key: String) -> Double? {
        (raw(key) as? NSNumber)?.doubleValue
    }
    func dictInt(_ dict: [String: Any], _ key: String) -> Int? {
        (dict[key] as? NSNumber)?.intValue
    }

    guard (raw("BatteryInstalled") as? Bool) ?? true else { return nil }

    let data = raw("BatteryData") as? [String: Any] ?? [:]

    var info = BatteryInfo()

    // Ёмкости: сначала BatteryData (Apple Silicon), затем корень (Intel).
    info.designCapacity = dictInt(data, "DesignCapacity") ?? int("DesignCapacity") ?? 0
    info.fullCapacity = dictInt(data, "FullChargeCapacity")
        ?? dictInt(data, "AppleRawMaxCapacity")
        ?? int("AppleRawMaxCapacity")
        ?? dictInt(data, "NominalChargeCapacity")
        ?? 0

    guard info.designCapacity > 0, info.fullCapacity > 0 else { return nil }

    info.cycles = int("CycleCount") ?? dictInt(data, "CycleCount") ?? 0

    // Процент заряда: на Apple Silicon CurrentCapacity уже в процентах,
    // на Intel — в мА·ч, поэтому делим на MaxCapacity.
    let current = int("CurrentCapacity") ?? 0
    let maxTop = int("MaxCapacity") ?? 100
    if maxTop > 100 {
        info.percent = Int((Double(current) / Double(maxTop) * 100).rounded())
        info.remaining = current
    } else {
        info.percent = current
        info.remaining = dictInt(data, "RemainingCapacity") ?? current
    }
    info.percent = min(100, max(0, info.percent))

    info.isCharging = (raw("IsCharging") as? Bool) ?? false
    info.isPlugged = (raw("ExternalConnected") as? Bool) ?? false

    let timeLeft = int("TimeRemaining") ?? 0
    let avgLeft = int("AvgTimeToEmpty") ?? 0
    if timeLeft > 0 && timeLeft < 3000 {
        info.minutesLeft = timeLeft
    } else if avgLeft > 0 && avgLeft < 3000 {
        info.minutesLeft = avgLeft
    }

    info.voltage = (dbl("Voltage") ?? 0) / 1000.0
    info.amperage = signed64(dbl("Amperage") ?? dbl("InstantAmperage") ?? 0) / 1000.0

    return info
}

// MARK: - CLI mode

if CommandLine.arguments.contains("--print") {
    guard let b = readBattery() else {
        print("battery not found")
        exit(1)
    }
    print(String(format: "charge      %d%%", b.percent))
    print(String(format: "health      %.1f%%", b.health))
    print("capacity    \(b.fullCapacity) / \(b.designCapacity) mAh")
    print("cycles      \(b.cycles)")
    print(String(format: "power       %.1f W  (%.2f V, %.2f A)", b.watts, b.voltage, b.amperage))
    print("plugged     \(b.isPlugged ? "yes" : "no")")
    print("charging    \(b.isCharging ? "yes" : "no")")
    exit(0)
}

// MARK: - UI

func valueLabel() -> NSTextField {
    let label = NSTextField(labelWithString: "—")
    label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    label.textColor = .labelColor
    label.alignment = .right
    return label
}

func row(_ title: String, _ value: NSTextField) -> NSStackView {
    let key = NSTextField(labelWithString: title)
    key.font = .systemFont(ofSize: 12)
    key.textColor = .secondaryLabelColor

    let stack = NSStackView(views: [key, NSView(), value])
    stack.orientation = .horizontal
    stack.spacing = 8
    return stack
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var window: NSWindow!
    var timer: Timer?

    let healthLabel = NSTextField(labelWithString: "—")
    let captionLabel = NSTextField(labelWithString: "")
    let verdictLabel = NSTextField(labelWithString: "")

    let chargeValue = valueLabel()
    let capacityValue = valueLabel()
    let cyclesValue = valueLabel()
    let powerValue = valueLabel()
    let leftValue = valueLabel()

    var shownHealth: Double = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(toggleWindow)
        statusItem.button?.target = self

        buildWindow()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func buildWindow() {
        let size = NSSize(width: 340, height: 430)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        window.contentView = effect

        healthLabel.font = .systemFont(ofSize: 64, weight: .bold)
        healthLabel.alignment = .center
        healthLabel.textColor = .labelColor

        captionLabel.font = .systemFont(ofSize: 12)
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.alignment = .center

        verdictLabel.font = .systemFont(ofSize: 13, weight: .medium)
        verdictLabel.alignment = .center
        verdictLabel.textColor = .secondaryLabelColor

        let header = NSStackView(views: [healthLabel, captionLabel, verdictLabel])
        header.orientation = .vertical
        header.spacing = 4
        header.alignment = .centerX

        let rows = NSStackView(views: [
            row("Заряд", chargeValue),
            row("Ёмкость", capacityValue),
            row("Циклы", cyclesValue),
            row("Расход", powerValue),
            row("Осталось", leftValue),
        ])
        rows.orientation = .vertical
        rows.spacing = 10
        rows.alignment = .leading

        let quitButton = NSButton(title: "Выход", target: self, action: #selector(quit))
        quitButton.bezelStyle = .inline
        quitButton.isBordered = false
        quitButton.contentTintColor = .secondaryLabelColor

        let root = NSStackView(views: [header, rows, NSView(), quitButton])
        root.orientation = .vertical
        root.spacing = 20
        root.alignment = .centerX
        root.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: effect.topAnchor, constant: 40),
            root.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -24),
            root.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -18),
            rows.widthAnchor.constraint(equalTo: root.widthAnchor),
        ])

        window.center()
    }

    @objc func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func refresh() {
        guard let b = readBattery() else {
            statusItem.button?.title = " —"
            healthLabel.stringValue = "—"
            healthLabel.textColor = .secondaryLabelColor
            captionLabel.stringValue = "батарея не найдена"
            verdictLabel.stringValue = "Этот Mac работает от сети"
            chargeValue.stringValue = "—"
            capacityValue.stringValue = "—"
            cyclesValue.stringValue = "—"
            powerValue.stringValue = "—"
            leftValue.stringValue = "—"
            return
        }

        statusItem.button?.title = " \(b.percent)%\(b.isCharging ? " ⚡" : "")"

        // Гистерезис: чип пересчитывает ёмкость каждые несколько секунд,
        // мелкие колебания (<0.6%) не должны менять цифру.
        if shownHealth < 0 || abs(b.health - shownHealth) >= 0.6 {
            shownHealth = b.health
        }

        healthLabel.stringValue = String(format: "%.0f%%", shownHealth)
        healthLabel.textColor = color(for: shownHealth)
        verdictLabel.stringValue = b.verdict

        let plugText = b.isPlugged ? (b.isCharging ? " · заряжается" : " · от сети") : ""
        captionLabel.stringValue = String(format: "реальная ёмкость · %.1f%%", b.health) + plugText

        chargeValue.stringValue = "\(b.percent)%"
        capacityValue.stringValue = "\(b.fullCapacity) / \(b.designCapacity) мА·ч"
        cyclesValue.stringValue = "\(b.cycles)"
        powerValue.stringValue = String(format: "%.1f Вт", b.watts)

        if b.isPlugged {
            leftValue.stringValue = b.isCharging ? "заряжается" : "от сети"
        } else if b.minutesLeft > 0 {
            let h = b.minutesLeft / 60
            let m = b.minutesLeft % 60
            leftValue.stringValue = h > 0 ? "\(h) ч \(m) мин" : "\(m) мин"
        } else {
            leftValue.stringValue = "—"
        }
    }

    func color(for health: Double) -> NSColor {
        if health >= 85 { return .systemGreen }
        if health >= 80 { return .systemYellow }
        if health >= 70 { return .systemOrange }
        return .systemRed
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
