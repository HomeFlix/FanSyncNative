import Foundation

/// Minimal multicast observer list, standing in for Combine's @Published on iOS 12
/// (ObservableObject/@Published require iOS 13). Holds weak-ish callback entries keyed
/// by an opaque token so a view controller can add/remove its subscription in
/// viewWillAppear/viewWillDisappear without leaking.
final class ObserverList<Value> {
    private var observers: [UUID: (Value) -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping (Value) -> Void) -> UUID {
        let token = UUID()
        observers[token] = callback
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    func notify(_ value: Value) {
        for callback in observers.values { callback(value) }
    }
}
