@testable import ColorPicker
import Testing

/// WCAG ratios as WebAIM's checker reports them, and APCA values from the apca-w3 reference implementation's
/// documentation (0.0.98G-4g).
struct ContrastTests {
    @Test(arguments: [
        ("#000000", "#FFFFFF", 21.0),
        ("#777777", "#FFFFFF", 4.478_089),
        ("#767676", "#FFFFFF", 4.542_225),
        ("#949494", "#FFFFFF", 3.033_470),
        ("#959595", "#FFFFFF", 2.995_346),
        ("#595959", "#FFFFFF", 7.004_729),
        ("#5A5A5A", "#FFFFFF", 6.896_926),
        ("#0000FF", "#FFFFFF", 8.592_471),
        ("#336699", "#FFFFFF", 5.997_787),
        ("#FFFFFF", "#FFFFFF", 1.0),
    ])
    func wcagRatiosOfKnownPairs(_ text: String, _ background: String, _ expected: Double) {
        #expect(approximately(WCAGContrast.ratio(.hex(text), .hex(background)), expected, 1e-5))
        #expect(approximately(WCAGContrast.ratio(.hex(background), .hex(text)), expected, 1e-5))
    }

    /// The lightest grays that pass on white: #767676 for normal text at AA, #949494 for large text and UI components,
    /// #595959 for AAA. One step lighter fails.
    @Test func thresholdsAreExactAndNotRoundedUp() {
        let white = ColorValue.white
        let aa = WCAGContrast.ratio(.hex("#767676"), white)
        let almostAA = WCAGContrast.ratio(.hex("#777777"), white)
        #expect(ContrastCriterion.normalTextAA.isMet(by: aa) && !ContrastCriterion.normalTextAA.isMet(by: almostAA))
        #expect(ContrastCriterion.largeTextAAA.isMet(by: aa) && !ContrastCriterion.largeTextAAA.isMet(by: almostAA))
        let large = WCAGContrast.ratio(.hex("#949494"), white)
        let almostLarge = WCAGContrast.ratio(.hex("#959595"), white)
        #expect(ContrastCriterion.largeTextAA.isMet(by: large) && !ContrastCriterion.largeTextAA.isMet(by: almostLarge))
        #expect(ContrastCriterion.userInterfaceAA.isMet(by: large) && !ContrastCriterion.userInterfaceAA.isMet(by: almostLarge))
        let aaa = WCAGContrast.ratio(.hex("#595959"), white)
        let almostAAA = WCAGContrast.ratio(.hex("#5A5A5A"), white)
        #expect(ContrastCriterion.normalTextAAA.isMet(by: aaa) && !ContrastCriterion.normalTextAAA.isMet(by: almostAAA))
        #expect(!ContrastCriterion.normalTextAA.isMet(by: 4.499_9))
    }

    @Test func criteriaCoverWCAGsTable() {
        #expect(ContrastCriterion.criterion(for: .normalText, level: .aa)?.minimum == 4.5)
        #expect(ContrastCriterion.criterion(for: .normalText, level: .aaa)?.minimum == 7)
        #expect(ContrastCriterion.criterion(for: .largeText, level: .aa)?.minimum == 3)
        #expect(ContrastCriterion.criterion(for: .largeText, level: .aaa)?.minimum == 4.5)
        #expect(ContrastCriterion.criterion(for: .userInterface, level: .aa)?.minimum == 3)
        #expect(ContrastCriterion.criterion(for: .userInterface, level: .aaa) == nil)
    }

    @Test(arguments: [
        (4.478_089, "4.47:1"),
        (4.542_225, "4.54:1"),
        (21.0, "21.00:1"),
        (1.0, "1.00:1"),
        (4.499_9, "4.49:1"),
        (7.0, "7.00:1"),
    ])
    func ratiosAreCutNotRounded(_ ratio: Double, _ expected: String) {
        #expect(WCAGContrast.ratioText(ratio) == expected)
    }

    @Test func translucentTextIsBlendedOverTheBackground() {
        let halfBlack = ColorValue(red: 0, green: 0, blue: 0, alpha: 0.5)
        let shown = WCAGContrast.shown(halfBlack, on: .white)
        #expect(approximately(shown.red, 0.5) && shown.isOpaque)
        #expect(WCAGContrast.shown(.hex("#336699"), on: .white) == .hex("#336699"))
    }

    @Test(arguments: [
        ("#888888", "#FFFFFF", 63.056_470),
        ("#FFFFFF", "#888888", -68.541_464),
        ("#000000", "#AAAAAA", 58.146_263),
        ("#AAAAAA", "#000000", -56.241_133),
        ("#112233", "#DDEEFF", 91.668_308),
        ("#DDEEFF", "#112233", -93.067_700),
        ("#000000", "#FFFFFF", 106.040_673),
        ("#FFFFFF", "#000000", -107.884_733),
        ("#112233", "#223344", 0.0),
    ])
    func apcaMatchesTheReferenceValues(_ text: String, _ background: String, _ expected: Double) {
        #expect(approximately(APCAContrast.lightnessContrast(text: .hex(text), background: .hex(background)), expected, 1e-4))
    }

    @Test func apcaReadsAsGuidance() {
        #expect(APCAContrast.text(63.056) == "Lc 63.1")
        #expect(APCAContrast.text(-68.54) == "Lc −68.5")
        #expect(APCAContrast.text(0) == "Lc 0.0")
        #expect(APCAContrast.text(106.04) == "Lc 106.0")
        #expect(APCAContrast.use(for: 106) == "Preferred for body text")
        #expect(APCAContrast.use(for: -76) == "Enough for body text")
        #expect(APCAContrast.use(for: 63) == "Enough for content text, not body text")
        #expect(APCAContrast.use(for: 46) == "Enough for headlines and large text")
        #expect(APCAContrast.use(for: 10) == "Too low to see reliably")
    }
}
