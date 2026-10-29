import Foundation
@testable import Recording
import Testing

struct ChapterListTests {
    private func markers(_ entries: [(Double, String)]) -> [ChapterMarker] {
        entries.map { ChapterMarker(time: $0.0, title: $0.1) }
    }

    @Test func coversTheWholeMovieFromZero() {
        let chapters = ChapterList.build(markers([(0, "Intro"), (12.5, "Setup"), (40, "Demo")]), range: 0 ... 60)

        #expect(chapters == [
            ExportedChapter(start: 0, duration: 12.5, title: "Intro"),
            ExportedChapter(start: 12.5, duration: 27.5, title: "Setup"),
            ExportedChapter(start: 40, duration: 20, title: "Demo"),
        ])
    }

    @Test func addsAnOpeningChapterWhenNoMarkerIsAtTheStart() {
        let chapters = ChapterList.build(markers([(10, "Demo"), (5, "Setup")]), range: 0 ... 30)

        #expect(chapters.map(\.title) == ["Start", "Setup", "Demo"])
        #expect(chapters.map(\.start) == [0, 5, 10])
    }

    @Test func aMarkerJustAfterTheStartNamesTheOpeningChapter() {
        let chapters = ChapterList.build(markers([(0.4, "Intro"), (10, "Demo")]), range: 0 ... 30)

        #expect(chapters.map(\.title) == ["Intro", "Demo"])
        #expect(chapters.map(\.start) == [0, 10])
    }

    @Test func aTrimStartsWithTheChapterRunningThere() {
        let chapters = ChapterList.build(markers([(0, "Intro"), (20, "Setup"), (50, "Demo")]), range: 30 ... 70)

        #expect(chapters == [
            ExportedChapter(start: 0, duration: 20, title: "Setup"),
            ExportedChapter(start: 20, duration: 20, title: "Demo"),
        ])
    }

    @Test func leavesOutMarkersAfterTheTrim() {
        let chapters = ChapterList.build(markers([(0, "Intro"), (20, "Setup"), (50, "Outro")]), range: 0 ... 40)

        #expect(chapters.map(\.title) == ["Intro", "Setup"])
        #expect(chapters.last?.end == 40)
    }

    @Test func hasNoChaptersWhenNoMarkerApplies() {
        #expect(ChapterList.build([], range: 0 ... 30).isEmpty)
        #expect(ChapterList.build(markers([(50, "Later")]), range: 0 ... 30).isEmpty)
        #expect(ChapterList.build(markers([(1, "Intro")]), range: 5 ... 5).isEmpty)
    }

    @Test func mergesMarkersTooCloseTogetherAndAtTheEnd() {
        let chapters = ChapterList.build(markers([(0, "Intro"), (10, "Setup"), (10.5, "Typo"), (29.6, "Too late")]), range: 0 ... 30)

        #expect(chapters.map(\.title) == ["Intro", "Setup"])
        #expect(chapters.last?.duration == 20)
    }

    @Test func namesUntitledChaptersAndKeepsTitlesOnOneLine() {
        let chapters = ChapterList.build(markers([(0, "  "), (10, "Two\nlines ")]), range: 0 ... 20)

        #expect(chapters.map(\.title) == ["Chapter 1", "Two lines"])
        #expect(ChapterList.title(String(repeating: "a", count: 300), number: 1).count == ChapterList.maximumTitleLength)
    }

    @Test func writesYouTubeTimestamps() {
        let chapters = [
            ExportedChapter(start: 0, duration: 83.9, title: "Intro"),
            ExportedChapter(start: 83.9, duration: 600, title: "Demo"),
            ExportedChapter(start: 683.9, duration: 30, title: "Questions"),
        ]

        #expect(ChapterTimestamps.text(for: chapters) == "00:00 Intro\n01:23 Demo\n11:23 Questions")
    }

    @Test func showsHoursOnceTheMovieIsAnHourLong() {
        let chapters = [
            ExportedChapter(start: 0, duration: 3000, title: "Part one"),
            ExportedChapter(start: 3000, duration: 723, title: "Part two"),
        ]

        #expect(ChapterTimestamps.text(for: chapters) == "0:00:00 Part one\n0:50:00 Part two")
        #expect(ChapterTimestamps.timestamp(3723.9, usesHours: true) == "1:02:03")
        #expect(ChapterTimestamps.timestamp(-5, usesHours: false) == "00:00")
    }

    @Test func saysWhyYouTubeWouldIgnoreChapters() {
        let two = [ExportedChapter(start: 0, duration: 20, title: "A"), ExportedChapter(start: 20, duration: 20, title: "B")]
        #expect(ChapterTimestamps.youTubeProblems(two).count == 1)

        let short = two + [ExportedChapter(start: 40, duration: 5, title: "C")]
        #expect(ChapterTimestamps.youTubeProblems(short) == ["YouTube shows chapters only when each is at least 10 seconds long."])

        let good = two + [ExportedChapter(start: 40, duration: 15, title: "C")]
        #expect(ChapterTimestamps.youTubeProblems(good).isEmpty)
    }
}
