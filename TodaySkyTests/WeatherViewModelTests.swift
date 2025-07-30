//
//  WeatherViewModelTests.swift
//  TodaySky
//
//  Created by 양동국 on 7/29/25.
//

// Tests/WeatherViewModelTests.swift
import XCTest
@testable import TodaySky

final class WeatherViewModelTests: XCTestCase {

    // 예시: 온도 데이터 파싱(문자열 → 정수) 확인
    func testTemperatureInt() {
        let vm = WeatherViewModel()
        // 임의 값 대입
        vm.temperature = "27.3"
        XCTAssertEqual(vm.temperatureInt, "27")
        
        vm.temperature = "18"
        XCTAssertEqual(vm.temperatureInt, "18")
    }

    // 예시: 아이콘 변환 함수 테스트
    func testIconSFName() {
        // 맑음
        XCTAssertEqual(WeatherViewModel.iconSFName(sky: "1", pty: "0"), "sun.max.fill")
        // 비
        XCTAssertEqual(WeatherViewModel.iconSFName(sky: "1", pty: "1"), "cloud.rain.fill")
        // 구름많음
        XCTAssertEqual(WeatherViewModel.iconSFName(sky: "3", pty: "0"), "cloud.fill")
    }
}
