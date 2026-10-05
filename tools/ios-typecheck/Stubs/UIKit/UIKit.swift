// Type-check stub of the UIKit/CoreGraphics API subset used by iOS/FPod.
// Signatures mirror Apple's SDK; bodies are placeholders. Never shipped.
@_exported import Foundation

// MARK: CoreGraphics

public struct CGAffineTransform {
    public init() {}
    public static let identity = CGAffineTransform()
}

public enum CGLineCap: Int32 { case butt, round, square }
public enum CGLineJoin: Int32 { case miter, round, bevel }
public enum CGPathFillRule: Int { case winding, evenOdd }

open class CGColor {}
open class CGImage {}

open class CGPath {
    public init() {}
    public init(rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) {}
    public init(roundedRect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat, transform: UnsafePointer<CGAffineTransform>?) {}
    public init(ellipseIn: CGRect, transform: UnsafePointer<CGAffineTransform>?) {}
}

open class CGMutablePath: CGPath {
    public override init() { super.init() }
    public func addLines(between points: [CGPoint], transform: CGAffineTransform = .identity) {}
    public func move(to point: CGPoint, transform: CGAffineTransform = .identity) {}
    public func addLine(to point: CGPoint, transform: CGAffineTransform = .identity) {}
    public func addQuadCurve(to end: CGPoint, control: CGPoint, transform: CGAffineTransform = .identity) {}
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint, transform: CGAffineTransform = .identity) {}
    public func closeSubpath() {}
}

open class CGContext {
    public func translateBy(x: CGFloat, y: CGFloat) {}
    public func setLineCap(_ cap: CGLineCap) {}
    public func setLineJoin(_ join: CGLineJoin) {}
    public func saveGState() {}
    public func restoreGState() {}
    public func setShadow(offset: CGSize, blur: CGFloat, color: CGColor?) {}
    public func addPath(_ path: CGPath) {}
    public func setFillColor(_ color: CGColor) {}
    public func fillPath(using rule: CGPathFillRule = .winding) {}
    public func setStrokeColor(_ color: CGColor) {}
    public func setLineWidth(_ width: CGFloat) {}
    public func strokePath() {}
}

// MARK: Colors, fonts, text

open class UIColor {
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
    public var cgColor: CGColor { CGColor() }
    public class var clear: UIColor { UIColor(red: 0, green: 0, blue: 0, alpha: 0) }
}

open class UIFontDescriptor {
    public struct SystemDesign: Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let rounded = SystemDesign(rawValue: "rounded")
    }
    public func withDesign(_ design: SystemDesign) -> UIFontDescriptor? { self }
}

open class UIFont {
    public struct Weight: Hashable {
        public let rawValue: CGFloat
        public init(rawValue: CGFloat) { self.rawValue = rawValue }
        public static let regular = Weight(rawValue: 0)
        public static let medium = Weight(rawValue: 0.23)
        public static let semibold = Weight(rawValue: 0.3)
        public static let bold = Weight(rawValue: 0.4)
    }
    public init(descriptor: UIFontDescriptor, size: CGFloat) {}
    public class func systemFont(ofSize fontSize: CGFloat, weight: UIFont.Weight) -> UIFont { UIFont(descriptor: UIFontDescriptor(), size: fontSize) }
    public var fontDescriptor: UIFontDescriptor { UIFontDescriptor() }
    public var lineHeight: CGFloat { 0 }
}

extension NSAttributedString.Key {
    public static let font = NSAttributedString.Key("NSFont")
    public static let foregroundColor = NSAttributedString.Key("NSColor")
}

extension NSString {
    public func size(withAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> CGSize { .zero }
    public func draw(at point: CGPoint, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {}
}

// MARK: Image rendering

open class UIImage {
    public var cgImage: CGImage? { nil }
}

open class UIGraphicsImageRendererFormat {
    public init() {}
    public var scale: CGFloat = 1
    public var opaque: Bool = false
}

open class UIGraphicsImageRendererContext {
    public var cgContext: CGContext { CGContext() }
}

open class UIGraphicsImageRenderer {
    public init(size: CGSize, format: UIGraphicsImageRendererFormat) {}
    public func image(actions: (UIGraphicsImageRendererContext) -> Void) -> UIImage { UIImage() }
}

// MARK: Responders, views, controllers

open class UIEvent {}
open class UIPressesEvent: UIEvent {}

public enum UIKeyboardHIDUsage: Int {
    case keyboardA = 4, keyboardC = 6, keyboardD = 7, keyboardE = 8, keyboardI = 12, keyboardJ = 13, keyboardM = 16
    case keyboardR = 21, keyboardS = 22, keyboardW = 26
    case keyboardReturnOrEnter = 40, keyboardEscape = 41, keyboardSpacebar = 44, keyboardF1 = 58
    case keyboardRightArrow = 79, keyboardLeftArrow = 80, keyboardDownArrow = 81, keyboardUpArrow = 82
}

open class UIKey {
    public var keyCode: UIKeyboardHIDUsage { .keyboardA }
}

open class UIPress {
    public var key: UIKey? { nil }
}

open class UITouch {
    public var timestamp: TimeInterval { 0 }
    public func location(in view: UIView?) -> CGPoint { .zero }
}

open class UIResponder {
    public init() {}
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}
    open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
    open func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
    open func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
}

extension UITouch: Hashable {
    public static func == (a: UITouch, b: UITouch) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}
extension UIPress: Hashable {
    public static func == (a: UIPress, b: UIPress) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}

public struct UIEdgeInsets {
    public var top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0
    public init() {}
}

public struct UIRectEdge: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let all = UIRectEdge(rawValue: 15)
}

public struct UIInterfaceOrientationMask: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let landscape = UIInterfaceOrientationMask(rawValue: 24)
}

public struct UIAccessibilityTraits: OptionSet {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let button = UIAccessibilityTraits(rawValue: 1)
    public static let staticText = UIAccessibilityTraits(rawValue: 64)
}

open class UIView: UIResponder {
    public struct AutoresizingMask: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let flexibleWidth = AutoresizingMask(rawValue: 2)
        public static let flexibleHeight = AutoresizingMask(rawValue: 16)
    }
    public init(frame: CGRect) { super.init() }
    public required init?(coder: NSCoder) { super.init() }
    open var bounds: CGRect = .zero
    open var safeAreaInsets: UIEdgeInsets { UIEdgeInsets() }
    open var window: UIWindow? { nil }
    open var autoresizingMask: AutoresizingMask = []
    open var backgroundColor: UIColor?
    open var isUserInteractionEnabled: Bool = true
    open var isMultipleTouchEnabled: Bool = false
    open var contentScaleFactor: CGFloat = 2
    open var isAccessibilityElement: Bool = false
    open var accessibilityElements: [Any]?
    open func addSubview(_ view: UIView) {}
}

open class UIScreen {
    public var scale: CGFloat { 2 }
}

open class UIWindow: UIView {
    public init(windowScene: UIWindowScene) { super.init(frame: .zero) }
    public required init?(coder: NSCoder) { super.init(frame: .zero) }
    open var rootViewController: UIViewController?
    open func makeKeyAndVisible() {}
    open var screen: UIScreen { UIScreen() }
}

open class UIViewController: UIResponder {
    public override init() { super.init() }
    open var view: UIView!
    open func loadView() {}
    open func viewDidLoad() {}
    open func viewDidLayoutSubviews() {}
    open var prefersStatusBarHidden: Bool { false }
    open var prefersHomeIndicatorAutoHidden: Bool { false }
    open var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [] }
    open var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
}

// MARK: App & scene lifecycle

open class UIApplication: UIResponder {
    public struct LaunchOptionsKey: Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }
}

public protocol UIApplicationDelegate: AnyObject {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration
}

extension UIApplicationDelegate {
    public static func main() {}
}

open class UISceneSession {
    public struct Role: Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
    }
    public var role: Role { Role(rawValue: "UIWindowSceneSessionRoleApplication") }
}

open class UISceneConfiguration {
    public init(name: String?, sessionRole: UISceneSession.Role) {}
    open var delegateClass: AnyClass?
}

open class UIScene: UIResponder {
    open class ConnectionOptions {}
}

open class UIWindowScene: UIScene {}

public protocol UISceneDelegate: AnyObject {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    func sceneWillResignActive(_ scene: UIScene)
    func sceneDidEnterBackground(_ scene: UIScene)
    func sceneDidBecomeActive(_ scene: UIScene)
}

public protocol UIWindowSceneDelegate: UISceneDelegate {
    var window: UIWindow? { get set }
}

// MARK: Feedback & accessibility

open class UIImpactFeedbackGenerator {
    public enum FeedbackStyle: Int { case light, medium, heavy, soft, rigid }
    public init(style: FeedbackStyle) {}
    public func impactOccurred() {}
}

open class UINotificationFeedbackGenerator {
    public enum FeedbackType: Int { case success, warning, error }
    public init() {}
    public func notificationOccurred(_ notificationType: FeedbackType) {}
}

open class UIAccessibilityElement {
    public init(accessibilityContainer container: Any) {}
    open var accessibilityFrameInContainerSpace: CGRect = .zero
    open var accessibilityLabel: String?
    open var accessibilityHint: String?
    open var accessibilityTraits: UIAccessibilityTraits = []
    open func accessibilityActivate() -> Bool { false }
}

public enum UIAccessibility {
    public struct Notification: Hashable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let layoutChanged = Notification(rawValue: 1001)
    }
    public static var isVoiceOverRunning: Bool { false }
    public static func post(notification: Notification, argument: Any?) {}
}
