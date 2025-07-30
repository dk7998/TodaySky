//
//  HolidayViewModelTests.swift
//  TodaySky
//
//  Created by 양동국 on 7/29/25.
//

// Tests/HolidayViewModelTests.swift
import XCTest
@testable import TodaySky

final class HolidayViewModelTests: XCTestCase {

    // 예시: 월별 캐시 구조 테스트
    func testHolidayCache() {
        let vm = HolidayViewModel()
        let testHoliday = Holiday(dateName: "테스트휴일", locdate: 20250717)
        vm.holidayCache["202507"] = [testHoliday]
        XCTAssertEqual(vm.holidayCache["202507"]?.first?.dateName, "테스트휴일")
    }
}
