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

    // Concern rises with screen time and with user idleness past 5min; baseline decays.
    let breakThresholdSec = Double(UserDefaultsStore.loadBreakThresholdMinutes()) * 60
    var concernDelta = -0.002
    if p.continuousScreenTimeSeconds > breakThresholdSec * 0.8 { concernDelta += 0.01 }
    if p.idleTimeSeconds > 300 { concernDelta += 0.005 }

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
