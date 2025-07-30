//
//   CalendarManager.swift
//  TodaySky
//
//  Created by 양동국 on 7/21/25.
//
import Foundation

/// 달력 한 셀에 표시될 날짜 정보 구조체
struct CalendarDate {
    let date: Date
    let day: Int
    let isToday: Bool
    let isCurrentMonth: Bool
    let isHoliday: Bool    // ← 공휴일 여부 추가
    let holidayName: String? // ← 공휴일 이름(예: "삼일절") 추가
}

/// 달력 생성 매니저
/// - 연/월 기준으로, 공휴일 배열 반영 달력 1차원 배열 생성 담당
class CalendarManager {
    
    private let calendar = Calendar.current
    
    /// 한국 공휴일 데이터 전용 포맷
    private lazy var dateFormatterYYYYMMDD: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
    
    /// 현재 날짜(Date) 반환
    /// - 실제 배포 시: 시스템의 현재 날짜(Date()) 반환
    /// - 테스트/디버깅 시: 특정 날짜를 반환하도록 주석을 해제하여 테스트 데이터로 활용 가능
    ///   - ex) `return Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 1))!`
    /// - 앱 전역에서 "오늘" 기준이 바뀌더라도 CalendarManager만 수정하면 됨
    func nowDate() -> Date {
        // 테스트: 특정 날짜로 고정할 때 아래 주석을 해제
        //return Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 1, hour: 10, minute: 11))!
        return Date()
    }
    
    /// 특정 년/월의 달력 배열(앞 공백 포함) 생성
    /// - Parameter holidays: YYYYMMDD Int 배열 (공휴일)
    /// - Returns: 달력 셀 1차원 배열(CalendarDate)
    func generateCalendarDates(year: Int, month: Int, holidays: [Holiday]) -> [CalendarDate] {
        var dates: [CalendarDate] = []
        
        guard let firstDayOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)
        else {
            return dates
        }
        
        let totalDays = range.count
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) // 1 = Sunday
        
        // 달력 앞부분(첫째주) 공백 채우기
        for _ in 1..<firstWeekday {
            dates.append(createEmptyDate())
        }
        
        // 해당 월의 실제 날짜 정보
        for day in 1...totalDays {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                let isToday = calendar.isDateInToday(date)
                let holiday = holidays.first { $0.locdate == Int(dateString(date)) }
                let isHoliday = (holiday != nil)
                let holidayName = holiday?.dateName
                let calendarDate = CalendarDate(
                    date: date,
                    day: day,
                    isToday: isToday,
                    isCurrentMonth: true,
                    isHoliday: isHoliday,
                    holidayName: holidayName
                )
                dates.append(calendarDate)
            }
        }
        
        return dates
    }
    /// 날짜 String 변환
    private func dateString(_ date: Date) -> String {
        return dateFormatterYYYYMMDD.string(from: date)
    }
    
    /// 달력 공백(이전/다음달 자리)용 빈 데이터 생성
    private func createEmptyDate() -> CalendarDate {
        let placeholderDate = Date.distantPast
        return CalendarDate(date: placeholderDate, day: 0, isToday: false, isCurrentMonth: false, isHoliday: false, holidayName: nil)
    }
    
    /// 오늘 날짜(year, month, day) 반환
    func todayDateComponents() -> (year: Int, month: Int, day: Int) {
        let now = nowDate()
        let comps = calendar.dateComponents([.year, .month, .day], from: now)
        return (comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
