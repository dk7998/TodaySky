//
//   CalendarDateCell.swift
//  TodaySky
//
//  Created by 양동국 on 7/21/25.
//

import UIKit

/// 달력 날짜 셀. (오늘 표시/선택 상태 지원)
class CalendarDateCell: UICollectionViewCell {
    static let identifier = "CalendarDateCell"
    
    // MARK: - UI Constants
    private enum UI {
        static let fontSize: CGFloat = 16
        static let circleDiameter: CGFloat = 36
        static let circleCornerRadius: CGFloat = circleDiameter / 2
        static let selectedBgAlpha: CGFloat = 0.2
        static let cellCornerRadius: CGFloat = 8
    }
    
    // 날짜 라벨
    private let dayLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: UI.fontSize, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 오늘(오늘 날짜) 표시용 원형 뷰
    private let circleView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemRed.withAlphaComponent(0.8)
        view.layer.cornerRadius = UI.circleCornerRadius
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(circleView)
        contentView.addSubview(dayLabel)
        
        NSLayoutConstraint.activate([
            circleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            circleView.widthAnchor.constraint(equalToConstant: UI.circleDiameter),
            circleView.heightAnchor.constraint(equalToConstant: UI.circleDiameter),
            
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        dayLabel.text = ""
        dayLabel.textColor = .label
        circleView.isHidden = true
        contentView.backgroundColor = .clear
    }
    
    /// 셀 구성 (날짜/선택 상태)
    func configure(with date: CalendarDate, isSelected: Bool = false) {
        if date.day == 0 {
            dayLabel.text = ""
            circleView.isHidden = true
            contentView.backgroundColor = .clear
            return
        }
        
        dayLabel.text = "\(date.day)"
        circleView.isHidden = !date.isToday
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date.date) // 1=일, 7=토
        
        // 오늘(원형)일 때는 글자색을 흰색(혹은 .background에 따라 다르게)
        if date.isToday {
            dayLabel.textColor = .white
        }
        // 오늘이 아닌 공휴일/일요일: 빨간색
        else if date.isHoliday || weekday == 1 {
            dayLabel.textColor = .systemRed
        }
        // 평일(해당 월) → 검정, 다른 월 → 연회색
        else {
            dayLabel.textColor = date.isCurrentMonth ? .label : .lightGray
        }
        
        contentView.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(UI.selectedBgAlpha) : .clear
        contentView.layer.cornerRadius = UI.cellCornerRadius
        
    }
}
