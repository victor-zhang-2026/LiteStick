import Foundation
import Observation

@Observable @MainActor final class StickStore {
    var text: String { didSet { defaults.set(text, forKey: "note") } }
    @ObservationIgnored private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        text = defaults.string(forKey: "note") ?? ""
    }
    func clear() {
        text = ""
        defaults.set("", forKey: "note")
    }
}
