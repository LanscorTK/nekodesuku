import Foundation

struct BehaviorPolicy {
    static func chooseAction(ctx: CatContext, perception p: Perception, bandit: Bandit) -> PetState {
        // Hard overrides (most specific first). Idle-swat used to live here gated on
        // concern; v1.4.1 moved it to PetBrain.pickNext as a time-only one-shot trigger
        // backed by Config.idleSwatMinutes.
        if ctx.energy < 0.15 { return .sleeping }
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
