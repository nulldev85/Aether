import XCTest
import UIKit
import QuartzCore
import SwiftUI
@testable import IPTVRadio

@MainActor
final class AetherStyleTests: XCTestCase {
    func testGraphitePaletteIsIdenticalInBothSystemAppearances() {
        let expected: [(UIColor, UInt32)] = [
            (AetherTheme.uiCanvas, 0x101113),
            (AetherTheme.uiNavigationSurface, 0x181A1D),
            (AetherTheme.uiPrimaryText, 0xC7CBD1),
            (AetherTheme.uiMutedIcon, 0x959DA8),
            (AetherTheme.uiAccent, 0x9CA5B1)
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

    func testWorkspaceNavigationMetricsRetainUsableTouchTargets() {
        XCTAssertEqual(AetherNavigationLayout.sideMargin, 24)
        XCTAssertGreaterThanOrEqual(AetherNavigationLayout.utilityTarget, 44)
        XCTAssertGreaterThanOrEqual(AetherNavigationLayout.minimumTarget, 44)
        // Actual top/bottom separation and target frames are asserted in the
        // UI suite. There is no floating-dock reservation arithmetic anymore.
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

    func testFullPlayerGeometryFitsTheAvailableRecordStageAndSlimsControlsWithoutTinyTargets() {
        let cases: [(CGSize, CGFloat)] = [
            (CGSize(width: 353, height: 500), 313),
            (CGSize(width: 353, height: 180), 180),
            (CGSize(width: 280, height: 400), 240),
            (CGSize(width: 984, height: 700), 360),
            (.zero, 0)
        ]
        for (stage, expected) in cases {
            let diameter = NowPlayingLayout.recordDiameter(in: stage)
            XCTAssertEqual(diameter, expected)
            XCTAssertGreaterThanOrEqual(diameter, 0)
            XCTAssertLessThanOrEqual(diameter, stage.height)
            XCTAssertLessThanOrEqual(diameter, stage.width)
        }
        XCTAssertGreaterThanOrEqual(NowPlayingLayout.skipButtonSize, 44)
        XCTAssertGreaterThanOrEqual(NowPlayingLayout.transportButtonSize, 44)
        let cardHeight = NowPlayingLayout.transportButtonSize + 44
            + NowPlayingLayout.controlRowGap + 2 * NowPlayingLayout.controlVerticalPadding
        XCTAssertEqual(cardHeight, 140)
        XCTAssertLessThanOrEqual(cardHeight, 176 * 0.8)
        XCTAssertGreaterThanOrEqual(NowPlayingLayout.minimumRecordStageHeight, NowPlayingLayout.compactRecordDiameter)
    }
}
