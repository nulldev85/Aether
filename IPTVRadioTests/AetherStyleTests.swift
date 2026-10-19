import XCTest
import UIKit
import QuartzCore
import SwiftUI
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

    func testNativeNavigationTypefaceMatchesLineupsRoundedSystemFace() throws {
        let sizes: [CGFloat] = [10, 13, 17, 34]
        let weights: [UIFont.Weight] = [.regular, .medium, .semibold, .heavy]
        for size in sizes {
            for weight in weights {
                let actual = AetherTheme.roundedUIFont(size, weight)
                let system = UIFont.systemFont(ofSize: size, weight: weight)
                let descriptor = try XCTUnwrap(system.fontDescriptor.withDesign(.rounded))
                let expected = UIFont(descriptor: descriptor, size: size)
                XCTAssertEqual(actual.fontName, expected.fontName)
                XCTAssertEqual(actual.pointSize, size)
            }
        }
    }

    func testSettingsDynamicTextStylesKeepRoundedFaceAndRequestedWeights() {
        let styles: [Font.TextStyle] = [.largeTitle, .title, .title2, .title3, .headline,
                                        .subheadline, .body, .callout, .footnote, .caption, .caption2]
        let weights: [Font.Weight] = [.regular, .medium, .semibold, .bold, .heavy]
        for style in styles {
            let defaultWeight: Font.Weight = style == .headline ? .semibold : .regular
            XCTAssertEqual(Font.radio(style), .system(style, design: .rounded, weight: defaultWeight))
            for weight in weights {
                XCTAssertEqual(Font.radio(style, weight), .system(style, design: .rounded, weight: weight))
            }
        }
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
