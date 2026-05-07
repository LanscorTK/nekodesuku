import Cocoa

final class RelationshipView: NSView {
    weak var controller: MainPanelController?

    init(frame: NSRect, controller: MainPanelController) {
        self.controller = controller
        super.init(frame: frame)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func refresh() {
        subviews.forEach { $0.removeFromSuperview() }

        guard let pets = controller?.appDelegate?.pets,
              let idx = controller?.selectedPetIndex,
              idx < pets.count else {
            renderEmptyState(message: "Select a cat in the list to see what they've learned about you.")
            renderBreakThresholdSlider()
            return
        }

        let pet = pets[idx]
        renderPetSummary(pet)
        renderBreakThresholdSlider()
    }

    private func renderEmptyState(message: String) {
        let lbl = NSTextField(labelWithString: message)
        lbl.font = NSFont.systemFont(ofSize: 11)
        lbl.textColor = .secondaryLabelColor
        lbl.frame = NSRect(x: 8, y: bounds.height - 22, width: bounds.width - 16, height: 16)
        addSubview(lbl)
    }

    private func renderPetSummary(_ pet: PetInstance) {
        let bond = bondLevel(stats: pet.stats)
        let bondLbl = NSTextField(labelWithString: "Bond with \(pet.petName): \(bondLevelDescription(bond)) (\(bond)/10)")
        bondLbl.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        bondLbl.frame = NSRect(x: 8, y: bounds.height - 22, width: bounds.width - 16, height: 16)
        addSubview(bondLbl)

        let top = pet.brain.bandit.topActions(limit: 3, minCount: 5)
        let favText: String
        if top.isEmpty {
            favText = "Still learning your cat — interact more!"
        } else {
            favText = "Favorite reactions: " + top.map { "\(displayName($0.action))" }.joined(separator: ", ")
        }
        let favLbl = NSTextField(labelWithString: favText)
        favLbl.font = NSFont.systemFont(ofSize: 11)
        favLbl.textColor = .secondaryLabelColor
        favLbl.frame = NSRect(x: 8, y: bounds.height - 42, width: bounds.width - 16, height: 16)
        addSubview(favLbl)

        let forget = NSButton(title: "Forget Me", target: self, action: #selector(forgetPressed))
        forget.bezelStyle = .inline
        forget.font = NSFont.systemFont(ofSize: 10)
        forget.frame = NSRect(x: bounds.width - 96, y: bounds.height - 22, width: 80, height: 18)
        forget.toolTip = "Reset what \(pet.petName) has learned about your reactions."
        addSubview(forget)
    }

    private func renderBreakThresholdSlider() {
        let perception = PerceptionLayer.shared.current()
        let activeMin = Int(perception.continuousScreenTimeSeconds / 60)
        let breakMin = Config.breakThresholdMinutes

        let info = NSTextField(labelWithString: "Screen time: \(activeMin)m  |  Break reminder at \(breakMin)m")
        info.font = NSFont.systemFont(ofSize: 11)
        info.frame = NSRect(x: 8, y: 36, width: bounds.width - 16, height: 16)
        addSubview(info)

        let slider = NSSlider(value: Double(breakMin), minValue: 1, maxValue: 180,
                              target: self, action: #selector(breakChanged(_:)))
        slider.frame = NSRect(x: 8, y: 8, width: bounds.width - 80, height: 20)
        slider.toolTip = "After this many minutes of continuous screen time, the cat starts pacing to nudge you for a break."
        addSubview(slider)

        let valLbl = NSTextField(labelWithString: "\(breakMin)m")
        valLbl.frame = NSRect(x: bounds.width - 64, y: 8, width: 50, height: 18)
        valLbl.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valLbl.alignment = .right
        valLbl.tag = 9001
        addSubview(valLbl)
    }

    @objc private func forgetPressed() {
        guard let pets = controller?.appDelegate?.pets,
              let idx = controller?.selectedPetIndex,
              idx < pets.count else { return }
        pets[idx].brain.bandit.reset()
        controller?.appDelegate?.savePets()
        refresh()
    }

    @objc private func breakChanged(_ sender: NSSlider) {
        let v = Int(sender.doubleValue.rounded())
        Config.breakThresholdMinutes = v
        Config.save()
        if let lbl = subviews.first(where: { $0.tag == 9001 }) as? NSTextField {
            lbl.stringValue = "\(v)m"
        }
    }

    private func bondLevel(stats: PetStats) -> Int {
        let raw = stats.clicks + stats.pettings * 2
        return min(10, raw / 5)
    }

    private func bondLevelDescription(_ level: Int) -> String {
        switch level {
        case 0...1: return "Stranger"
        case 2...3: return "Acquainted"
        case 4...5: return "Friendly"
        case 6...7: return "Bonded"
        case 8...9: return "Inseparable"
        default:    return "Soulmate"
        }
    }

    private func displayName(_ s: PetState) -> String {
        switch s {
        case .sitIdle:     return "sit idle"
        case .walkRight:   return "walk right"
        case .walkLeft:    return "walk left"
        case .sleeping:    return "sleep"
        case .meowing:     return "meow"
        case .yawning:     return "yawn"
        case .washing:     return "wash"
        case .scratching:  return "scratch"
        case .clickReact:  return "react"
        case .petting:     return "be pet"
        case .followMouse: return "follow mouse"
        case .pawAttack:   return "swat"
        case .zoomies:     return "zoomies"
        case .chaseBug:    return "chase"
        case .stretch:     return "stretch"
        case .climbEdge:   return "climb"
        case .walkTop:     return "walk top"
        }
    }
}
