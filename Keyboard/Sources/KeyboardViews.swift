import UIKit

// MARK: - 键盘 UI 组件工厂
//
// 键盘扩展内存上限 ~60-70MB，全部用系统 UIKit 控件、无第三方依赖、无图片资源；
// 颜色走动态 UIColor 支持深色模式。

enum KB {
    // 品牌色：主操作、意图徽章
    static let brand = UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.62, green: 0.62, blue: 0.95, alpha: 1)
            : UIColor(red: 0.36, green: 0.36, blue: 0.84, alpha: 1)
    }
    static let bg = UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.11, alpha: 1) : UIColor(white: 0.956, alpha: 1)
    }
    static let card = UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : .white
    }
    static let cardBorder = UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.28, alpha: 1) : UIColor(white: 0.87, alpha: 1)
    }
    static let primaryText = UIColor { t in
        t.userInterfaceStyle == .dark ? .white : UIColor(white: 0.1, alpha: 1)
    }
    static let secondaryText = UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.65, alpha: 1) : UIColor(white: 0.45, alpha: 1)
    }

    static func riskColor(_ score: Double) -> UIColor {
        switch score {
        case ..<3: return .systemGreen
        case ..<6: return .systemYellow
        case ..<8: return .systemOrange
        default: return .systemRed
        }
    }

    static func cardView() -> UIView {
        let v = UIView()
        v.backgroundColor = card
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = cardBorder.cgColor
        return v
    }

    static func label(_ text: String = "", font: UIFont = .systemFont(ofSize: 14),
                      color: UIColor = primaryText, lines: Int = 0,
                      alignment: NSTextAlignment = .natural) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.numberOfLines = lines
        l.textAlignment = alignment
        return l
    }

    static func button(_ title: String, icon: String? = nil, primary: Bool = false,
                       font: UIFont = .systemFont(ofSize: 15, weight: .semibold)) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = font
            return out
        }
        if let icon {
            config.image = UIImage(systemName: icon)
            config.imagePadding = 6
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        }
        if primary {
            config.baseBackgroundColor = brand
            config.baseForegroundColor = .white
        } else {
            config.baseBackgroundColor = UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: 0.12) : UIColor(white: 0, alpha: 0.06)
            }
            config.baseForegroundColor = primaryText
        }
        config.cornerStyle = .medium
        let b = UIButton(configuration: config)
        return b
    }

    /// 小圆角徽章：意图、话术、风险。
    /// 横向必须按内容 hug——放进横向 stack 时，默认的 .fill 会把多余宽度分给
    /// hugging 最低的那个 label，徽章就会被拉成整行宽、把正文挤没。
    static func badge(_ text: String, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = "  \(text)  "
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = color
        l.layer.cornerRadius = 5
        l.layer.borderWidth = 1
        l.layer.borderColor = color.withAlphaComponent(0.5).cgColor
        l.backgroundColor = color.withAlphaComponent(0.1)
        l.clipsToBounds = true
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        l.sizeToFit()
        return l
    }
}

// MARK: - 候选行

/// 一行候选：话术徽章 + 正文 +（可选）排序概率。点按整行插入。
final class CandidateRow: UIControl {
    let candidate: Candidate
    var onInsert: ((Candidate) -> Void)?

    init(candidate: Candidate) {
        self.candidate = candidate
        super.init(frame: .zero)

        let language = JevStore.loadLanguage()
        let chip = KB.badge(localizedToneName(candidate.tone, language: language), color: KB.brand)
        chip.font = .systemFont(ofSize: 11, weight: .medium)

        let text = KB.label(candidate.text, font: .systemFont(ofSize: 14), lines: 2)

        let trailing = KB.label(
            candidate.prob.map { String(format: "%.0f%%", $0 * 100) }
                ?? jevLocalized(language, zh: "点按插入", en: "Tap to insert"),
            font: .systemFont(ofSize: 11),
            color: KB.secondaryText
        )
        trailing.setContentHuggingPriority(.required, for: .horizontal)

        let hstack = UIStackView(arrangedSubviews: [chip, text, trailing])
        hstack.axis = .horizontal
        hstack.spacing = 6
        hstack.alignment = .center
        hstack.isLayoutMarginsRelativeArrangement = true
        hstack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)

        addSubview(hstack)
        hstack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hstack.topAnchor.constraint(equalTo: topAnchor),
            hstack.bottomAnchor.constraint(equalTo: bottomAnchor),
            hstack.leadingAnchor.constraint(equalTo: leadingAnchor),
            hstack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        backgroundColor = KB.card
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = KB.cardBorder.cgColor

        // 插入走点按手势，而不是 control 的 touchUpInside：
        // 候选行在滚动视图里，手指哪怕只挪几个点，滚动视图的 pan 就会开始识别并取消
        // control 的触摸追踪——touchUpInside 永远不来，表现就是"点了完全没反应"。
        // 手势识别器与 pan 并存：干净的点击由它兜住，真拖动则原样交给滚动。
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))

        // 高亮仍由 control 的触摸状态驱动（取消时 up() 会兜底复原）
        addTarget(self, action: #selector(down), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(up), for: [.touchDragExit, .touchCancel, .touchUpInside])
    }

    @objc private func tapped() {
#if DEBUG
        JevStore.diag("候选行 tapped（手势）：话术=\(candidate.tone) 字数=\(candidate.text.count)")
#endif
        onInsert?(candidate)
    }
    @objc private func down() {
#if DEBUG
        JevStore.diag("候选行 touchDown")
#endif
        backgroundColor = KB.brand.withAlphaComponent(0.15)
    }
    @objc private func up() { backgroundColor = KB.card }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
