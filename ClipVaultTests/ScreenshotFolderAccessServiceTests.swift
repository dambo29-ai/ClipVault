//
//  ScreenshotFolderAccessServiceTests.swift
//  ClipVaultTests
//
//  Created by Alejandro Mora on 7/23/26.
//

import Foundation
import Testing
@testable import ClipVault

@MainActor
struct ScreenshotFolderAccessServiceTests
{
    @Test
    func grantsAccessWhenSelectedFolderMatchesDestination()
    {
        let testDefaults =
            makeUserDefaults()

        defer {
            clearUserDefaults(
                testDefaults
            )
        }

        let expectedFolder =
            URL(
                fileURLWithPath:
                    "/Users/TestUser/Desktop",
                isDirectory:
                    true
            )

        let bookmarkData =
            Data(
                [1, 2, 3]
            )

        let service =
            makeService(
                destination:
                    expectedFolder,
                userDefaults:
                    testDefaults,
                bookmarkCreator: {
                    selectedURL in

                    #expect(
                        selectedURL ==
                            expectedFolder
                    )

                    return bookmarkData
                }
            )

        let result =
            service
                .grantAccess(
                    to:
                        expectedFolder
                )

        guard
            case .granted =
                result
        else {
            Issue.record(
                "Expected access to be granted."
            )

            return
        }

        #expect(
            service
                .hasAccessToCurrentDestination
        )

        #expect(
            service
                .grantedFolderURL ==
                expectedFolder
        )
    }

    @Test
    func rejectsFolderThatDoesNotMatchDestination()
    {
        let expectedFolder =
            URL(
                fileURLWithPath:
                    "/Users/TestUser/Desktop",
                isDirectory:
                    true
            )

        let selectedFolder =
            URL(
                fileURLWithPath:
                    "/Users/TestUser/Pictures",
                isDirectory:
                    true
            )

        let service =
            makeService(
                destination:
                    expectedFolder
            )

        let result =
            service
                .grantAccess(
                    to:
                        selectedFolder
                )

        guard
            case let .incorrectFolder(
                expected,
                selected
            ) =
                result
        else {
            Issue.record(
                "Expected an incorrect-folder result."
            )

            return
        }

        #expect(
            expected ==
                expectedFolder
        )

        #expect(
            selected ==
                selectedFolder
        )

        #expect(
            !service
                .hasAccessToCurrentDestination
        )
    }

    @Test
    func restoresSavedBookmarkAccess()
    {
        let testDefaults =
            makeUserDefaults()

        defer {
            clearUserDefaults(
                testDefaults
            )
        }

        let expectedFolder =
            URL(
                fileURLWithPath:
                    "/Users/TestUser/Desktop",
                isDirectory:
                    true
            )

        let bookmarkData =
            Data(
                [4, 5, 6]
            )

        testDefaults
            .set(
                bookmarkData,
                forKey:
                    "screenshotFolderSecurityScopedBookmark"
            )

        let service =
            makeService(
                destination:
                    expectedFolder,
                userDefaults:
                    testDefaults,
                bookmarkResolver: {
                    receivedBookmark in

                    #expect(
                        receivedBookmark ==
                            bookmarkData
                    )

                    return (
                        url:
                            expectedFolder,
                        isStale:
                            false
                    )
                }
            )

        #expect(
            service
                .grantedFolderURL ==
                expectedFolder
        )

        #expect(
            service
                .hasAccessToCurrentDestination
        )
    }

    @Test
    func clearAccessRemovesSavedPermission()
    {
        let testDefaults =
            makeUserDefaults()

        defer {
            clearUserDefaults(
                testDefaults
            )
        }

        let expectedFolder =
            URL(
                fileURLWithPath:
                    "/Users/TestUser/Desktop",
                isDirectory:
                    true
            )

        let service =
            makeService(
                destination:
                    expectedFolder,
                userDefaults:
                    testDefaults,
                bookmarkCreator: {
                    _ in

                    Data(
                        [7, 8, 9]
                    )
                }
            )

        let result =
            service
                .grantAccess(
                    to:
                        expectedFolder
                )

        guard
            case .granted =
                result
        else {
            Issue.record(
                "Expected access to be granted."
            )

            return
        }

        service
            .clearAccess()

        #expect(
            service
                .grantedFolderURL ==
                nil
        )

        #expect(
            !service
                .hasAccessToCurrentDestination
        )

        #expect(
            testDefaults
                .data(
                    forKey:
                        "screenshotFolderSecurityScopedBookmark"
                ) ==
                nil
        )
    }

    private func makeService(
        destination:
            URL,
        userDefaults:
            UserDefaults =
                .standard,
        bookmarkCreator:
            @escaping (URL) throws -> Data = {
                _ in

                Data(
                    [1]
                )
            },
        bookmarkResolver:
            @escaping (Data) throws -> (
                url:
                    URL,
                isStale:
                    Bool
            ) = {
                _ in

                throw TestError
                    .unavailable
            }
    ) -> ScreenshotFolderAccessService {
        ScreenshotFolderAccessService(
            destinationService:
                ScreenshotDestinationService(
                    homeDirectory:
                        URL(
                            fileURLWithPath:
                                "/Users/TestUser",
                            isDirectory:
                                true
                        ),
                    configuredLocationProvider: {
                        destination
                            .path
                    }
                ),
            userDefaults:
                userDefaults,
            bookmarkCreator:
                bookmarkCreator,
            bookmarkResolver:
                bookmarkResolver
        )
    }

    private func makeUserDefaults()
        -> UserDefaults
    {
        let suiteName =
            "ScreenshotFolderAccessServiceTests-" +
            UUID()
                .uuidString

        return UserDefaults(
            suiteName:
                suiteName
        )!
    }

    private func clearUserDefaults(
        _ userDefaults:
            UserDefaults
    ) {
        guard
            let suiteName =
                userDefaults
                    .volatileDomainNames
                    .first(
                        where: {
                            $0.contains(
                                "ScreenshotFolderAccessServiceTests-"
                            )
                        }
                    )
        else {
            return
        }

        userDefaults
            .removePersistentDomain(
                forName:
                    suiteName
            )
    }

    private enum TestError:
        Error
    {
        case unavailable
    }
}
