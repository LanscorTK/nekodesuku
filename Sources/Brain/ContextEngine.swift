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

func updateContext(_ ctx: inout CatContext, perception p: Perception, dt: TimeInterval) {
    // Energy drains slowly while active, recovers when user idle (cat naps too).
    let energyDelta = p.idleTimeSeconds > 60 ? 0.005 : -0.001

    // Boredom rises slowly always; falls only on user interaction (handled at reward callsite).
    let boredomDelta = 0.0008

    // Concern rises with screen time (user might need a break) and with user idleness past 5min.
    let breakThresholdSec = Double(UserDefaultsStore.loadBreakThresholdMinutes()) * 60
    var concernDelta = -0.002  // baseline decay
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
