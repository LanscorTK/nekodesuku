import Cocoa

// ============================================================================
// MARK: - Main Panel
// ============================================================================

class MainPanelController {
    var window: NSWindow?
    weak var appDelegate: AppDelegate?
    var catListView: NSView?
    var rightHeaderLabel: NSTextField?
    var variantView: NSView?         // area below grid for variant buttons
    var statsView: NSView?           // stats display area
    var relationshipView: RelationshipView?
    var selectedPetIndex: Int? = nil  // nil = add mode, Int = change breed mode
    var pendingFolder: String? = nil  // breed clicked that has variants

    let winW: CGFloat = 560
    let winH: CGFloat = 700
    let leftW: CGFloat = 255
    let topH: CGFloat = 290  // height of cat area (above settings)
    let relH: CGFloat = 130  // vertical span of relationship section (excluding divider+header)

    func show() {
        if let w = window {
            rebuildCatList()
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: winW, height: winH),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "NekoDeskuToppu"
        w.center()
        w.isReleasedWhenClosed = false

        let root = NSView(frame: w.contentView!.bounds)

        // === Left column: My Cats ===
        let leftHeader = NSTextField(labelWithString: "My Cats")
        leftHeader.font = NSFont.boldSystemFont(ofSize: 14)
        leftHeader.frame = NSRect(x: 16, y: winH - 32, width: 200, height: 20)
        root.addSubview(leftHeader)

        let scrollH: CGFloat = topH - 80
        let catScroll = NSScrollView(frame: NSRect(x: 10, y: winH - 32 - scrollH - 8, width: leftW - 15, height: scrollH))
        catScroll.hasVerticalScroller = true
        catScroll.drawsBackground = false
        catScroll.autohidesScrollers = true
        let catContent = NSView(frame: NSRect(x: 0, y: 0, width: leftW - 30, height: scrollH))
        catScroll.documentView = catContent
        root.addSubview(catScroll)
        catListView = catContent

        let btnY = winH - topH - 4
        let addRandBtn = NSButton(title: "+ Random", target: self, action: #selector(addRandomCat))
        addRandBtn.frame = NSRect(x: 16, y: btnY, width: 80, height: 28)
        addRandBtn.font = NSFont.systemFont(ofSize: 11)
        root.addSubview(addRandBtn)

        let summonBtn = NSButton(title: "Summon", target: self, action: #selector(summonAll))
        summonBtn.frame = NSRect(x: 100, y: btnY, width: 70, height: 28)
        summonBtn.font = NSFont.systemFont(ofSize: 11)
        root.addSubview(summonBtn)

        let removeAllBtn = NSButton(title: "Rm All", target: self, action: #selector(removeAllCats))
        removeAllBtn.frame = NSRect(x: 174, y: btnY, width: 62, height: 28)
        removeAllBtn.font = NSFont.systemFont(ofSize: 11)
        root.addSubview(removeAllBtn)

        // === Stats area (below buttons, left column) ===
        let sArea = NSView(frame: NSRect(x: 10, y: winH - topH + 35, width: leftW - 15, height: 60))
        root.addSubview(sArea)
        statsView = sArea

        // === Vertical divider ===
        let vDiv = NSBox(frame: NSRect(x: leftW, y: winH - topH, width: 1, height: topH - 10))
        vDiv.boxType = .separator
        root.addSubview(vDiv)

        // === Right column: Add a Cat / Change Breed ===
        let rHeader = NSTextField(labelWithString: "Add a Cat")
        rHeader.font = NSFont.boldSystemFont(ofSize: 14)
        rHeader.frame = NSRect(x: leftW + 16, y: winH - 32, width: 260, height: 20)
        root.addSubview(rHeader)
        rightHeaderLabel = rHeader

        buildCatGrid(in: root)

        // === Variant picker area (below grid, right column) ===
        let varArea = NSView(frame: NSRect(x: leftW + 10, y: winH - topH + 5, width: winW - leftW - 20, height: 50))
        root.addSubview(varArea)
        variantView = varArea

        // === Horizontal divider ===
        let hDiv = NSBox(frame: NSRect(x: 10, y: winH - topH - 10, width: winW - 20, height: 1))
        hDiv.boxType = .separator
        root.addSubview(hDiv)

        // === Bottom: Settings ===
        let sHeader = NSTextField(labelWithString: "Settings")
        sHeader.font = NSFont.boldSystemFont(ofSize: 14)
        sHeader.frame = NSRect(x: 16, y: winH - topH - 36, width: 200, height: 20)
        root.addSubview(sHeader)

        buildSettings(in: root, baseY: winH - topH - 65)

        // === Horizontal divider above Relationship ===
        let relDiv = NSBox(frame: NSRect(x: 10, y: relH + 8, width: winW - 20, height: 1))
        relDiv.boxType = .separator
        root.addSubview(relDiv)

        // === Relationship section ===
        let relHeader = NSTextField(labelWithString: "Relationship")
        relHeader.font = NSFont.boldSystemFont(ofSize: 14)
        relHeader.frame = NSRect(x: 16, y: relH - 16, width: 200, height: 20)
        root.addSubview(relHeader)

        let rel = RelationshipView(
            frame: NSRect(x: 10, y: 10, width: winW - 20, height: relH - 30),
            controller: self
        )
        root.addSubview(rel)
        relationshipView = rel

        w.contentView = root
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w

        rebuildCatList()
    }

    // MARK: Cat List

    func rebuildCatList() {
        guard let container = catListView else { return }
        container.subviews.removeAll()

        guard let pets = appDelegate?.pets else { return }
        let rowH: CGFloat = 72
        let contentW = container.enclosingScrollView?.frame.width ?? 240
        let totalH = max(CGFloat(pets.count) * rowH, container.enclosingScrollView?.frame.height ?? 200)
        container.frame = NSRect(x: 0, y: 0, width: contentW, height: totalH)

        for (i, pet) in pets.enumerated() {
            let y = totalH - CGFloat(i + 1) * rowH
            let row = NSView(frame: NSRect(x: 0, y: y, width: contentW, height: rowH))
            row.wantsLayer = true

            // Selected highlight
            if selectedPetIndex == i {
                row.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
                row.layer?.cornerRadius = 6
            }

            // Click to select/deselect
            let clickBtn = NSButton(frame: NSRect(x: 0, y: 0, width: contentW, height: rowH))
            clickBtn.isBordered = false
            clickBtn.isTransparent = true
            clickBtn.tag = i
            clickBtn.target = self
            clickBtn.action = #selector(selectCat(_:))
            row.addSubview(clickBtn)

            // Thumbnail (vertically centered)
            let thumbSize: CGFloat = 40
            let thumbY = (rowH - thumbSize) / 2
            let gifPath = gifPathForCat(folder: pet.catFolder, variant: pet.catVariant)
            if let thumb = extractThumbnail(gifPath: gifPath, size: thumbSize) {
                let iv = NSImageView(frame: NSRect(x: 8, y: thumbY, width: thumbSize, height: thumbSize))
                iv.image = thumb
                iv.imageScaling = .scaleNone
                row.addSubview(iv)
            }

            // Name (vertically centered with breed)
            let textX: CGFloat = 56
            let name = NSTextField(labelWithString: pet.petName)
            name.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            name.frame = NSRect(x: textX, y: 36, width: 120, height: 18)
            row.addSubview(name)

            // Breed
            let info = NSTextField(labelWithString: Config.catDisplayName(pet.catFolder))
            info.font = NSFont.systemFont(ofSize: 11)
            info.textColor = .secondaryLabelColor
            info.frame = NSRect(x: textX, y: 20, width: 120, height: 15)
            row.addSubview(info)

            // Buttons row
            let btnY: CGFloat = 2
            let renameBtn = NSButton(title: "Rename", target: self, action: #selector(renameCat(_:)))
            renameBtn.font = NSFont.systemFont(ofSize: 10)
            renameBtn.tag = i
            renameBtn.frame = NSRect(x: textX, y: btnY, width: 58, height: 18)
            renameBtn.bezelStyle = .inline
            row.addSubview(renameBtn)

            if pets.count > 1 {
                let delBtn = NSButton(title: "Del", target: self, action: #selector(removeCat(_:)))
                delBtn.font = NSFont.systemFont(ofSize: 10)
                delBtn.tag = i
                delBtn.frame = NSRect(x: textX + 62, y: btnY, width: 36, height: 18)
                delBtn.bezelStyle = .inline
                row.addSubview(delBtn)
            }

            // Top separator (between rows)
            if i > 0 {
                let sep = NSBox(frame: NSRect(x: 8, y: rowH - 1, width: contentW - 16, height: 1))
                sep.boxType = .separator
                row.addSubview(sep)
            }

            container.addSubview(row)
        }

        updateRightHeader()
        rebuildStats()
        relationshipView?.refresh()
    }

    func rebuildStats() {
        guard let container = statsView else { return }
        container.subviews.removeAll()

        guard let idx = selectedPetIndex, let pets = appDelegate?.pets, idx < pets.count else {
            // No cat selected — show nothing
            return
        }
        let s = pets[idx].stats
        let uptime = ProcessInfo.processInfo.systemUptime - s.createdAt
        let days = Int(uptime / 86400)
        let hours = Int(uptime.truncatingRemainder(dividingBy: 86400) / 3600)
        let distM = Int(s.totalDistance / 100)  // ~100px per "meter"
        let sleepMin = Int(s.sleepTime / 60)

        let lines = [
            "Companion: \(days)d \(hours)h  |  Clicks: \(s.clicks)  |  Pets: \(s.pettings)",
            "Walked: \(distM)m  |  Slept: \(sleepMin)m",
        ]

        for (i, line) in lines.enumerated() {
            let lbl = NSTextField(labelWithString: line)
            lbl.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            lbl.textColor = .secondaryLabelColor
            lbl.frame = NSRect(x: 4, y: CGFloat(35 - i * 18), width: 240, height: 14)
            container.addSubview(lbl)
        }
    }

    func updateRightHeader() {
        if let idx = selectedPetIndex, let pets = appDelegate?.pets, idx < pets.count {
            rightHeaderLabel?.stringValue = "Change Breed: \(pets[idx].petName)"
        } else {
            selectedPetIndex = nil
            rightHeaderLabel?.stringValue = "Add a Cat"
        }
    }

    // MARK: Cat Grid

    func buildCatGrid(in root: NSView) {
        let cols = 5
        let cellW: CGFloat = 54
        let cellH: CGFloat = 72
        let gridX: CGFloat = leftW + 14
        let gridTopY: CGFloat = winH - 85

        for c in 1...13 {
            let col = (c - 1) % cols
            let row = (c - 1) / cols
            let x = gridX + CGFloat(col) * cellW
            let y = gridTopY - CGFloat(row) * cellH

            let folder = "Cat \(c)"
            let catDir = "\(Config.packPath)/\(folder)"
            let gifPath: String
            if FileManager.default.fileExists(atPath: "\(catDir)/meow_sit.gif") {
                gifPath = "\(catDir)/meow_sit.gif"
            } else {
                let variant = appDelegate?.findFirstVariant(folder: folder) ?? ""
                gifPath = variant.isEmpty ? "\(catDir)/meow_sit.gif" : "\(catDir)/\(variant)/meow_sit.gif"
            }

            let btn = NSButton(frame: NSRect(x: x, y: y, width: 46, height: 46))
            btn.bezelStyle = .regularSquare
            btn.isBordered = true
            if let thumb = extractThumbnail(gifPath: gifPath, size: 38) {
                btn.image = thumb
                btn.imagePosition = .imageOnly
                btn.imageScaling = .scaleNone
            } else {
                btn.title = folder
            }
            btn.tag = c
            btn.target = self
            btn.action = #selector(gridCatClicked(_:))
            root.addSubview(btn)

            let label = NSTextField(labelWithString: Config.catDisplayName(folder))
            label.font = NSFont.systemFont(ofSize: 9)
            label.alignment = .center
            label.frame = NSRect(x: x - 4, y: y - 16, width: 54, height: 14)
            root.addSubview(label)
        }
    }

    // MARK: Settings

    func buildSettings(in root: NSView, baseY: CGFloat) {
        var y = baseY
        let tooltips: [String: String] = [
            "Size": "Cat pixel scale (3x=tiny, 10x=huge)",
            "Speed": "Walking speed in pixels per second",
            "Gravity": "How fast cats fall down",
            "Activity": "0=calm (mostly sleep), 2=hyperactive (lots of zoomies)",
        ]

        let sliders: [(String, Double, Double, Double, Selector, String)] = [
            ("Size",     3, 10,  Double(Config.scale),        #selector(scaleChanged(_:)),    "%.0f"),
            ("Speed",   10, 80,  Double(Config.walkSpeed),    #selector(speedChanged(_:)),    "%.0f"),
            ("Gravity", 20, 200, Double(Config.gravitySpeed), #selector(gravityChanged(_:)),  "%.0f"),
            ("Activity", 0, 2,   Config.activityLevel,        #selector(activityChanged(_:)), "%.1f"),
        ]

        for (label, min, max, val, action, fmt) in sliders {
            let lbl = NSTextField(labelWithString: label)
            lbl.frame = NSRect(x: 20, y: y, width: 65, height: 20)
            lbl.font = NSFont.systemFont(ofSize: 11)
            lbl.toolTip = tooltips[label]
            root.addSubview(lbl)

            let slider = NSSlider(value: val, minValue: min, maxValue: max,
                                  target: self, action: action)
            slider.frame = NSRect(x: 90, y: y, width: winW - 160, height: 20)
            slider.tag = Int(y)
            root.addSubview(slider)

            let valLbl = NSTextField(labelWithString: String(format: fmt, val))
            valLbl.frame = NSRect(x: winW - 60, y: y, width: 45, height: 20)
            valLbl.alignment = .right
            valLbl.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            valLbl.tag = 1000 + Int(y)
            root.addSubview(valLbl)

            y -= 28
        }

        // Auto-sleep slider
        let sleepLbl = NSTextField(labelWithString: "Auto Sleep")
        sleepLbl.frame = NSRect(x: 20, y: y, width: 65, height: 20)
        sleepLbl.font = NSFont.systemFont(ofSize: 11)
        sleepLbl.toolTip = "Minutes of no interaction before all cats fall asleep (0=off)"
        root.addSubview(sleepLbl)

        let sleepSlider = NSSlider(value: Config.autoSleepMinutes, minValue: 0, maxValue: 30,
                                   target: self, action: #selector(autoSleepChanged(_:)))
        sleepSlider.frame = NSRect(x: 90, y: y, width: winW - 160, height: 20)
        sleepSlider.tag = Int(y)
        root.addSubview(sleepSlider)

        let sleepVal = NSTextField(labelWithString: Config.autoSleepMinutes > 0 ? "\(Int(Config.autoSleepMinutes))m" : "Off")
        sleepVal.frame = NSRect(x: winW - 60, y: y, width: 45, height: 20)
        sleepVal.alignment = .right
        sleepVal.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        sleepVal.tag = 1000 + Int(y)
        root.addSubview(sleepVal)
        y -= 28

        let winCheck = NSButton(checkboxWithTitle: "Window Awareness", target: self, action: #selector(windowAwarenessChanged(_:)))
        winCheck.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        winCheck.state = Config.windowAwareness ? .on : .off
        winCheck.font = NSFont.systemFont(ofSize: 11)
        winCheck.toolTip = "Cats can stand on top of other app windows"
        root.addSubview(winCheck)
        y -= 28

        let resetBtn = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaults(_:)))
        resetBtn.frame = NSRect(x: winW - 130, y: y - 2, width: 110, height: 24)
        resetBtn.font = NSFont.systemFont(ofSize: 10)
        root.addSubview(resetBtn)
    }

    // MARK: Actions

    @objc func selectCat(_ sender: NSButton) {
        if selectedPetIndex == sender.tag {
            selectedPetIndex = nil  // deselect
        } else {
            selectedPetIndex = sender.tag
        }
        rebuildCatList()
    }

    @objc func gridCatClicked(_ sender: NSButton) {
        let folder = "Cat \(sender.tag)"

        // Check if this breed has variants
        let catDir = "\(Config.packPath)/\(folder)"
        let variants: [String] = {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: catDir) else { return [] }
            return items.filter { name in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: "\(catDir)/\(name)", isDirectory: &isDir)
                return isDir.boolValue
            }.sorted()
        }()

        if variants.count > 1 {
            // Has variants — show variant picker
            pendingFolder = folder
            showVariants(folder: folder, variants: variants)
        } else {
            // No variants — directly add/change
            let variant = variants.first ?? ""
            applyBreedSelection(folder: folder, variant: variant)
        }
    }

    func showVariants(folder: String, variants: [String]) {
        guard let container = variantView else { return }
        container.subviews.removeAll()

        let scrollView = NSScrollView(frame: container.bounds)
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let cellW: CGFloat = 42
        let contentW = max(CGFloat(variants.count) * cellW + 8, scrollView.frame.width)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: contentW, height: 46))

        for (i, v) in variants.enumerated() {
            let x: CGFloat = 4 + CGFloat(i) * cellW
            let gifPath = gifPathForCat(folder: folder, variant: v)
            let btn = NSButton(frame: NSRect(x: x, y: 6, width: 36, height: 36))
            btn.bezelStyle = .regularSquare
            btn.isBordered = true
            if let thumb = extractThumbnail(gifPath: gifPath, size: 30) {
                btn.image = thumb
                btn.imagePosition = .imageOnly
                btn.imageScaling = .scaleNone
            } else {
                btn.title = String(v.suffix(3))
                btn.font = NSFont.systemFont(ofSize: 8)
            }
            btn.tag = i
            btn.target = self
            btn.action = #selector(variantClicked(_:))
            btn.toolTip = v
            content.addSubview(btn)
        }

        scrollView.documentView = content
        container.addSubview(scrollView)
    }

    @objc func variantClicked(_ sender: NSButton) {
        guard let folder = pendingFolder else { return }
        let catDir = "\(Config.packPath)/\(folder)"
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: catDir) else { return }
        let variants = items.filter { name in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: "\(catDir)/\(name)", isDirectory: &isDir)
            return isDir.boolValue
        }.sorted()
        guard sender.tag < variants.count else { return }
        applyBreedSelection(folder: folder, variant: variants[sender.tag])
    }

    func applyBreedSelection(folder: String, variant: String) {
        if let idx = selectedPetIndex, let pets = appDelegate?.pets, idx < pets.count {
            pets[idx].changeCat(folder: folder, variant: variant)
        } else {
            appDelegate?.addPet(catFolder: folder, catVariant: variant)
        }
        appDelegate?.savePets()
        pendingFolder = nil
        variantView?.subviews.removeAll()
        rebuildCatList()
    }

    @objc func renameCat(_ sender: NSButton) {
        guard let pets = appDelegate?.pets, sender.tag < pets.count else { return }
        let pet = pets[sender.tag]
        let alert = NSAlert()
        alert.messageText = "Rename Cat"
        alert.informativeText = "Enter a new name:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = pet.petName
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        if alert.runModal() == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                pet.petName = name
                appDelegate?.savePets()
                rebuildCatList()
            }
        }
    }

    @objc func removeCat(_ sender: NSButton) {
        guard let delegate = appDelegate, sender.tag < delegate.pets.count,
              delegate.pets.count > 1 else { return }
        if selectedPetIndex == sender.tag { selectedPetIndex = nil }
        else if let sel = selectedPetIndex, sel > sender.tag { selectedPetIndex = sel - 1 }
        let pet = delegate.pets.remove(at: sender.tag)
        pet.close()
        delegate.savePets()
        rebuildCatList()
    }

    @objc func addRandomCat() {
        appDelegate?.addRandomPet()
        rebuildCatList()
    }

    @objc func summonAll() {
        appDelegate?.summonAllPets()
    }

    @objc func removeAllCats() {
        guard let delegate = appDelegate, delegate.pets.count > 1 else { return }
        while delegate.pets.count > 1 {
            delegate.pets.removeLast().close()
        }
        selectedPetIndex = nil
        delegate.savePets()
        rebuildCatList()
    }

    // MARK: Settings Actions

    private func updateValueLabel(slider: NSSlider, format: String = "%.0f") {
        guard let view = slider.superview else { return }
        if let label = view.viewWithTag(1000 + slider.tag) as? NSTextField {
            label.stringValue = String(format: format, slider.doubleValue)
        }
    }

    @objc func scaleChanged(_ sender: NSSlider) {
        updateValueLabel(slider: sender)
        Config.scale = CGFloat(sender.doubleValue)
        Config.save()
        appDelegate?.resizeAllPets()
    }

    @objc func speedChanged(_ sender: NSSlider) {
        updateValueLabel(slider: sender)
        Config.walkSpeed = CGFloat(sender.doubleValue)
        Config.save()
    }

    @objc func gravityChanged(_ sender: NSSlider) {
        updateValueLabel(slider: sender)
        Config.gravitySpeed = CGFloat(sender.doubleValue)
        Config.save()
    }

    @objc func activityChanged(_ sender: NSSlider) {
        updateValueLabel(slider: sender, format: "%.1f")
        Config.activityLevel = sender.doubleValue
        Config.save()
    }

    @objc func autoSleepChanged(_ sender: NSSlider) {
        Config.autoSleepMinutes = round(sender.doubleValue)
        Config.save()
        guard let view = sender.superview else { return }
        if let label = view.viewWithTag(1000 + sender.tag) as? NSTextField {
            label.stringValue = Config.autoSleepMinutes > 0 ? "\(Int(Config.autoSleepMinutes))m" : "Off"
        }
    }

    @objc func windowAwarenessChanged(_ sender: NSButton) {
        Config.windowAwareness = sender.state == .on
        Config.save()
    }

    @objc func resetDefaults(_ sender: Any) {
        Config.scale = 6.0
        Config.walkSpeed = 30
        Config.gravitySpeed = 80
        Config.activityLevel = 1.0
        Config.windowAwareness = true
        Config.autoSleepMinutes = 5.0
        Config.save()
        appDelegate?.resizeAllPets()
        window?.close()
        window = nil
        show()
    }
}
