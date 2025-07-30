//
//  PaddingLabel.swift
//  TodaySky
//
//  Created by 양동국 on 7/24/25.
//

import UIKit

/// 좌우/상하 패딩(여백) 조절이 가능한 UILabel 커스텀 서브클래스
/// - drawText/IntrinsicContentSize 오버라이드로 Insets 적용
class PaddingLabel: UILabel {
    /// 텍스트 내부 여백 (기본 좌우 8pt)
    var inset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
    
    /// 여백(inset)만큼 줄인 영역에 텍스트 그림
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: inset))
    }
    /// intrinsicContentSize 오버라이드로, 오토레이아웃/사이즈 계산시 inset 반영
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + inset.left + inset.right,
                      height: size.height + inset.top + inset.bottom)
    }
}
