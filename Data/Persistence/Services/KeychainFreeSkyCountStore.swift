//
//  KeychainFreeSkyCountStore.swift
//  BlueHour
//
//  무료 하늘 카운트를 키체인에 보관한다. 앱을 지웠다 다시 설치하거나 전체 기록을 삭제해도
//  유지되도록 키체인을 쓴다. (PL-OBQXIP — 카운트 보관)
//
//  접근성은 kSecAttrAccessibleAfterFirstUnlock(기기 첫 잠금 해제 후 접근 가능),
//  iCloud 동기화는 사용하지 않도록 kSecAttrSynchronizable = false로 명시한다.
//

import Foundation
import Security

final class KeychainFreeSkyCountStore: FreeSkyCountStoring {

    private let service = "academy.credo.BlueHour.freeSky"
    private let account = "freeSkyCount"

    func load() -> Int {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8),
              let value = Int(string)
        else {
            return 0
        }
        return value
    }

    func save(_ count: Int) {
        let data = Data(String(count).utf8)

        // 항목을 찾기 위한 기본 질의 (class + service + account + synchronizable)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]

        // 이미 있으면 값만 갱신한다.
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // 없으면 접근성·동기화 속성과 함께 새로 추가한다.
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    #if DEBUG
    /// 개발자 도구 전용: 키체인에 저장된 카운트 항목 자체를 삭제한다(초기화).
    func debugDeleteStored() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        SecItemDelete(query as CFDictionary)
    }
    #endif
}
