import UIKit

final class CreateScheduleViewController: UIViewController, UITextFieldDelegate {
    private let dayLabels = ["M", "T", "W", "TH", "F", "SA", "SU"]
    private var selectedDays: Set<Int> = []
    private var dayButtons: [UIButton] = []

    private let repeatSwitch = UISwitch()
    private let repeatStatusLabel = UILabel()
    private let fanSwitch = UISwitch()
    private let fanOnOffLabel = UILabel()
    private let fanPercentLabel = UILabel()
    private let fanSlider = UISlider()
    private let lightSwitch = UISwitch()
    private let lightOnOffLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Create Schedule"
        view.backgroundColor = FanSyncTheme.screenBackground
        setUpEggplantNavBar(self)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped)
        )

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40)
        ])

        stack.addArrangedSubview(label("Schedule Name"))
        let nameField = UITextField()
        nameField.placeholder = "My Schedule"
        nameField.font = .systemFont(ofSize: 18)
        nameField.delegate = self
        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(divider())

        let startPicker = UIDatePicker()
        startPicker.datePickerMode = .time
        let endPicker = UIDatePicker()
        endPicker.datePickerMode = .time
        if #available(iOS 13.4, *) {
            // Not reachable on iOS 12 devices; .wheels is already the iOS 12 default style.
        }

        let startStack = UIStackView(arrangedSubviews: [label("Start Time"), startPicker])
        startStack.axis = .vertical
        startStack.spacing = 8
        let endStack = UIStackView(arrangedSubviews: [label("End Time"), endPicker])
        endStack.axis = .vertical
        endStack.spacing = 8
        let timesRow = UIStackView(arrangedSubviews: [startStack, endStack])
        timesRow.axis = .horizontal
        timesRow.spacing = 20
        stack.addArrangedSubview(timesRow)
        stack.addArrangedSubview(divider())

        repeatSwitch.onTintColor = FanSyncTheme.eggplant
        repeatStatusLabel.text = "OFF"
        repeatStatusLabel.font = .systemFont(ofSize: 18, weight: .bold)
        repeatSwitch.addTarget(self, action: #selector(repeatChanged), for: .valueChanged)
        let repeatRow = UIStackView(arrangedSubviews: [label("Repeat"), UIView(), repeatStatusLabel, repeatSwitch])
        repeatRow.axis = .horizontal
        repeatRow.spacing = 8
        stack.addArrangedSubview(repeatRow)

        let daysRow = UIStackView()
        daysRow.axis = .horizontal
        daysRow.distribution = .fillEqually
        for (i, dayLabel) in dayLabels.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(dayLabel, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.setTitleColor(FanSyncTheme.onLabel, for: .normal)
            button.layer.cornerRadius = 18
            button.layer.borderWidth = 1.5
            button.layer.borderColor = UIColor.clear.cgColor
            button.tag = i
            button.addTarget(self, action: #selector(dayTapped(_:)), for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: 36).isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            daysRow.addArrangedSubview(button)
            dayButtons.append(button)
        }
        stack.addArrangedSubview(daysRow)
        stack.addArrangedSubview(divider())

        let settingsTitle = UILabel()
        settingsTitle.text = "Settings"
        settingsTitle.font = .systemFont(ofSize: 20, weight: .bold)
        settingsTitle.textAlignment = .center
        stack.addArrangedSubview(settingsTitle)

        fanSwitch.onTintColor = FanSyncTheme.eggplant
        fanOnOffLabel.text = "OFF"
        fanOnOffLabel.font = .systemFont(ofSize: 18, weight: .bold)
        fanPercentLabel.text = "--"
        fanPercentLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        fanSwitch.addTarget(self, action: #selector(fanSwitchChanged), for: .valueChanged)
        let fanRow = UIStackView(arrangedSubviews: [fanSwitch, fanOnOffLabel, UIView(), fanPercentLabel])
        fanRow.axis = .horizontal
        fanRow.spacing = 8
        stack.addArrangedSubview(fanRow)

        fanSlider.minimumValue = 0
        fanSlider.maximumValue = 100
        fanSlider.tintColor = FanSyncTheme.eggplant
        fanSlider.isEnabled = false
        fanSlider.addTarget(self, action: #selector(fanSliderChanged), for: .valueChanged)
        stack.addArrangedSubview(fanSlider)
        stack.addArrangedSubview(divider())

        lightSwitch.onTintColor = FanSyncTheme.eggplant
        lightOnOffLabel.text = "OFF"
        lightOnOffLabel.font = .systemFont(ofSize: 18, weight: .bold)
        lightSwitch.addTarget(self, action: #selector(lightSwitchChanged), for: .valueChanged)
        let lightRow = UIStackView(arrangedSubviews: [label("Light"), UIView(), lightOnOffLabel, lightSwitch])
        lightRow.axis = .horizontal
        lightRow.spacing = 8
        stack.addArrangedSubview(lightRow)
    }

    private func label(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = FanSyncTheme.onLabel
        return label
    }

    private func divider() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    @objc private func dayTapped(_ sender: UIButton) {
        if selectedDays.contains(sender.tag) {
            selectedDays.remove(sender.tag)
            sender.layer.borderColor = UIColor.clear.cgColor
        } else {
            selectedDays.insert(sender.tag)
            sender.layer.borderColor = FanSyncTheme.eggplant.cgColor
        }
    }

    @objc private func repeatChanged() {
        repeatStatusLabel.text = repeatSwitch.isOn ? "ON" : "OFF"
    }

    @objc private func fanSwitchChanged() {
        fanOnOffLabel.text = fanSwitch.isOn ? "ON" : "OFF"
        fanPercentLabel.text = fanSwitch.isOn ? "\(Int(fanSlider.value))%" : "--"
        fanSlider.isEnabled = fanSwitch.isOn
    }

    @objc private func fanSliderChanged() {
        fanPercentLabel.text = "\(Int(fanSlider.value))%"
    }

    @objc private func lightSwitchChanged() {
        lightOnOffLabel.text = lightSwitch.isOn ? "ON" : "OFF"
    }

    @objc private func doneTapped() {
        navigationController?.popViewController(animated: true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
