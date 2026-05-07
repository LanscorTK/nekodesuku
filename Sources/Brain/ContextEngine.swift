import Foundation

enum Mood {
    case calm, playful, agitated
}

struct CatContext {
    var energy: Double   // 0...1 — drained by activity, restored by sleep
    var boredom: Double  // 0...1 — rises with monotony, falls on user interaction
    var concern: Double  // 0...1 — rises with user idle/overwork
    var mood: Mood

    static func fresh() -> CatContext {
        CatContext(energy: 0.7, boredom: 0.2, concern: 0.0, mood: .calm)
    }
}

private func clamp01(_ x: Double) -> Double { max(0, min(1, x)) }

func updateContext(_ ctx: inout CatContext, perception p: Perception, currentState: PetState, dt: TimeInterval) {
    // Energy: recovers fastest when the cat itself is resting, slower when user is idle,
    // drains slowly otherwise. Without the resting branch a cat with low energy would
    // sleep continuously without recovering.
    let resting = (currentState == .sleeping || currentState == .yawning)
    let energyDelta: Double
    if resting              { energyDelta =  0.008 }
    else if p.idleTimeSeconds > 60 { energyDelta =  0.003 }
    else                    { energyDelta = -0.001 }

    // Boredom rises slowly always; falls only via reward signal at user interaction.
    let boredomDelta = 0.0008

    // Concern is purely the screen-time intervention signal. Idle-swat used to share
    // this channel but is now time-only triggered (see PetBrain.pickNext); the old
    // idleTime → concern bump was orphaned and removed in v1.4.1.
    let breakThresholdMin = UserDefaultsStore.loadBreakThresholdMinutes()
    var concernDelta = -0.002
    if breakThresholdMin > 0 {
        let breakThresholdSec = Double(breakThresholdMin) * 60
        if p.continuousScreenTimeSeconds > breakThresholdSec * 0.8 { concernDelta += 0.01 }
    }

    ctx.energy = clamp01(ctx.energy + dt * energyDelta)
    ctx.boredom = clamp01(ctx.boredom + dt * boredomDelta)
    ctx.concern = clamp01(ctx.concern + dt * concernDelta)
    ctx.mood = deriveMood(ctx)
}

private func deriveMood(_ c: CatContext) -> Mood {
    if c.concern > 0.8 { return .agitated }
    if c.boredom > 0.6 && c.energy > 0.4 { return .playful }
    return .calm
}
