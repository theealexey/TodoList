import UIKit

final class TodoListCell: UITableViewCell {
    
    struct Configuration: Equatable {
        let title: String
        let details: String
        let dateText: String
        let isCompleted: Bool
    }
    
    static let reuseIdentifier = "TodoListCell"
    
    var onStatusToggle: (() -> Void)?
    
    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 16
        static let statusSize: CGFloat = 28
        static let contentSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 6
    }
    
    private enum Palette {
        static var accent: UIColor {
            UIColor(
                red: 1,
                green: 0.84,
                blue: 0,
                alpha: 1
            )
        }
        
        static var primaryText: UIColor {
            UIColor(white: 0.96, alpha: 1)
        }
        
        static var secondaryText: UIColor {
            UIColor(white: 0.72, alpha: 1)
        }
        
        static var completedText: UIColor {
            UIColor(white: 0.40, alpha: 1)
        }
        
        static var pendingBorder: UIColor {
            UIColor(white: 0.30, alpha: 1)
        }
        
        static var separator: UIColor {
            UIColor(white: 0.18, alpha: 1)
        }
    }
    
    private let statusButton = ExpandedHitAreaButton(
        type: .system
    )
    
    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let dateLabel = UILabel()
    private let separatorView = UIView()
    
    private lazy var textStackView = UIStackView(
        arrangedSubviews: [
            titleLabel,
            detailsLabel,
            dateLabel
        ]
    )
    
    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )
        
        configure()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        onStatusToggle = nil
        
        titleLabel.attributedText = nil
        detailsLabel.text = nil
        dateLabel.text = nil
        
        statusButton.setImage(
            nil,
            for: .normal
        )
    }
    
    func configure(
        with configuration: Configuration
    ) {
        configureStatus(
            isCompleted: configuration.isCompleted
        )
        
        configureTitle(
            configuration.title,
            isCompleted: configuration.isCompleted
        )
        
        detailsLabel.text = configuration.details
        detailsLabel.isHidden = configuration.details.isEmpty
        
        dateLabel.text = configuration.dateText
        
        let secondaryColor = configuration.isCompleted
        ? Palette.completedText
        : Palette.secondaryText
        
        detailsLabel.textColor = secondaryColor
        dateLabel.textColor = secondaryColor
    }
    
    private func configure() {
        backgroundColor = .black
        contentView.backgroundColor = .black
        selectionStyle = .none
        
        configureStatusButton()
        configureLabels()
        configureStackView()
        configureHierarchy()
        configureConstraints()
    }
    
    private func configureStatusButton() {
        statusButton.translatesAutoresizingMaskIntoConstraints =
        false
        
        statusButton.backgroundColor = .clear
        statusButton.layer.borderWidth = 1.5
        statusButton.layer.cornerRadius =
        Layout.statusSize / 2
        
        statusButton.addTarget(
            self,
            action: #selector(statusButtonTapped),
            for: .touchUpInside
        )
        
        statusButton.accessibilityLabel =
        "Изменить статус задачи"
    }
    
    @objc
    private func statusButtonTapped() {
        onStatusToggle?()
    }
    
    private func configureLabels() {
        titleLabel.font = .preferredFont(
            forTextStyle: .headline
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        
        detailsLabel.font = .preferredFont(
            forTextStyle: .subheadline
        )
        detailsLabel.adjustsFontForContentSizeCategory = true
        detailsLabel.numberOfLines = 2
        detailsLabel.lineBreakMode = .byTruncatingTail
        
        dateLabel.font = .preferredFont(
            forTextStyle: .caption1
        )
        dateLabel.adjustsFontForContentSizeCategory = true
        
        separatorView.backgroundColor = Palette.separator
    }
    
    private func configureStackView() {
        textStackView.translatesAutoresizingMaskIntoConstraints =
        false
        
        textStackView.axis = .vertical
        textStackView.alignment = .fill
        textStackView.spacing = Layout.textSpacing
    }
    
    private func configureHierarchy() {
        contentView.addSubview(statusButton)
        contentView.addSubview(textStackView)
        contentView.addSubview(separatorView)
        
        separatorView.translatesAutoresizingMaskIntoConstraints =
        false
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            statusButton.topAnchor.constraint(
                equalTo: textStackView.topAnchor
            ),
            statusButton.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            statusButton.widthAnchor.constraint(
                equalToConstant: Layout.statusSize
            ),
            statusButton.heightAnchor.constraint(
                equalToConstant: Layout.statusSize
            ),
            
            textStackView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Layout.verticalInset
            ),
            textStackView.leadingAnchor.constraint(
                equalTo: statusButton.trailingAnchor,
                constant: Layout.contentSpacing
            ),
            textStackView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            textStackView.bottomAnchor.constraint(
                equalTo: separatorView.topAnchor,
                constant: -Layout.verticalInset
            ),
            
            separatorView.leadingAnchor.constraint(
                equalTo: textStackView.leadingAnchor
            ),
            separatorView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            separatorView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor
            ),
            separatorView.heightAnchor.constraint(
                equalToConstant: 1 / UIScreen.main.scale
            )
        ])
    }
    
    private func configureStatus(
        isCompleted: Bool
    ) {
        statusButton.layer.borderColor = (
            isCompleted
            ? Palette.accent
            : Palette.pendingBorder
        ).cgColor
        
        if isCompleted {
            let configuration =
            UIImage.SymbolConfiguration(
                pointSize: 15,
                weight: .semibold
            )
            
            let image = UIImage(
                systemName: "checkmark",
                withConfiguration: configuration
            )
            
            statusButton.setImage(
                image,
                for: .normal
            )
            statusButton.tintColor = Palette.accent
        } else {
            statusButton.setImage(
                nil,
                for: .normal
            )
            statusButton.tintColor = nil
        }
    }
    
    private func configureTitle(
        _ title: String,
        isCompleted: Bool
    ) {
        let titleColor = isCompleted
        ? Palette.completedText
        : UIColor.white
        
        var attributes: [
            NSAttributedString.Key: Any
        ] = [
            .foregroundColor: titleColor
        ]
        
        if isCompleted {
            attributes[.strikethroughStyle] =
            NSUnderlineStyle.single.rawValue
            
            attributes[.strikethroughColor] =
            titleColor
        }
        
        titleLabel.attributedText =
        NSAttributedString(
            string: title,
            attributes: attributes
        )
    }
    
    private final class ExpandedHitAreaButton: UIButton {
        
        override func point(
            inside point: CGPoint,
            with event: UIEvent?
        ) -> Bool {
            guard
                isUserInteractionEnabled,
                !isHidden,
                alpha > 0.01
            else {
                return false
            }
            
            return bounds
                .insetBy(dx: -8, dy: -8)
                .contains(point)
        }
    }
}
