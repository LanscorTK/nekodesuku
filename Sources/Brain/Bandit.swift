import Foundation

final class Bandit {
    private(set) var counts: [PetState: Int] = [:]
    private(set) var rewards: [PetState: Double] = [:]
    private(set) var totalActions: Int = 0

    private let epsilonInitial: Double = 0.5
    private let epsilonFinal: Double = 0.05
    private let epsilonDecayActions: Int = 200

    init() {}

    init?(dict: [String: Any]) {
        guard let c = dict["counts"] as? [String: Int],
              let r = dict["rewards"] as? [String: Double] else { return nil }
        for (k, v) in c { if let s = Bandit.state(from: k) { counts[s] = v } }
        for (k, v) in r { if let s = Bandit.state(from: k) { rewards[s] = v } }
        totalActions = dict["totalActions"] as? Int ?? 0
    }

    func currentEpsilon() -> Double {
        let progress = min(Double(totalActions) / Double(epsilonDecayActions), 1.0)
        return epsilonInitial + (epsilonFinal - epsilonInitial) * progress
    }

    func sample(eligible: [PetState]) -> PetState {
        guard !eligible.isEmpty else { return .sitIdle }
        if Double.random(in: 0..<1) < currentEpsilon() {
            return eligible.randomElement()!
        }
        let scored = eligible.map { ($0, rewards[$0, default: 0]) }
        let maxR = scored.map { $0.1 }.max() ?? 0
        let bests = scored.filter { $0.1 == maxR }.map { $0.0 }
        return bests.randomElement()!
    }

    func record(action: PetState, reward: Double) {
        let n = counts[action, default: 0] + 1
        let prev = rewards[action, default: 0]
        rewards[action] = prev + (reward - prev) / Double(n)
        counts[action] = n
        totalActions += 1
    }

    func reset() {
        counts.removeAll()
        rewards.removeAll()
        totalActions = 0
    }

    func toDict() -> [String: Any] {
        var c: [String: Int] = [:]
        for (k, v) in counts { c[Bandit.key(for: k)] = v }
        var r: [String: Double] = [:]
        for (k, v) in rewards { r[Bandit.key(for: k)] = v }
        return ["counts": c, "rewards": r, "totalActions": totalActions]
    }

    func topActions(limit: Int, minCount: Int = 1) -> [(action: PetState, reward: Double, count: Int)] {
        rewards
            .compactMap { (s, r) -> (PetState, Double, Int)? in
                let n = counts[s, default: 0]
                guard n >= minCount else { return nil }
                return (s, r, n)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { (action: $0.0, reward: $0.1, count: $0.2) }
    }

    private static func key(for s: PetState) -> String {
        switch s {
        case .sitIdle:     return "sitIdle"
        case .walkRight:   return "walkRight"
        case .walkLeft:    return "walkLeft"
        case .sleeping:    return "sleeping"
        case .meowing:     return "meowing"
        case .yawning:     return "yawning"
        case .washing:     return "washing"
        case .scratching:  return "scratching"
        case .clickReact:  return "clickReact"
        case .petting:     return "petting"
        case .followMouse: return "followMouse"
        case .pawAttack:   return "pawAttack"
        case .zoomies:     return "zoomies"
        case .chaseBug:    return "chaseBug"
        case .stretch:     return "stretch"
        case .climbEdge:   return "climbEdge"
        case .walkTop:     return "walkTop"
        }
    }

    private static func state(from key: String) -> PetState? {
        switch key {
        case "sitIdle":     return .sitIdle
        case "walkRight":   return .walkRight
        case "walkLeft":    return .walkLeft
        case "sleeping":    return .sleeping
        case "meowing":     return .meowing
        case "yawning":     return .yawning
        case "washing":     return .washing
        case "scratching":  return .scratching
        case "clickReact":  return .clickReact
        case "petting":     return .petting
        case "followMouse": return .followMouse
        case "pawAttack":   return .pawAttack
        case "zoomies":     return .zoomies
        case "chaseBug":    return .chaseBug
        case "stretch":     return .stretch
        case "climbEdge":   return .climbEdge
        case "walkTop":     return .walkTop
        default:            return nil
        }
    }
}
