import Cocoa
import ServiceManagement

// ============================================================================
// MARK: - App Delegate
// ============================================================================

class AppDelegate: NSObject, NSApplicationDelegate {
    var pets: [PetInstance] = []
    var timer: Timer!
    var statusItem: NSStatusItem!
    var menuTargetPet: PetInstance?
    let panelController = MainPanelController()
    let windowTracker = WindowTracker()
    var lastInteractionTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    var lastStatsSave: TimeInterval = 0

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard NSScreen.main != nil else {
            print("No screen found"); NSApp.terminate(nil); return
        }

        Config.restore()
        UserDefaults.standard.set(0.3, forKey: "NSInitialToolTipDelay")
        panelController.appDelegate = self
        restorePets()

        if pets.isEmpty {
            print("No animations found. Check 'Kittens pack' path.")
            NSApp.terminate(nil); return
        }

        setupStatusBar()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer, forMode: .common)
    }

    func tick() {
        PerceptionLayer.shared.update()
        windowTracker.update()

        // Auto-sleep: if no interaction for N minutes, all cats sleep
        if Config.autoSleepMinutes > 0 {
            let idle = ProcessInfo.processInfo.systemUptime - lastInteractionTime
            if idle > Config.autoSleepMinutes * 60 {
                for pet in pets {
                    if case .sleeping = pet.brain.state { } else {
                        if case .petting = pet.brain.state { } else {
                            pet.brain.enter(.sleeping)
                        }
                    }
                }
            }
        }

        for pet in pets { pet.tick() }

        // Auto-save stats every 60 seconds
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastStatsSave > 60 { lastStatsSave = now; savePets() }
    }

    // MARK: - Status Bar

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Pixel cat icon from Kittens pack (use variant detection)
        let iconVariant = findFirstVariant(folder: "Cat 1")
        let iconGIF = gifPathForCat(folder: "Cat 1", variant: iconVariant)
        if let thumb = extractThumbnail(gifPath: iconGIF, size: 18) {
            thumb.isTemplate = true
            statusItem.button?.image = thumb
        } else {
            statusItem.button?.title = "🐱"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func rebuildStatusMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let addItem = NSMenuItem(title: "Add Cat", action: #selector(addRandomPet), keyEquivalent: "n")
        addItem.target = self
        menu.addItem(addItem)

        let summonItem = NSMenuItem(title: "Summon All Cats", action: #selector(summonAllPets), keyEquivalent: "s")
        summonItem.target = self
        menu.addItem(summonItem)

        if pets.count > 1 {
            let rmItem = NSMenuItem(title: "Remove Last Cat", action: #selector(removeLastPet), keyEquivalent: "")
            rmItem.target = self
            menu.addItem(rmItem)

            let rmAllItem = NSMenuItem(title: "Remove All Cats", action: #selector(removeAllPets), keyEquivalent: "")
            rmAllItem.target = self
            menu.addItem(rmAllItem)
        }

        menu.addItem(.separator())

        for (i, pet) in pets.enumerated() {
            let title = "Cat #\(i + 1): \(pet.petName)"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for c in 1...13 {
                let folder = "Cat \(c)"
                let ci = NSMenuItem(title: Config.catDisplayName(folder), action: #selector(statusChangeCat(_:)), keyEquivalent: "")
                ci.tag = i * 100 + c
                ci.target = self
                if pet.catFolder == folder { ci.state = .on }
                sub.addItem(ci)
            }
            item.submenu = sub
            menu.addItem(item)
        }

        menu.addItem(.separator())



        let panelItem = NSMenuItem(title: "Open Panel…", action: #selector(openPanel), keyEquivalent: ",")
        panelItem.target = self
        menu.addItem(panelItem)

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let versionItem = NSMenuItem(title: "NekoDeskuToppu v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
    }

    @objc func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }

    @objc func checkForUpdates() {
        let repoURL = "https://api.github.com/repos/lanscortk/nekodesuku/releases/latest"
        guard let url = URL(string: repoURL) else { return }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    let alert = NSAlert()
                    alert.messageText = "Update Check Failed"
                    alert.informativeText = "Could not reach GitHub. Check your internet connection."
                    alert.runModal()
                    return
                }
                let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                let local = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                if remote.compare(local, options: .numeric) == .orderedDescending {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "Version \(remote) is available (you have \(local))."
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")
                    if alert.runModal() == .alertFirstButtonReturn,
                       let htmlURL = json["html_url"] as? String,
                       let dl = URL(string: htmlURL) {
                        NSWorkspace.shared.open(dl)
                    }
                } else {
                    let alert = NSAlert()
                    alert.messageText = "You're Up to Date"
                    alert.informativeText = "NekoDeskuToppu \(local) is the latest version."
                    alert.runModal()
                }
            }
        }.resume()
    }

    @objc func addRandomPet() {
        let catNum = Int.random(in: 1...13)
        let folder = "Cat \(catNum)"
        addPet(catFolder: folder, catVariant: findFirstVariant(folder: folder))
        savePets()
    }

    @objc func summonAllPets() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!
        let bottomY = screen.visibleFrame.minY
        for (i, pet) in pets.enumerated() {
            let x = mouse.x - Config.windowSize / 2 + CGFloat(i) * (Config.windowSize + 10)
            pet.window.setFrameOrigin(NSPoint(x: x, y: bottomY))
            pet.view.gravityEnabled = true
            pet.brain.enter(.sitIdle)
        }
    }

    @objc func removeLastPet() {
        guard pets.count > 1 else { return }
        pets.removeLast().close()
        savePets()
    }

    @objc func removeAllPets() {
        guard pets.count > 1 else { return }
        while pets.count > 1 { pets.removeLast().close() }
        savePets()
    }

    @objc func statusChangeCat(_ sender: NSMenuItem) {
        let petIdx = sender.tag / 100
        let catNum = sender.tag % 100
        guard petIdx < pets.count else { return }
        let folder = "Cat \(catNum)"
        pets[petIdx].changeCat(folder: folder, variant: findFirstVariant(folder: folder))
        savePets()
    }

    // MARK: - Per-Pet Context Menu

    func showPetMenu(for pet: PetInstance, event: NSEvent) {
        menuTargetPet = pet
        let menu = NSMenu()

        let catSub = NSMenu()
        for i in 1...13 {
            let folder = "Cat \(i)"
            let item = NSMenuItem(title: Config.catDisplayName(folder), action: #selector(ctxPickCat(_:)), keyEquivalent: "")
            item.tag = i; item.target = self
            if pet.catFolder == folder { item.state = .on }
            catSub.addItem(item)
        }
        let catItem = NSMenuItem(title: "Choose Cat", action: nil, keyEquivalent: "")
        catItem.submenu = catSub
        menu.addItem(catItem)

        let catDir = "\(Config.packPath)/\(pet.catFolder)"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: catDir) {
            let variants = contents.filter { name in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: "\(catDir)/\(name)", isDirectory: &isDir)
                return isDir.boolValue
            }.sorted()
            if variants.count > 1 {
                let varSub = NSMenu()
                for v in variants {
                    let item = NSMenuItem(title: v, action: #selector(ctxPickVariant(_:)), keyEquivalent: "")
                    item.representedObject = v; item.target = self
                    if v == pet.catVariant { item.state = .on }
                    varSub.addItem(item)
                }
                let varItem = NSMenuItem(title: "Color Variant", action: nil, keyEquivalent: "")
                varItem.submenu = varSub
                menu.addItem(varItem)
            }
        }

        menu.addItem(.separator())

        // Interactions
        let actSub = NSMenu()
        let actions: [(String, Int)] = [
            ("Sleep", 1), ("Meow", 2), ("Yawn", 3),
            ("Wash", 4), ("Scratch", 5), ("Zoomies", 6),
        ]
        for (title, tag) in actions {
            let item = NSMenuItem(title: title, action: #selector(ctxDoAction(_:)), keyEquivalent: "")
            item.tag = tag; item.target = self
            actSub.addItem(item)
        }
        let actItem = NSMenuItem(title: "Do…", action: nil, keyEquivalent: "")
        actItem.submenu = actSub
        menu.addItem(actItem)

        let renameItem = NSMenuItem(title: "Rename…", action: #selector(ctxRenamePet), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        if pets.count > 1 {
            let rm = NSMenuItem(title: "Remove This Cat", action: #selector(ctxRemovePet), keyEquivalent: "")
            rm.target = self
            menu.addItem(rm)
        }

        menu.addItem(.separator())
        let panelItem = NSMenuItem(title: "Open Panel…", action: #selector(openPanel), keyEquivalent: ",")
        panelItem.target = self
        menu.addItem(panelItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))

        NSMenu.popUpContextMenu(menu, with: event, for: pet.view)
    }

    @objc func ctxPickCat(_ sender: NSMenuItem) {
        guard let pet = menuTargetPet else { return }
        let folder = "Cat \(sender.tag)"
        pet.changeCat(folder: folder, variant: findFirstVariant(folder: folder))
        savePets()
    }

    @objc func ctxPickVariant(_ sender: NSMenuItem) {
        guard let pet = menuTargetPet, let v = sender.representedObject as? String else { return }
        pet.changeCat(folder: pet.catFolder, variant: v)
        savePets()
    }

    @objc func ctxRenamePet() {
        guard let pet = menuTargetPet else { return }
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
                savePets()
            }
        }
    }

    @objc func ctxDoAction(_ sender: NSMenuItem) {
        guard let pet = menuTargetPet else { return }
        switch sender.tag {
        case 1: pet.brain.enter(.sleeping)
        case 2: pet.brain.enter(.meowing)
        case 3: pet.brain.enter(.yawning)
        case 4: pet.brain.enter(.washing)
        case 5: pet.brain.enter(.scratching)
        case 6: pet.brain.enter(.zoomies)
        default: break
        }
    }

    @objc func ctxRemovePet() {
        guard let pet = menuTargetPet, pets.count > 1,
              let idx = pets.firstIndex(where: { $0 === pet }) else { return }
        pets.remove(at: idx)
        pet.close()
        savePets()
    }

    // MARK: - Settings

    @objc func openPanel() {
        panelController.show()
    }

    func resizeAllPets() {
        let sz = Config.windowSize
        for pet in pets {
            let origin = pet.window.frame.origin
            pet.window.setFrame(NSRect(x: origin.x, y: origin.y, width: sz, height: sz), display: false)
            pet.view.frame = NSRect(x: 0, y: 0, width: sz, height: sz)
            pet.view.updateTrackingAreas()
            pet.brain.loadAnims(catPath: pet.catPath)
            pet.brain.enter(.sitIdle)
        }
    }

    // MARK: - Persistence

    func savePets() {
        let data: [[String: Any]] = pets.map {
            ["folder": $0.catFolder, "variant": $0.catVariant, "name": $0.petName,
             "stats": $0.stats.toDict()]
        }
        UserDefaultsStore.saveSavedPets(data)
    }

    func restorePets() {
        if let saved = UserDefaultsStore.loadSavedPets(), !saved.isEmpty {
            for entry in saved {
                let folder = entry["folder"] as? String ?? "Cat 1"
                let variant = entry["variant"] as? String ?? folder
                let name = entry["name"] as? String
                addPet(catFolder: folder, catVariant: variant, petName: name)
                if let statsDict = entry["stats"] as? [String: Any] {
                    pets.last?.stats = PetStats.from(statsDict)
                }
            }
        }
        // Fall back to default if nothing loaded (first launch or stale saved data)
        if pets.isEmpty {
            addPet(catFolder: "Cat 1", catVariant: "Cat 1")
        }
    }

    // MARK: - Pet Management

    func addPet(catFolder: String, catVariant: String, petName: String? = nil) {
        let mouseScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main ?? NSScreen.screens.first!
        let sb = mouseScreen.visibleFrame
        let startX = sb.minX + CGFloat.random(in: 50...(max(51, sb.width - 150)))
        let pet = PetInstance(
            catFolder: catFolder, catVariant: catVariant, petName: petName,
            startX: startX, bottomY: sb.minY
        )
        guard !pet.brain.anims.isEmpty else { pet.close(); return }
        pets.append(pet)
    }

    func findFirstVariant(folder: String) -> String {
        let catDir = "\(Config.packPath)/\(folder)"
        if let items = try? FileManager.default.contentsOfDirectory(atPath: catDir) {
            let dirs = items.filter { name in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: "\(catDir)/\(name)", isDirectory: &isDir)
                return isDir.boolValue
            }.sorted()
            if let first = dirs.first { return first }
        }
        return ""  // no subfolders, GIFs are directly in the cat folder
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if menu == statusItem.menu { rebuildStatusMenu() }
    }
}
