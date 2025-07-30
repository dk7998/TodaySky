//
//  WeatherViewModel.swift
//  TodaySky
//
//  Created by 양동국 on 7/23/25.
//

import Foundation
import CoreLocation

// MARK: - Data Models

struct WeatherData: Decodable {
    let fcstDate: String
    let fcstTime: String
    let category: String
    let fcstValue: String
}

struct WeatherAPIResponse: Decodable {
    let response: Response
    struct Response: Decodable {
        let body: Body
        struct Body: Decodable {
            let items: Items
            struct Items: Decodable {
                let item: [WeatherData]
            }
        }
    }
}

// MARK: - Delegate Protocol
/// 날씨 정보 갱신 및 오류를 ViewController에 전달하는 델리게이트
protocol WeatherViewModelDelegate: AnyObject {
    func weatherViewModelDidUpdate(_ viewModel: WeatherViewModel)
    func weatherViewModel(_ viewModel: WeatherViewModel, didFailWithReason error: APIError)
}

// MARK: - ViewModel

/// 기상청 단기예보 OpenAPI를 사용해 위치 기반 날씨 정보를 제공하는 뷰모델.
/// CLLocationManager로 사용자의 현재 위치를 받아오고, 네트워크 통신 및 파싱 후 delegate로 결과를 전달함.
/// - 위치 권한 흐름, Info.plist 내 서비스키, 데이터 파싱 및 에러 처리까지 포함
class WeatherViewModel: NSObject, CLLocationManagerDelegate {
    // MARK: - Properties
    
    weak var delegate: WeatherViewModelDelegate?
    private let locationManager = CLLocationManager()
    
    // 현재값
    var temperature: String = "--"
    private(set) var humidity: String = "--"
    private(set) var iconName: String = "questionmark.circle"
    
    // 6시간 후 예보값
    private(set) var nextTemperature: String = "--"
    private(set) var nextHumidity: String = "--"
    private(set) var nextIconName: String = "questionmark.circle"
    
    // MARK: - API Key 보안: Info.plist에서 불러오기
    private var serviceKey: String {
        guard let key = Bundle.main.infoDictionary?["WeatherServiceKey"] as? String else {
            fatalError("WeatherServiceKey가 Info.plist에 설정되어 있지 않습니다.")
        }
        return key
    }
    
    // MARK: - Computed Properties
    
    var temperatureInt: String {
        temperature.split(separator: ".").first.map { String($0) } ?? temperature
    }
    var nextTemperatureInt: String {
        nextTemperature.split(separator: ".").first.map { String($0) } ?? nextTemperature
    }
    
    
    
    // MARK: - Init
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    // MARK: - Public Methods
    /// 위치 권한 요청 및 날씨 정보 요청 트리거
    func requestWeather() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else {
            delegate?.weatherViewModel(self, didFailWithReason: .unauthorized)
        }
    }
    
    
    // MARK: - CLLocationManagerDelegate
    /// 위치 정보 업데이트 성공 시(최신 위치 1개만 사용)
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        // 위도/경도 → 기상청 API용 nx,ny 그리드 좌표로 변환
        let (nx, ny) = Self.convertToGrid(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        // 네트워크로 예보 데이터 요청
        fetchForecastWeather(nx: nx, ny: ny)
    }
    /// 위치 정보 획득 실패(권한 거부/에러 등)
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 위치 권한 에러 → delegate로 ViewController에 전달
        delegate?.weatherViewModel(self, didFailWithReason: .unauthorized)
    }
    
    
    // MARK: - Static Utilities
    /// 위경도 → 기상청 nx/ny 변환
    static func convertToGrid(lat: Double, lon: Double) -> (Int, Int) {
        let RE: Double = 6371.00877, GRID: Double = 5.0
        let SLAT1: Double = 30.0, SLAT2: Double = 60.0
        let OLON: Double = 126.0, OLAT: Double = 38.0
        let XO: Double = 43.0, YO: Double = 136.0
        let DEGRAD = Double.pi / 180.0
        let re = RE / GRID
        let slat1 = SLAT1 * DEGRAD, slat2 = SLAT2 * DEGRAD
        let olon = OLON * DEGRAD, olat = OLAT * DEGRAD
        let sn = log(cos(slat1) / cos(slat2)) / log(tan(.pi * 0.25 + slat2 * 0.5) / tan(.pi * 0.25 + slat1 * 0.5))
        let sf = pow(tan(.pi * 0.25 + slat1 * 0.5), sn) * cos(slat1) / sn
        let ro = re * sf / pow(tan(.pi * 0.25 + olat * 0.5), sn)
        let ra = re * sf / pow(tan(.pi * 0.25 + (lat * DEGRAD) * 0.5), sn)
        var theta = lon * DEGRAD - olon
        if theta > .pi { theta -= 2.0 * .pi }
        if theta < -.pi { theta += 2.0 * .pi }
        theta *= sn
        let nx = Int(ra * sin(theta) + XO + 0.5)
        let ny = Int(ro - ra * cos(theta) + YO + 0.5)
        return (nx, ny)
    }
    
    /// Converts KMA weather codes (SKY/PTY) to SF Symbol icon name for iOS display.
    /// - 한국 기상청 SKY/PTY 코드를 기반으로 iOS용 SF Symbol 아이콘 이름 반환
    /// - Parameters:
    ///   - sky: SKY 코드 ("1": 맑음, "3": 구름많음, "4": 흐림)
    ///   - pty: PTY 코드 ("0": 없음, "1": 비, "2": 비/눈, "3": 눈, "4": 소나기, "5~7": 특수)
    /// - Returns: SF Symbols 아이콘 이름(e.g., "cloud.rain.fill")
    static func iconSFName(sky: String, pty: String) -> String {
        if let ptyVal = Int(pty), ptyVal > 0 {
            switch ptyVal {
            case 1, 5: return "cloud.rain.fill"
            case 2, 6: return "cloud.sleet.fill"
            case 3, 7: return "snowflake"
            case 4:    return "cloud.heavyrain.fill"
            default:   return "cloud.rain.fill"
            }
        }
        switch sky {
        case "1": return "sun.max.fill"       // 맑음
        case "3": return "cloud.fill"         // 구름많음
        case "4": return "cloud.sun.fill"     // 흐림
        default:  return "questionmark.circle"
        }
    }
    
    // MARK: - Utility Methods
    /// 기상청 단기예보 API 호출용 기준 날짜/시간 반환
    /// - 45분 전 규칙, 2~23시만 baseTime, 0/1시는 전날 23시로 처리.
    /// - 예보 데이터는 [2, 5, 8, 11, 14, 17, 20, 23]시 기준으로만 제공됩니다.
    private func getBaseDateTime(now: Date = Date()) -> (baseDate: String, baseTime: String) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let baseTimes = [2, 5, 8, 11, 14, 17, 20, 23]
        let nowHour = calendar.component(.hour, from: now)
        let nowMinute = calendar.component(.minute, from: now)
        var target = now
        var hour = nowHour
        if nowMinute < 45 {
            target = calendar.date(byAdding: .hour, value: -1, to: now)!
            hour = calendar.component(.hour, from: target)
        }
        let baseHour = baseTimes.last(where: { hour >= $0 }) ?? 23
        var baseDate = formatter.string(from: target)
        if hour < 2 && baseHour == 23 {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: target)!
            baseDate = formatter.string(from: yesterday)
        }
        let baseTime = String(format: "%02d00", baseHour)
        return (baseDate, baseTime)
    }
    
    /// 예보 항목 배열에서 sky/pty 값을 추출하여 SF Symbol 아이콘 이름으로 반환
    /// - Parameters:
    ///   - items: 날씨 예보 데이터 배열
    ///   - date: (옵션) 예보 기준 날짜 (yyyyMMdd)
    ///   - time: (옵션) 예보 기준 시간 (HHmm)
    /// - Returns: 아이콘 이름 (e.g., "cloud.rain.fill")
    private static func extractIcon(from items: [WeatherData], date: String? = nil, time: String? = nil) -> String {
        let filteredItems: [WeatherData]

        if let date = date, let time = time {
            filteredItems = items.filter { $0.fcstDate == date && $0.fcstTime == time }
        } else {
            filteredItems = items
        }

        let sky = filteredItems.first { $0.category == "SKY" }?.fcstValue ?? "--"
        let pty = filteredItems.first { $0.category == "PTY" }?.fcstValue ?? "--"
        return iconSFName(sky: sky, pty: pty)
    }
    
    /// 예보 아이템 배열에서 6시간 뒤 temp/humi/icon 추출
    private func forecastAfter6Hours(from items: [WeatherData]) -> (temp: String?, humi: String?, icon: String) {
        guard let first = items.first else { return (nil, nil, "questionmark.circle") }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        guard let startDate = formatter.date(from: first.fcstDate + first.fcstTime) else { return (nil, nil, "questionmark.circle") }
        let targetDate = Calendar.current.date(byAdding: .hour, value: 6, to: startDate)!
        let targetDateStr = formatter.string(from: targetDate)
        let targetFcstDate = String(targetDateStr.prefix(8))
        let targetFcstTime = String(targetDateStr.suffix(4))
        let temp = items.first { $0.fcstDate == targetFcstDate && $0.fcstTime == targetFcstTime && ($0.category == "TMP" || $0.category == "T1H") }?.fcstValue
        let humi = items.first { $0.fcstDate == targetFcstDate && $0.fcstTime == targetFcstTime && $0.category == "REH" }?.fcstValue
        let icon = Self.extractIcon(from: items, date: targetFcstDate, time: targetFcstTime)
        return (temp, humi, icon)
    }
    
    // MARK: - Network
    
    private func fetchForecastWeather(nx: Int, ny: Int) {
        let (baseDate, baseTime) = getBaseDateTime()
        let urlString = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst?serviceKey=\(serviceKey)&numOfRows=100&pageNo=1&dataType=JSON&base_date=\(baseDate)&base_time=\(baseTime)&nx=\(nx)&ny=\(ny)"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.delegate?.weatherViewModel(self, didFailWithReason: .unknown)
            }
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            if error != nil {
                // 네트워크 장애 구분 (실제로 더 세밀하게 하고 싶으면 error코드 분기)
                DispatchQueue.main.async {
                    self.delegate?.weatherViewModel(self, didFailWithReason: .network)
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.delegate?.weatherViewModel(self, didFailWithReason: .network)
                }
                return
            }
            guard let decoded = try? JSONDecoder().decode(WeatherAPIResponse.self, from: data) else {
                DispatchQueue.main.async {
                    self.delegate?.weatherViewModel(self, didFailWithReason: .parsing)
                }
                return
            }
            // 데이터 정상 파싱 및 저장
            let items = decoded.response.body.items.item
            let currTemp = items.first { $0.category == "TMP" || $0.category == "T1H" }?.fcstValue
            let currHumi = items.first { $0.category == "REH" }?.fcstValue
            self.iconName = Self.extractIcon(from: items)
            self.temperature = currTemp ?? "--"
            self.humidity = currHumi ?? "--"
            let (nextTemp, nextHumi, nextIconName) = self.forecastAfter6Hours(from: items)
            self.nextTemperature = nextTemp ?? "--"
            self.nextHumidity = nextHumi ?? "--"
            self.nextIconName = nextIconName
            
            DispatchQueue.main.async {
                self.delegate?.weatherViewModelDidUpdate(self)
            }
        }.resume()
    }
    
}
