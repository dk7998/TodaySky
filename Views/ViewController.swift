//
//  Untitled.swift
//  TodaySky
//
//  Created by 양동국 on 7/23/25.
//

import UIKit

/// 메인 시계/달력 뷰 컨트롤러
///
/// - 역할: 시간, 날짜, 온도, 날씨 아이콘 등 주요 정보를 상단에 표시하고,
///   하단에 커스텀 달력(CalendarView)을 표시.
/// - 특징:
///   - 기기 화면 크기에 따라 레이아웃, 폰트, 아이콘 크기 자동 조정(ScreenSizeViewModel 사용)
///   - 분/월 단위 자동 갱신(타이머 활용)
///   - 가로/세로 회전 및 기기 대응 레이아웃(오토레이아웃)
/// - 주요 컴포넌트:
///   - 시계, 날짜, 온도/습도, 날씨 아이콘(Label/UIImageView)
///   - 스택뷰 및 커스텀 캘린더 뷰
///   - 다국어, iPhone SE 등 소형 기기 지원
class ViewController: UIViewController {
    // MARK: - Properties
    
    private var margin: CGFloat = 20
    private let sizeModel = ScreenSizeViewModel()
    private let weatherVM = WeatherViewModel()
    private let holidayVM = HolidayViewModel()
    private let timeLabel = UILabel()
    private let dateLabel = UILabel()
    private let tempLabel1 = UILabel()
    private let tempLabel2 = UILabel()
    private let weatherIcon1 = UIImageView()
    private let weatherIcon2 = UIImageView()
    private let calendarView = CalendarView()
    private var calendarTopConstraint: NSLayoutConstraint?
    private var calendarTrailingConstraint: NSLayoutConstraint?
    private var mainLeadingConstraint: NSLayoutConstraint?
    private var mainTopConstraint: NSLayoutConstraint?
    private var timer: Timer?
    
    // 네트워크 연결 감지 재시도
    private var networkRetryCount = 0
    // 날씨 API 재시도
    private var weatherRetryCount = 0
    // 공휴일 API 재시도
    private var holidayRetryCount = 0
    // 최대 재시도 횟수
    private let maxRetries = 3
    // 5분후 재시도 딜레이
    private let retryDelay: TimeInterval = 5 * 60
    
    private var lastMinute: Int? = nil
    private var lastDay: Int? = nil
    private var lastMonth: Int? = nil
    private var lastYear: Int? = nil
    private var lastWeatherDate: Date?
    private var isClockStarted = false
    private var didShowNetworkAlert = false
    
    // 현재 날씨 예보 아이콘+온도 표시
    private lazy var currentWeatherStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [weatherIcon1, tempLabel1])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // 6시간 뒤 날씨 예보 아이콘+온도 표시
    private lazy var nextWeatherStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [weatherIcon2, tempLabel2])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // 날씨 아이콘 가로 스택
    private lazy var weatherRowStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [currentWeatherStack, nextWeatherStack])
        stack.axis = .horizontal
        stack.spacing = sizeModel.iconSpacing
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // 시간 날짜 날씨 스택
    private lazy var mainStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            timeLabel,
            dateLabel,
            weatherRowStack
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        stack.setCustomSpacing(30, after: dateLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // 캘린더 크기 고정
    private var calendarWidth: CGFloat {
        min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) - (margin * 2)
    }
    private var calendarHeight: CGFloat {
        let cellSize = calendarWidth / 7
        return (cellSize * 6) + 32
    }
    
    // MARK: - Initializer
    override func viewDidLoad() {
        super.viewDidLoad()
        if sizeModel.sizeClass == .small {
            margin = 6
        }
        
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .systemBackground
        
        NetworkMonitor.shared.delegate = self
        weatherVM.delegate = self
        holidayVM.delegate = self
        setupViews()
        startClock()
        addAppLifecycleObservers()
        
    }
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification
    // 앱 백그라운드/포그라운드 진입 시 타이머 제어를 위한 노티피케이션 등록
    private func addAppLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func appDidEnterBackground() {
        timer?.invalidate()
        timer = nil
        isClockStarted = false
    }
    
    @objc private func appWillEnterForeground() {
        startClock()
    }
    
    // MARK: - UI Setup
    private func setupViews() {
        labelMake(timeLabel)
        labelMake(dateLabel)
        labelMake(tempLabel1)
        labelMake(tempLabel2)
        imageMake(weatherIcon1)
        imageMake(weatherIcon2)
        
        tempLabel1.text = "-----"
        tempLabel2.text = "-----"
        weatherIcon1.image = UIImage(systemName: "questionmark.circle")
        weatherIcon2.image = UIImage(systemName: "questionmark.circle")
        
        // 날씨 데이터 비동기 로드 전까지 뷰 크기·레이아웃 고정을 위해
        // 초기 alpha=0(투명) 상태로 추가하여, 레이아웃 틀어짐 방지 목적
        // 데이터 수신 후 alpha=1로 노출 (자리 유지 + 자연스러운 표시)
        tempLabel1.alpha = 0
        tempLabel2.alpha = 0
        weatherIcon1.alpha = 0
        weatherIcon2.alpha = 0
        
        let overlayLabel = PaddingLabel()
        overlayLabel.inset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        overlayLabel.text = "+6h"
        overlayLabel.font = .systemFont(ofSize: 15, weight: .bold)
        overlayLabel.textColor = .white
        overlayLabel.backgroundColor = .red
        overlayLabel.layer.cornerRadius = 7
        overlayLabel.clipsToBounds = true
        overlayLabel.textAlignment = .center
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        let angle: CGFloat = -(.pi / 6) // -30도(라디안)
        overlayLabel.layer.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        
        weatherIcon2.addSubview(overlayLabel)
        
        NSLayoutConstraint.activate([
            overlayLabel.topAnchor.constraint(equalTo: weatherIcon2.topAnchor, constant: -10),
            overlayLabel.leadingAnchor.constraint(equalTo: weatherIcon2.leadingAnchor, constant: -15),
            overlayLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
            overlayLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        timeLabel.font = .monospacedDigitSystemFont(ofSize: sizeModel.timeFontSize, weight: .medium)
        dateLabel.font = .systemFont(ofSize: sizeModel.dateFontSize, weight: .semibold)
        tempLabel1.font = .systemFont(ofSize: sizeModel.tempFontSize, weight: .regular)
        tempLabel2.font = .systemFont(ofSize: sizeModel.tempFontSize, weight: .regular)
        
        view.addSubview(mainStack)
        view.addSubview(calendarView)
        
        let imageSize = sizeModel.iconSize
        NSLayoutConstraint.activate([
            mainStack.widthAnchor.constraint(equalToConstant: calendarWidth),
            calendarView.widthAnchor.constraint(equalToConstant: calendarWidth),
            calendarView.heightAnchor.constraint(equalToConstant: calendarHeight),
            weatherIcon1.widthAnchor.constraint(equalToConstant: imageSize),
            weatherIcon1.heightAnchor.constraint(equalToConstant: imageSize),
            weatherIcon2.widthAnchor.constraint(equalToConstant: imageSize),
            weatherIcon2.heightAnchor.constraint(equalToConstant: imageSize),
        ])
        
        // 최초 방향에 맞는 calendarView 제약
        setCalendarViewConstraint(for: view.bounds.size)
    }
    
    private func setCalendarViewConstraint(for size: CGSize) {
        // 기존 제약 비활성화
        calendarTopConstraint?.isActive = false
        calendarTrailingConstraint?.isActive = false
        mainLeadingConstraint?.isActive = false
        mainTopConstraint?.isActive = false
        
        let isLandscape = size.width > size.height
        
        if isLandscape {
            mainTopConstraint = mainStack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            mainLeadingConstraint = NSLayoutConstraint(
                item: mainStack,
                attribute: .centerX,
                relatedBy: .equal,
                toItem: view.safeAreaLayoutGuide,
                attribute: .centerX,
                multiplier: sizeModel.mainStackCenterXMultiplier,   // SafeArea 중앙의 1/2 (왼쪽 1/4 위치)
                constant: 0
            )
            calendarTopConstraint = calendarView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            calendarTrailingConstraint = calendarView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        } else {
            mainTopConstraint = mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: margin)
            mainLeadingConstraint = mainStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin)
            calendarTopConstraint = calendarView.topAnchor.constraint(equalTo: mainStack.bottomAnchor, constant: margin*2)
            calendarTrailingConstraint = calendarView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin)
        }
        
        calendarTopConstraint?.isActive = true
        calendarTrailingConstraint?.isActive = true
        mainLeadingConstraint?.isActive = true
        mainTopConstraint?.isActive = true
    }
    
    // MARK: - Orientation Handling
    // 화면 회전 대응 (iOS 13+)
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.setCalendarViewConstraint(for: size)
            self.view.layoutIfNeeded()
        })
    }
    
    // MARK: - Timer & Auto Update
    // 시계: 분 단위 갱신
    private func startClock() {
        if isClockStarted { return }
        
        isClockStarted = true
        // 기존 타이머 해제(안전)
        timer?.invalidate()
        
        let now = calendarView.nowDate()
        let calendar = Calendar.current
        
        // lastXXX 값 초기화
        lastMinute = calendar.component(.minute, from: now)
        lastDay = calendar.component(.day, from: now)
        lastMonth = calendar.component(.month, from: now)
        
        // UI 즉시 업데이트
        updateClock(date: now)
        updateDate(date: now)
        updateCalendar(date: now)
        updateWeatherIfNeeded(now: now)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
    }
    
    // 매 1초마다 호출: 분/일/월/날씨 갱신 필요 여부 체크 및 처리
    private func timerTick() {
        let now = calendarView.nowDate()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        let minute = calendar.component(.minute, from: now)
        
        var shouldUpdateClock = false
        var shouldUpdateDate = false
        var shouldUpdateCalendar = false
        
        if minute != lastMinute {
            shouldUpdateClock = true
            if day != lastDay {
                shouldUpdateDate = true
                if month != lastMonth {
                    shouldUpdateCalendar = true
                    lastMonth = month
                }
                lastDay = day
            }
            lastMinute = minute
        }
        
        if shouldUpdateClock { updateClock(date: now) }
        if shouldUpdateDate { updateDate(date: now) }
        if shouldUpdateCalendar { updateCalendar(date: now) }
        
        // 30분마다 날씨 갱신
        updateWeatherIfNeeded(now: now)
    }
    
    private func updateWeatherIfNeeded(now: Date) {
        checkNetworkConnectionAndProceed { isConnected in
            guard isConnected else { return }
            
            // 날씨 API 재시도는 아래와 같이 분리
            self.tryWeatherRequest(now: now)
        }
    }
    
    private func tryWeatherRequest(now: Date, ignoreCooldown: Bool = false) {
        if !ignoreCooldown, let last = lastWeatherDate, now.timeIntervalSince(last) < 1800 {
            return // 쿨타임 무시가 아닐 때만 30분 제한
        }
        if weatherRetryCount < maxRetries {
            weatherVM.requestWeather()
            lastWeatherDate = now
        } else {
            // 이미 Alert는 위 네트워크에서 띄웠으므로 생략 (필요시 별도 처리)
            weatherRetryCount = 0
        }
    }
    
    private func updateClock(date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        timeLabel.text = formatter.string(from: date)
    }
    
    private func updateDate(date: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd (E)"
        dateLabel.text = formatter.string(from: date)
    }
    
    private func updateCalendar(date: Date) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        lastYear = year
        lastMonth = month
        
        checkNetworkConnectionAndProceed { isConnected in
            if isConnected {
                self.holidayRetryCount = 0
                self.holidayVM.fetchHolidays(year: year, month: month)
            }
        }
        calendarView.configure(year: year, month: month)
    }
    
    // MARK: - Network Handling
    
    func showAPIErrorAlert(_ message: String, title: String = "오류") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    // 네트워크 오류 Alert
    private func showNetworkAlertIfNeeded() {
        if didShowNetworkAlert { return }
        didShowNetworkAlert = true
        let alert = UIAlertController(title: "네트워크 오류", message: "인터넷 연결을 확인하세요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.didShowNetworkAlert = false
        })
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.presentedViewController == nil,
                  self.isViewLoaded,
                  self.view.window != nil else { return }
            self.present(alert, animated: true)
        }
    }
    
    /// 네트워크 연결 상태를 체크하고, 연결될 때까지 최대 3회 재시도 후 콜백 실행.
    /// - parameter completion: true(성공) or false(최대 재시도 실패)
    private func checkNetworkConnectionAndProceed(completion: @escaping (Bool) -> Void) {
        if NetworkMonitor.shared.isConnected {
            networkRetryCount = 0 // 성공시 카운트 초기화
            completion(true)
        } else if networkRetryCount < maxRetries {
            networkRetryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.checkNetworkConnectionAndProceed(completion: completion)
            }
        } else {
            showNetworkAlertIfNeeded()
            networkRetryCount = 0
            completion(false)
        }
    }
    
    // MARK: - Helper
    // 공통 반복 작성 코드를 함수로 통일
    private func labelMake(_ label: UILabel) {
        label.textAlignment = .center
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func imageMake(_ imgView : UIImageView) {
        //imgView.tintColor = .systemBlue
        imgView.contentMode = .scaleAspectFit
        imgView.preferredSymbolConfiguration = .preferringMulticolor()
        imgView.translatesAutoresizingMaskIntoConstraints = false
    }
    
}

// MARK: - NetworkMonitorDelegate

/// 네트워크 연결 상태 변화 감지 시 호출됨. 네트워크 복구 시 자동 재시도 로직 포함.
/// - isConnected: 연결 여부. false일 경우 네트워크 오류 알럿을 1회만 노출.
/// - 참고: 앱이 포그라운드 전환, Wi-Fi 변경 등 모든 네트워크 변화에 반응함.
extension ViewController: NetworkMonitorDelegate {
    func networkStatusChanged(isConnected: Bool) {
        if isConnected {
            networkRetryCount = 0
            weatherRetryCount = 0
            holidayRetryCount = 0
            if let lastWeatherDate = lastWeatherDate {
                updateWeatherIfNeeded(now: lastWeatherDate)
            }
            if let year = lastYear, let month = lastMonth {
                holidayVM.fetchHolidays(year: year, month: month)
            }
        } else {
            showNetworkAlertIfNeeded()
        }
    }
}

// MARK: - HolidayViewModelDelegate
// 공휴일 정보가 갱신되거나, 에러가 발생하면 이 extension에서 UI 업데이트/에러 표시
extension ViewController: HolidayViewModelDelegate {
    
    /// 공휴일 정보 정상 갱신
    func holidayViewModelDidUpdate(_ viewModel: HolidayViewModel) {
        holidayRetryCount = 0
        calendarView.setHolidays(viewModel.holidays)
    }
    
    /// 공휴일 정보 갱신 및 실패 시 재시도(최대 3회) 또는 네트워크 Alert 노출
    func holidayViewModel(_ viewModel: HolidayViewModel, didFailWithReason error: APIError) {
        switch error {
        case .network:
            // 네트워크 문제는 NetworkMonitor에서만 처리
            return
        case .parsing:
            if holidayRetryCount < maxRetries {
                holidayRetryCount += 1
                if let year = lastYear, let month = lastMonth {
                    // 1초 후 즉시 재시도 (최대 3회)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        self?.holidayVM.fetchHolidays(year: year, month: month)
                    }
                }
            } else {
                showAPIErrorAlert("공휴일 데이터 파싱 실패 (5분 후 자동 재시도)")
                holidayRetryCount = 0
                // 5분 후 쿨다운 재시도
                if let year = lastYear, let month = lastMonth {
                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                        self?.holidayVM.fetchHolidays(year: year, month: month)
                    }
                }
            }
        case .unauthorized:
            showAPIErrorAlert("공휴일 API 인증 오류")
        //case .server(let msg): showAPIErrorAlert(msg ?? "공휴일 서버 오류")
        case .unknown:
            showAPIErrorAlert("공휴일 정보 오류")
        }
    }
}


// MARK: - WeatherViewModelDelegate
// 날씨 정보가 갱신되거나, 에러가 발생하면 이 extension에서 UI 업데이트/에러 표시
extension ViewController: WeatherViewModelDelegate {
        
    /// 날씨 정보 정상 갱신
    func weatherViewModelDidUpdate(_ viewModel: WeatherViewModel) {
        // 정상 데이터 도착 시, 재시도 카운트 리셋
        weatherRetryCount = 0
        
        // 예시: UI 업데이트 (Main Thread)
        tempLabel1.text = "\(viewModel.temperatureInt)°C, \(viewModel.humidity)%"
        tempLabel2.text = "\(viewModel.nextTemperatureInt)°C, \(viewModel.nextHumidity)%"
        weatherIcon1.image = UIImage(systemName: viewModel.iconName)
        weatherIcon2.image = UIImage(systemName: viewModel.nextIconName)

        // 알파값을 처음 1로 변경(첫 호출 시)
        if tempLabel1.alpha == 0 {
            tempLabel1.alpha = 1
            tempLabel2.alpha = 1
            weatherIcon1.alpha = 1
            weatherIcon2.alpha = 1
        }
    }
    
    /// 날씨 정보 갱신 및 실패 시 재시도(최대 3회) 또는 네트워크 Alert 노출
    func weatherViewModel(_ viewModel: WeatherViewModel, didFailWithReason error: APIError) {
        switch error {
        case .network:
            // 네트워크 문제는 NetworkMonitor에서만 처리
            return
        case .parsing:
            if weatherRetryCount < maxRetries {
                weatherRetryCount += 1
                // 1초 후 재시도 (3회)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.tryWeatherRequest(now: Date(), ignoreCooldown: true)
                }
            } else {
                showAPIErrorAlert("날씨 데이터 파싱 실패 (5분 후 자동 재시도)")
                weatherRetryCount = 0
                // 5분 후 추가 재시도 (쿨다운)
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                    self?.tryWeatherRequest(now: Date(), ignoreCooldown: true)
                }
            }
        case .unauthorized:
            showAPIErrorAlert("날씨 API 인증 오류")
        //case .server(let msg): showAPIErrorAlert(msg ?? "날씨 서버 오류")
        case .unknown:
            showAPIErrorAlert("날씨 정보 오류")
        }
    }
}
