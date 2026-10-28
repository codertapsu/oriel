import CoreGraphics
@testable import OCR
import Testing

struct OCRGeometryTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let normalized: CGRect
        let imageSize: CGSize
        let expected: CGRect

        var testDescription: String {
            "\(normalized) in \(imageSize)"
        }
    }

    static let cases: [Case] = [
        // The whole image.
        Case(
            normalized: CGRect(x: 0, y: 0, width: 1, height: 1),
            imageSize: CGSize(width: 800, height: 600),
            expected: CGRect(x: 0, y: 0, width: 800, height: 600)
        ),
        // Bottom-left origin becomes top-left: a box at the bottom of Vision's space is at the bottom of the image.
        Case(
            normalized: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            imageSize: CGSize(width: 1000, height: 500),
            expected: CGRect(x: 100, y: 200, width: 300, height: 200)
        ),
        Case(
            normalized: CGRect(x: 0, y: 0.9, width: 0.5, height: 0.1),
            imageSize: CGSize(width: 200, height: 100),
            expected: CGRect(x: 0, y: 0, width: 100, height: 10)
        ),
        // Floating-point noise from Vision does not add a pixel (0.0333333331 × 1200 = 39.9999997).
        Case(
            normalized: CGRect(x: 0.0333333331, y: 0.6, width: 0.5375, height: 0.1071428571),
            imageSize: CGSize(width: 1200, height: 700),
            expected: CGRect(x: 40, y: 205, width: 645, height: 75)
        ),
        // Fractional pixels round outwards.
        Case(
            normalized: CGRect(x: 0.105, y: 0.105, width: 0.5, height: 0.5),
            imageSize: CGSize(width: 100, height: 100),
            expected: CGRect(x: 10, y: 39, width: 51, height: 51)
        ),
        // Parts outside the image are clipped.
        Case(
            normalized: CGRect(x: -0.1, y: 0.8, width: 0.3, height: 0.4),
            imageSize: CGSize(width: 100, height: 100),
            expected: CGRect(x: 0, y: 0, width: 20, height: 20)
        ),
    ]

    @Test(arguments: cases)
    func convertsNormalizedBottomLeftBoxesToTopLeftPixels(_ testCase: Case) {
        #expect(OCRGeometry.pixelRect(fromNormalized: testCase.normalized, imageSize: testCase.imageSize) == testCase.expected)
    }

    @Test func boxesOutsideTheImageOrOfAnEmptyImageAreZero() {
        let size = CGSize(width: 100, height: 100)
        #expect(OCRGeometry.pixelRect(fromNormalized: CGRect(x: 1.2, y: 0, width: 0.1, height: 0.1), imageSize: size) == .zero)
        #expect(OCRGeometry.pixelRect(fromNormalized: CGRect(x: 0, y: 0, width: 1, height: 1), imageSize: .zero) == .zero)
        #expect(OCRGeometry.pixelRect(fromNormalized: .null, imageSize: size) == .zero)
    }

    @Test func normalizedRectIsTheInverse() {
        let size = CGSize(width: 1000, height: 500)
        let pixels = CGRect(x: 100, y: 200, width: 300, height: 200)
        let normalized = OCRGeometry.normalizedRect(fromPixel: pixels, imageSize: size)
        #expect(abs(normalized.minX - 0.1) < 1e-9 && abs(normalized.minY - 0.2) < 1e-9)
        #expect(abs(normalized.width - 0.3) < 1e-9 && abs(normalized.height - 0.4) < 1e-9)
        #expect(OCRGeometry.pixelRect(fromNormalized: normalized, imageSize: size) == pixels)
    }

    @Test func unionCoversEveryRect() {
        let rects = [CGRect(x: 10, y: 10, width: 5, height: 5), CGRect(x: 0, y: 20, width: 2, height: 2)]
        #expect(OCRGeometry.union(rects) == CGRect(x: 0, y: 10, width: 15, height: 12))
        #expect(OCRGeometry.union([]) == .zero)
    }
}
