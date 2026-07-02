//
//  ServiceLocator.swift
//  Perch
//
//  DI container — Repositories & Managers register here, ViewModels resolve them.
//  ViewModels are NOT registered (owned by AppDelegate).
//

import Foundation

final class ServiceLocator {
    static let shared = ServiceLocator()
    private var registry: [String: () -> Any] = [:]
    private init() {}

    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        registry[key(type)] = factory
    }

    func resolve<T>(_ type: T.Type) -> T {
        guard let factory = registry[key(type)] else {
            fatalError("ServiceLocator: no registration for \(T.self)")
        }
        guard let instance = factory() as? T else {
            fatalError("ServiceLocator: registration for \(T.self) produced wrong type")
        }
        return instance
    }

    private func key<T>(_ type: T.Type) -> String {
        String(describing: type)
    }
}
