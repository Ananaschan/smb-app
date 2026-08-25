import XCTest
@testable import SMBPlayer

final class RemoteItemTests: XCTestCase {
    func testDirectoriesComeFirstWhenSortingByName() {
        let folder = RemoteItem(
            name: "Zeta 文件夹",
            path: "zeta",
            isDirectory: true,
            size: 0,
            modifiedAt: nil
        )
        let file = RemoteItem(
            name: "Alpha.mp4",
            path: "alpha.mp4",
            isDirectory: false,
            size: 100,
            modifiedAt: nil
        )

        XCTAssertTrue(
            RemoteFileSort.compares(
                folder,
                file,
                sort: .name,
                ascending: true
            )
        )
    }

    func testDateSortingDescending() {
        let older = RemoteItem(
            name: "old.jpg",
            path: "old.jpg",
            isDirectory: false,
            size: 1,
            modifiedAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = RemoteItem(
            name: "new.jpg",
            path: "new.jpg",
            isDirectory: false,
            size: 1,
            modifiedAt: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertTrue(
            RemoteFileSort.compares(
                newer,
                older,
                sort: .date,
                ascending: false
            )
        )
    }

    func testParentPath() {
        XCTAssertEqual(
            RemoteItem.parentPath(of: "Movies/2026/example.mkv"),
            "Movies/2026"
        )
        XCTAssertEqual(RemoteItem.parentPath(of: "root.mkv"), "")
    }

    func testJoiningPaths() {
        XCTAssertEqual(RemoteItem.path(byJoining: "Movies", "a.mkv"), "Movies/a.mkv")
        XCTAssertEqual(RemoteItem.path(byJoining: "", "a.mkv"), "a.mkv")
    }
}
