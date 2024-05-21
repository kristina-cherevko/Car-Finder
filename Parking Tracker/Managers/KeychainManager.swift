//
//  KeychainManager.swift
//  Parking Tracker
//
//  Created by Kristina Cherevko on 5/15/24.
//

import Foundation
import Security
import CoreLocation

struct KeychainManager {
    
    private let accountKey = "TrackerLocation"
    
    @discardableResult
    func save(_ location: Location) -> Bool {
        // TODO: Delete previous location if it exists
        _ = delete()
        guard let data = try? JSONEncoder().encode(location) else {
            return false
        }
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                      kSecAttrAccount: accountKey,
                                      kSecValueData: data]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func get() -> Location? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                      kSecAttrAccount: accountKey,
                                      kSecReturnData: true,
                                      kSecMatchLimit: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(Location.self, from: data)
    }
    
    @discardableResult
    func delete() -> Bool {
        let deleteQuery: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: accountKey]
        let status = SecItemDelete(deleteQuery as CFDictionary)
        return status == errSecSuccess
    }
}


