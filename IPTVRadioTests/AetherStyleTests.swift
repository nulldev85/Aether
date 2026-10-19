import XCTest
import UIKit
import QuartzCore
@testable import IPTVRadio

@MainActor
final class AetherStyleTests: XCTestCase {
    func testPaletteMatchesLineupReferenceExactlyInBothSystemAppearances() {
        let expected: [(UIColor, UInt32)] = [
            (AetherTheme.uiCanvas, 0x1C1C1E),
            (AetherTheme.uiNavigationSurface, 0x2C2C2E),
            (AetherTheme.uiPrimaryText, 0xFFFFFF),
            (AetherTheme.uiMutedIcon, 0x9E9EA5),
            (AetherTheme.uiAccent, 0xFF3347)
        ]
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            for (color, hex) in expected {
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                XCTAssertTrue(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: appearance))
                    .getRed(&red, green: &green, blue: &blue, alpha: &alpha))
                XCTAssertEqual(red, CGFloat((hex >> 16) & 255) / 255, accuracy: 0.0001)
                XCTAssertEqual(green, CGFloat((hex >> 8) & 255) / 255, accuracy: 0.0001)
                XCTAssertEqual(blue, CGFloat(hex & 255) / 255, accuracy: 0.0001)
                XCTAssertEqual(alpha, 1)
            }
        }
    }

    func testNavigationClearanceIncludesBothCapsulesWithoutDoubleCountingSafeArea() {
        for bottom in [CGFloat(0), 21, 34] {
            for playerHeight in [CGFloat(68), 110] {
                let gap: CGFloat = bottom > 0 ? 20 : 8
                let withPlayer = AetherNavigationLayout.reservedHeight(hasPlayer: true, playerHeight: playerHeight, safeAreaBottom: bottom)
                let withoutPlayer = AetherNavigationLayout.reservedHeight(hasPlayer: false, playerHeight: playerHeight, safeAreaBottom: bottom)
                XCTAssertEqual(withPlayer + bottom, 62 + gap + playerHeight + 8)
                XCTAssertEqual(withoutPlayer + bottom, 62 + gap)
                XCTAssertEqual(withPlayer - withoutPlayer, playerHeight + 8)
            }
        }
        XCTAssertEqual(AetherTheme.panelRadius, 24)
        XCTAssertEqual(AetherTheme.compactRadius, 14)
        XCTAssertEqual(AetherNavigationLayout.itemHeight, 54)
        XCTAssertEqual(AetherNavigationLayout.padding, 4)
    }

    func testNativeNavigationTypefaceMatchesLineupsRoundedSystemFace() {
        let actual = AetherTheme.roundedUIFont(17, .heavy)
        let system = UIFont.systemFont(ofSize: 17, weight: .heavy)
        let expected = UIFont(descriptor: system.fontDescriptor.withDesign(.rounded) ?? system.fontDescriptor, size: 17)
        XCTAssertEqual(actual.fontName, expected.fontName)
        XCTAssertEqual(actual.pointSize, 17)
    }

    func testPreservedVinylStillSpinsPausesAndResumesOneAnimation() throws {
        let disc = VinylDiscView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        disc.setSpinning(true)
        let rotation = try XCTUnwrap(disc.layer.animation(forKey: "vinylRotation") as? CABasicAnimation)
        XCTAssertEqual(rotation.keyPath, "transform.rotation.z")
        XCTAssertEqual(rotation.duration, 5.4)
        XCTAssertEqual(disc.layer.speed, 1)
        disc.setSpinning(false)
        XCTAssertEqual(disc.layer.speed, 0)
        XCTAssertNotNil(disc.layer.animation(forKey: "vinylRotation"))
        disc.setSpinning(true)
        XCTAssertEqual(disc.layer.speed, 1)
        XCTAssertEqual(disc.layer.animationKeys(), ["vinylRotation"])
    }
}
