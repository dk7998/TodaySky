//
//  CalendarView.swift
//  TodaySky
//
//  Created by 양동국 on 7/21/25.
//

import UIKit

/// 달력(캘린더) 뷰.
/// - 상단 요일 헤더, 날짜 컬렉션 뷰, 날짜 선택시 애니메이션 표시 포함.
/// - MVVM 구조 확장 및 커스텀 캘린더 뷰로 활용 가능.
/// - **공휴일 데이터는 ViewController 등 상위에서 setHolidays(_:)로 주입**
class CalendarView: UIView {
    
    // MARK: - Properties
    
    private let weekDays = ["일", "월", "화", "수", "목", "금", "토"]
    private let calendarManager = CalendarManager()
    private let collectionView: UICollectionView
    private var calendarCells: [CalendarDate] = []
    private var currentYear: Int = 0
    private var currentMonth: Int = 0
    private var holidays: [Holiday] = []
    private var selectedIndexPath: IndexPath?
    private var selectedDate: Date?
    
    // 요일 헤더 스택
    private lazy var weekStack: UIStackView = {
        let labels = weekDays.map { day -> UILabel in
            let label = UILabel()
            label.text = day
            label.font = .systemFont(ofSize: 18, weight: .medium)
            label.textColor = (day == "일") ? .systemRed : (day == "토") ? .systemBlue : .label
            label.textAlignment = .center
            return label
        }
        let stack = UIStackView(arrangedSubviews: labels)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    /// 날짜 표시용 DateFormatter
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd (E)"
        return formatter
    }()
    
    /// 날짜 클릭시 중앙에 표시되는 라벨(애니메이션)
    private let selectedDateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 40, weight: .bold)
        label.textColor = .systemYellow
        label.textAlignment = .center
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initializer
    
    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    /// 달력 UI 전체 구성 (요일, 날짜, 선택 라벨)
    private func setupView() {
        // 요일 헤더 추가
        addSubview(weekStack)
        
        // 캘린더 본문 컬렉션뷰 설정
        addSubview(collectionView)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CalendarDateCell.self, forCellWithReuseIdentifier: CalendarDateCell.identifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemGray6
        
        // 선택된 날짜 표시 라벨
        addSubview(selectedDateLabel)

        NSLayoutConstraint.activate([
            // 요일 헤더
            weekStack.topAnchor.constraint(equalTo: topAnchor),
            weekStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            weekStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            weekStack.heightAnchor.constraint(equalToConstant: 32),

            // 캘린더 본문
            collectionView.topAnchor.constraint(equalTo: weekStack.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // 날짜 클릭시 중앙 애니메이션 라벨
            selectedDateLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            selectedDateLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
        ])
    }
    
    // MARK: - Public Methods
    
    /// 해당 년/월 데이터로 캘린더 갱신 (공휴일 정보는 내부 holidays 배열로)
    func configure(year: Int, month: Int) {
        currentYear = year
        currentMonth = month
        updateCalendar()
    }
    
    /// 외부에서 공휴일 데이터를 주입하면 즉시 렌더링
    func setHolidays(_ holidays: [Holiday]) {
        self.holidays = holidays
        updateCalendar()
    }
    
    /// 실제 달력 날짜 배열을 생성하고 컬렉션뷰 갱신
    private func updateCalendar() {
        calendarCells = calendarManager.generateCalendarDates(year: currentYear, month: currentMonth, holidays: holidays)
        collectionView.reloadData()
    }
    
    // MARK: - Helper
    /// 날짜를 yyyy.MM.dd (E) 형식 문자열로 변환
    private func formattedDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    /// 현재 날짜 반환 (CalendarManager에서 관리하는 기준일 사용)
    /// - 목적: 앱/테스트 시점 제어를 CalendarManager에서 일괄 처리할 수 있도록 통일.
    ///   - ex) 테스트/디버깅 시 CalendarManager의 기준 날짜만 변경하면 앱 전체 날짜 일관성 유지 가능.
    /// - 실제 사용: 오늘 날짜(Date())를 반환하지만, CalendarManager를 통해 테스트·모킹에 대응할 수 있음.
    func nowDate() -> Date {
        return calendarManager.nowDate()
    }
}

// MARK: - UICollectionViewDataSource

extension CalendarView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return calendarCells.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDateCell.identifier, for: indexPath) as? CalendarDateCell else {
            return UICollectionViewCell()
        }
        let date = calendarCells[indexPath.item]
        let isSelected = (indexPath == selectedIndexPath)
        cell.configure(with: date, isSelected: isSelected)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension CalendarView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard calendarCells[indexPath.item].day != 0 else { return }
        guard collectionView.isUserInteractionEnabled else { return } // 연속 탭 방지
        collectionView.isUserInteractionEnabled = false
        
        // 기존 선택 해제
        if let previous = selectedIndexPath {
            collectionView.reloadItems(at: [previous])
        }
        
        selectedIndexPath = indexPath
        selectedDate = calendarCells[indexPath.item].date
        collectionView.reloadItems(at: [indexPath])
        
        if let date = selectedDate {
            selectedDateLabel.text = formattedDate(date)
            selectedDateLabel.alpha = 0
            UIView.animate(withDuration: 0.3) {
                self.selectedDateLabel.alpha = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                UIView.animate(withDuration: 0.5) {
                    self.selectedDateLabel.alpha = 0
                } completion: { _ in
                    if let selected = self.selectedIndexPath {
                        self.selectedIndexPath = nil
                        self.collectionView.reloadItems(at: [selected])
                    }
                    self.collectionView.isUserInteractionEnabled = true // 항상 복구
                }
            }
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CalendarView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width / 7
        return CGSize(width: width, height: width)
    }
}
