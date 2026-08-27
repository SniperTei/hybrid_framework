import UIKit

/**
 * Self-drawn container navigation bar (v3.5.0 container-nav).
 *
 * Not tied to UINavigationController — containers present as fullScreen
 * modals, so the bar is a plain UIView laid out by CoconutWebViewController:
 *
 *   left: back chevron or custom text · center: title · right: × close or
 *   custom text (right text and × are mutually exclusive — the owner decides
 *   via the refresh calls on NavConfig + canGoBack).
 */
public final class CoconutNavBarView: UIView {

    public var onLeftTap: (() -> Void)?
    public var onRightTap: (() -> Void)?

    private let leftButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let rightButton = UIButton(type: .system)

    public override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white

        leftButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        leftButton.tintColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        leftButton.contentHorizontalAlignment = .center
        leftButton.addTarget(self, action: #selector(leftTapped), for: .touchUpInside)
        leftButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftButton)

        titleLabel.text = ""
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        rightButton.setTitle("✕", for: .normal)
        rightButton.setTitleColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), for: .normal)
        rightButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        rightButton.addTarget(self, action: #selector(rightTapped), for: .touchUpInside)
        rightButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightButton)

        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0, alpha: 0.1)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            leftButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            leftButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            leftButton.heightAnchor.constraint(equalToConstant: 44),

            rightButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            rightButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            rightButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leftButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightButton.leadingAnchor, constant: -8),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Item configuration

    /// Back chevron (default left item).
    public func setLeftBack() {
        leftButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        leftButton.setTitle(nil, for: .normal)
    }

    /// Custom left text replaces the chevron.
    public func setLeftText(_ text: String) {
        leftButton.setImage(nil, for: .normal)
        leftButton.setTitle(text, for: .normal)
        leftButton.titleLabel?.font = .systemFont(ofSize: 16)
        leftButton.setTitleColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), for: .normal)
    }

    /// × close button.
    public func setRightClose() {
        rightButton.setTitle("✕", for: .normal)
        rightButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
    }

    /// Custom right action text (mutually exclusive with ×).
    public func setRightText(_ text: String) {
        rightButton.setTitle(text, for: .normal)
        rightButton.titleLabel?.font = .systemFont(ofSize: 16)
    }

    public func hideRight() {
        rightButton.setTitle(nil, for: .normal)
    }

    public func setTitle(_ text: String?) {
        titleLabel.text = text ?? ""
    }

    // MARK: - Actions

    @objc private func leftTapped() { onLeftTap?() }
    @objc private func rightTapped() { onRightTap?() }
}
