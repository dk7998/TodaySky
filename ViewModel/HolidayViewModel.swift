//
//  HolidayViewModel.swift
//  TodaySky
//
//  Created by 양동국 on 7/23/25.
//

import Foundation

// MARK: - Holiday 데이터 구조
struct Holiday: Decodable {
    let dateName: String    // 공휴일 이름
    let locdate: Int        // 날짜(YYYYMMDD)
}

// MARK: - API 응답 구조 (단일/배열 모두 지원)
struct HolidayAPIResponse: Decodable {
    let response: Response
    struct Response: Decodable {
        let body: Body
        struct Body: Decodable {
            let items: Items?
            struct Items: Decodable {
                let item: [Holiday]?
                
                // [Holiday], Holiday, null, "" 모두 대응
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    if let arr = try? container.decode([Holiday].self, forKey: .item) {
                        item = arr
                    } else if let single = try? container.decode(Holiday.self, forKey: .item) {
                        item = [single]
                    } else {
                        item = nil
                    }
                }
                enum CodingKeys: String, CodingKey { case item }
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                // "items": struct or string("") or nil 모두 대응
                if let items = try? container.decode(Items.self, forKey: .items) {
                    self.items = items
                } else {
                    self.items = nil
                }
            }
            enum CodingKeys: String, CodingKey { case items }
        }
    }
}

// MARK: - Delegate Protocol

protocol HolidayViewModelDelegate: AnyObject {
    func holidayViewModelDidUpdate(_ viewModel: HolidayViewModel)
    func holidayViewModel(_ viewModel: HolidayViewModel, didFailWithReason error: APIError)
}

// MARK: - ViewModel

/// 공휴일 OpenAPI에서 월별 공휴일 데이터를 가져와서 캐시 및 delegate로 결과를 알림
/// - Info.plist의 HolidayServiceKey 사용
/// - 에러 및 데이터 갱신을 delegate로 ViewController에 전달
class HolidayViewModel {
    // MARK: - Properties
    
    weak var delegate: HolidayViewModelDelegate?
    /// 월별 공휴일 캐시 ["202507": [Holiday], ...]
    var holidayCache: [String: [Holiday]] = [:]
    private(set) var holidays: [Holiday] = []
    
    // MARK: - API Key 보안: Info.plist에서 불러오기
    private var serviceKey: String {
        guard let key = Bundle.main.infoDictionary?["HolidayServiceKey"] as? String else {
            fatalError("HolidayServiceKey가 Info.plist에 설정되어 있지 않습니다.")
        }
        return key
    }
    
    // MARK: - API Fetch
    
    /// 연/월별 공휴일 데이터 요청 (중복 요청 시 캐시 반환)
    func fetchHolidays(year: Int, month: Int) {
        let key = "\(year)\(String(format: "%02d", month))"
        
        // 캐시 반환
        if let cached = holidayCache[key] {
            self.holidays = cached
            DispatchQueue.main.async {
                self.delegate?.holidayViewModelDidUpdate(self)
            }
            return
        }
        let urlString = "https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo?serviceKey=\(serviceKey)&solYear=\(year)&solMonth=\(String(format: "%02d", month))&_type=json"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.delegate?.holidayViewModel(self, didFailWithReason: .unknown)
            }
            return
        }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            if error != nil {
                // 네트워크 장애 구분 (실제로 더 세밀하게 하고 싶으면 error코드 분기)
                DispatchQueue.main.async {
                    self.delegate?.holidayViewModel(self, didFailWithReason: .network)
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.delegate?.holidayViewModel(self, didFailWithReason: .network)
                }
                return
            }
            guard let decoded = try? JSONDecoder().decode(HolidayAPIResponse.self, from: data) else {
                // JSON 구조가 완전히 깨졌을 때만 에러
                DispatchQueue.main.async {
                    self.delegate?.holidayViewModel(self, didFailWithReason: .parsing)
                }
                return
            }
            // 데이터 정상 파싱 및 저장
            // items 자체가 nil이거나, item 배열이 없거나, item이 nil이면 빈 배열로 처리
            let items = decoded.response.body.items?.item ?? []
            self.holidayCache[key] = items
            self.holidays = items
            DispatchQueue.main.async {
                self.delegate?.holidayViewModelDidUpdate(self)
            }
        }
        task.resume()
    }
}
