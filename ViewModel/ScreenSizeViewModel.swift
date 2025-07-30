//
//  Untitled.swift
//  TodaySky
//
//  Created by 양동국 on 7/23/25.
//

import UIKit

enum DeviceSizeClass {
    case small
    case normal
    case big
}

/// 기기 화면의 최소 변(width/height 기준)으로 사이즈 그룹(small, normal, big)을 판별하고
/// UI 요소 크기, 폰트 사이즈, 이미지 크기 등 레이아웃 관련 값을 자동으로 반환하는 ViewModel
class ScreenSizeViewModel {
    
    // MARK: - Properties
    
    private static let defaultPPI: CGFloat = 326 // iPhone Retina 기본 ppi
    private static let smallWidthLimit: CGFloat = 380 // iPhone SE 등 스몰 기기 기준
    private static let normalWidthLimit: CGFloat = 420 // 일반 iPhone 기준
    
    private let minScreenSide: CGFloat
    private let screenScale: CGFloat
    private let screenPPI: CGFloat
    
    // MARK: - Initializer
    
    init(ppi: CGFloat? = nil) {
        self.minScreenSide = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        self.screenScale = UIScreen.main.scale
        self.screenPPI = ppi ?? Self.defaultPPI
    }
    
    // MARK: - Size Class Logic
    
    var sizeClass: DeviceSizeClass {
        switch minScreenSide {
        case ..<Self.smallWidthLimit:    return .small
        case ..<Self.normalWidthLimit:   return .normal
        default:                         return .big
        }
    }
    
    // MARK: - UI Metrics
    
    /// 가로모드에서 mainStack을 좌측 치우치게 할 때 사용하는 multiplier (세로: 1.0, 가로: 0.48~0.55)
    var mainStackCenterXMultiplier: CGFloat {
        switch sizeClass {
        case .small:    return 0.45
        default:        return 0.55
        }
    }
    
    var tempFontSize: CGFloat {
        switch sizeClass {
        case .small:    return 17
        default:        return 20
        }
    }
    
    var iconSpacing: CGFloat {
        switch sizeClass {
        case .small:    return 70
        default:        return 65
        }
    }
    
    var iconSize: CGFloat {
        switch sizeClass {
        case .small:    return 80
        case .normal:   return 90
        case .big:      return 110
        }
    }
    
    var timeFontSize: CGFloat {
        switch sizeClass {
        case .small:    return 90
        case .normal:   return 100
        case .big:      return 110
        }
    }
    
    var dateFontSize: CGFloat {
        switch sizeClass {
        case .small:    return 35
        case .normal:   return 40
        case .big:      return 45
        }
    }
    
    // MARK: - Helper
    /// 기기의 화면 최소 변 기준 인치 단위 (ppi 기반, UI 세부 조정용)
    private var physicalWidthInInches: CGFloat {
        return (minScreenSide / screenScale) / screenPPI
    }
}
