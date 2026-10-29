import simd

/// The color math behind every format, after CSS Color 4 (§10, sample code) and Björn Ottosson's OKLab. sRGB and
/// Display P3 share the sRGB transfer curve and the D65 white point, so going from one to the other is a matrix on
/// linear light, through CIE XYZ. Values outside 0…1 (extended sRGB, which is how macOS hands over a wide-gamut color)
/// keep their sign through the transfer curve, so nothing is clipped until a format asks for it.
nonisolated enum ColorSpaceMath {
    /// sRGB (or Display P3) gamma-encoded component to linear light.
    static func linear(_ encoded: Double) -> Double {
        let magnitude = abs(encoded)
        let value = magnitude <= 0.04045 ? magnitude / 12.92 : pow((magnitude + 0.055) / 1.055, 2.4)
        return encoded < 0 ? -value : value
    }

    /// Linear light to the sRGB (or Display P3) transfer curve.
    static func encoded(_ linear: Double) -> Double {
        let magnitude = abs(linear)
        let value = magnitude <= 0.003_130_8 ? magnitude * 12.92 : 1.055 * pow(magnitude, 1 / 2.4) - 0.055
        return linear < 0 ? -value : value
    }

    static func linear(_ encoded: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(linear(encoded.x), linear(encoded.y), linear(encoded.z))
    }

    static func encoded(_ linear: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(encoded(linear.x), encoded(linear.y), encoded(linear.z))
    }

    static let linearSRGBToXYZ = simd_double3x3(rows: [
        SIMD3(0.412_390_799_265_959_5, 0.357_584_339_383_878, 0.180_480_788_401_834_3),
        SIMD3(0.212_639_005_871_510_36, 0.715_168_678_767_756, 0.072_192_315_360_733_71),
        SIMD3(0.019_330_818_715_591_85, 0.119_194_779_794_625_99, 0.950_532_152_249_660_6),
    ])

    static let xyzToLinearSRGB = simd_double3x3(rows: [
        SIMD3(3.240_969_941_904_522_6, -1.537_383_177_570_094, -0.498_610_760_293_003_4),
        SIMD3(-0.969_243_636_280_879_6, 1.875_967_501_507_720_2, 0.041_555_057_407_175_59),
        SIMD3(0.055_630_079_696_993_66, -0.203_976_958_888_976_52, 1.056_971_514_242_878_6),
    ])

    static let linearP3ToXYZ = simd_double3x3(rows: [
        SIMD3(0.486_570_948_648_216_2, 0.265_667_693_169_093_06, 0.198_217_285_234_362_5),
        SIMD3(0.228_974_564_069_748_8, 0.691_738_521_836_506_4, 0.079_286_914_093_745),
        SIMD3(0, 0.045_113_381_858_902_64, 1.043_944_368_900_976),
    ])

    static let xyzToLinearP3 = simd_double3x3(rows: [
        SIMD3(2.493_496_911_941_425, -0.931_383_617_919_123_9, -0.402_710_784_450_716_84),
        SIMD3(-0.829_488_969_561_574_7, 1.762_664_060_318_346_3, 0.023_624_685_841_943_577),
        SIMD3(0.035_845_830_243_784_47, -0.076_172_389_268_041_82, 0.956_884_524_007_687_2),
    ])

    /// Gamma-encoded sRGB to gamma-encoded Display P3.
    static func displayP3(fromSRGB srgb: SIMD3<Double>) -> SIMD3<Double> {
        encoded(xyzToLinearP3 * (linearSRGBToXYZ * linear(srgb)))
    }

    /// Gamma-encoded Display P3 to gamma-encoded (extended) sRGB.
    static func sRGB(fromDisplayP3 p3: SIMD3<Double>) -> SIMD3<Double> {
        encoded(xyzToLinearSRGB * (linearP3ToXYZ * linear(p3)))
    }

    /// Linear sRGB to OKLab (L, a, b), with Ottosson's matrices for sRGB.
    static func oklab(fromLinearSRGB rgb: SIMD3<Double>) -> SIMD3<Double> {
        let lms = SIMD3(
            0.412_221_470_8 * rgb.x + 0.536_332_536_3 * rgb.y + 0.051_445_992_9 * rgb.z,
            0.211_903_498_2 * rgb.x + 0.680_699_545_1 * rgb.y + 0.107_396_956_6 * rgb.z,
            0.088_302_461_9 * rgb.x + 0.281_718_837_6 * rgb.y + 0.629_978_700_5 * rgb.z
        )
        let root = SIMD3(cbrt(lms.x), cbrt(lms.y), cbrt(lms.z))
        return SIMD3(
            0.210_454_255_3 * root.x + 0.793_617_785_0 * root.y - 0.004_072_046_8 * root.z,
            1.977_998_495_1 * root.x - 2.428_592_205_0 * root.y + 0.450_593_709_9 * root.z,
            0.025_904_037_1 * root.x + 0.782_771_766_2 * root.y - 0.808_675_766_0 * root.z
        )
    }

    /// OKLab (L, a, b) back to linear sRGB.
    static func linearSRGB(fromOKLab lab: SIMD3<Double>) -> SIMD3<Double> {
        let root = SIMD3(
            lab.x + 0.396_337_777_4 * lab.y + 0.215_803_757_3 * lab.z,
            lab.x - 0.105_561_345_8 * lab.y - 0.063_854_172_8 * lab.z,
            lab.x - 0.089_484_177_5 * lab.y - 1.291_485_548_0 * lab.z
        )
        let lms = root * root * root
        return SIMD3(
            4.076_741_662_1 * lms.x - 3.307_711_591_3 * lms.y + 0.230_969_929_2 * lms.z,
            -1.268_438_004_6 * lms.x + 2.609_757_401_1 * lms.y - 0.341_319_396_5 * lms.z,
            -0.004_196_086_3 * lms.x - 0.703_418_614_7 * lms.y + 1.707_614_701_0 * lms.z
        )
    }

    /// The hue angle of OKLab's opponent pair (a: green–red, b: blue–yellow) in degrees, 0 ..< 360.
    static func hueDegrees(greenRed: Double, blueYellow: Double) -> Double {
        let degrees = atan2(blueYellow, greenRed) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }
}
