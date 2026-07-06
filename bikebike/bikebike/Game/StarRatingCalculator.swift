enum StarRatingCalculator {
    static func stars(for position: Int) -> Int {
        max(1, min(5, 6 - position))
    }
}
