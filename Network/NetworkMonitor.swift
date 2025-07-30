//
//  NetworkMonitor.swift
//  TodaySky
//
//  Created by 양동국 on 7/28/25.
//

import Network
import Foundation

// MARK: - API 실패 사유 정의 (공통)
enum APIError: Error {
    case network         // 네트워크 장애(오프라인 등)
    case parsing         // 데이터 구조 파싱 실패
    case unauthorized    // 권한/인증 실패 (위치, 인증 등)
    //case server(String?) // 서버에서 내려준 에러 메시지
    case unknown         // 알 수 없는 기타 에러
}

/// 네트워크 연결 상태를 실시간 감지 및 브로드캐스트하는 싱글톤 클래스.
/// - iOS 12+ NWPathMonitor 기반으로 동작
/// - delegate, NotificationCenter 모두 지원(선택 사용)
/// - isConnected로 현재 연결 상태 확인 가능
/// - 사용 예: API 요청 전 연결 확인, 오프라인시 UI 처리 등
///
/// 예시 사용법:
///     NetworkMonitor.shared.isConnected
///     NetworkMonitor.shared.delegate = self
///     NotificationCenter.default.addObserver(...)
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global()
    private(set) var isConnected: Bool = true
    
    // 상태 변화시 노티피케이션
    static let networkChanged = Notification.Name("NetworkChangedNotification")
    
    // 네트워크 상태 변경을 알릴 delegate (옵셔널)
    weak var delegate: NetworkMonitorDelegate?
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                let prev = self.isConnected
                self.isConnected = connected
                
                // 바뀌었을 때만 이벤트 발생
                if prev != connected {
                    // Notification
                    NotificationCenter.default.post(
                        name: NetworkMonitor.networkChanged,
                        object: nil,
                        userInfo: ["isConnected": connected]
                    )
                    // delegate
                    self.delegate?.networkStatusChanged(isConnected: connected)
                }
            }
        }
        monitor.start(queue: queue)
    }
}

protocol NetworkMonitorDelegate: AnyObject {
    func networkStatusChanged(isConnected: Bool)
}
