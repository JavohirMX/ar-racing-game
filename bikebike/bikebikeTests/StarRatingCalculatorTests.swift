import Testing
@testable import bikebike

@Suite struct StarRatingCalculatorTests {

    @Test func firstPlaceGetsFiveStars() {
        #expect(StarRatingCalculator.stars(for: 1) == 5)
    }

    @Test func secondPlaceGetsFourStars() {
        #expect(StarRatingCalculator.stars(for: 2) == 4)
    }

    @Test func thirdPlaceGetsThreeStars() {
        #expect(StarRatingCalculator.stars(for: 3) == 3)
    }

    @Test func fourthPlaceGetsTwoStars() {
        #expect(StarRatingCalculator.stars(for: 4) == 2)
    }

    @Test func fifthPlaceGetsOneStar() {
        #expect(StarRatingCalculator.stars(for: 5) == 1)
    }

    @Test func sixthPlaceGetsOneStar() {
        #expect(StarRatingCalculator.stars(for: 6) == 1)
    }

    @Test func highPositionsStillGetOneStar() {
        #expect(StarRatingCalculator.stars(for: 10) == 1)
        #expect(StarRatingCalculator.stars(for: 100) == 1)
    }

    @Test func ratingAlwaysInRange() {
        for position in 1...50 {
            let stars = StarRatingCalculator.stars(for: position)
            #expect(stars >= 1 && stars <= 5)
        }
    }
}
