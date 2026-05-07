import Foundation

struct BehaviorPolicy {
    static func chooseAction(ctx: CatContext, perception p: Perception, bandit: Bandit) -> PetState {
        // Hard overrides (most specific first).
        if ctx.energy < 0.15 { return .sleeping }
        if ctx.concern > 0.7 && p.idleTimeSeconds > 300 {
            // Step 3/3 wires the swat tail off the followMouse end-state.
            return .followMouse
        }
        if ctx.mood == .agitated {
            return bandit.sample(eligible: agitatedActions)
        }

        let eligible: [PetState]
        switch ctx.mood {
        case .playful:  eligible = playfulActions
        case .calm:     eligible = calmActions
        case .agitated: eligible = agitatedActions  // unreachable, handled above
        }
        return bandit.sample(eligible: eligible)
    }

    static let calmActions: [PetState] = [
        .walkRight, .walkLeft, .yawning, .washing, .scratching, .stretch, .meowing
    ]
    static let playfulActions: [PetState] = [
        .zoomies, .chaseBug, .followMouse, .stretch, .walkRight, .walkLeft
    ]
    static let agitatedActions: [PetState] = [
        .walkRight, .walkLeft, .meowing
    ]

    /// All actions the bandit may select. Reactive states (clickReact/petting) and
    /// environment-triggered states (climbEdge/walkTop/pawAttack) are intentionally
    /// excluded.
    static let banditEligible: Set<PetState> = Set(calmActions + playfulActions + agitatedActions + [.sleeping])
}
