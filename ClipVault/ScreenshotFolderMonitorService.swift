//
//  ScreenshotFolderMonitorService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/23/26.
//

import Combine
import Darwin
import Foundation

enum ScreenshotFolderMonitorStartResult:
    Equatable
{
    case started

    case alreadyMonitoring

    case securityScopedAccessFailed

    case folderOpenFailed
}

@MainActor
final class ScreenshotFolderMonitorService:
    ObservableObject
{
    @Published
    private(set)
    var isMonitoring:
        Bool =
            false

    @Published
    private(set)
    var monitoredFolderURL:
        URL?

    private var eventSource:
        (
            any
            DispatchSourceFileSystemObject
        )?

    private var folderFileDescriptor:
        Int32 =
            -1

    private var securityScopedFolderURL:
        URL?

    private let monitoringQueue:
        DispatchQueue

    private let securityScopeStarter:
        (URL) -> Bool

    private let securityScopeStopper:
        (URL) -> Void

    private let folderOpener:
        (URL) -> Int32

    private let fileDescriptorCloser:
        (Int32) -> Void

    init(
        monitoringQueue:
            DispatchQueue =
                DispatchQueue(
                    label:
                        "com.alejandromora.ClipVault.ScreenshotFolderMonitor"
                ),
        securityScopeStarter:
            @escaping (URL) -> Bool = {
                folderURL in

                folderURL
                    .startAccessingSecurityScopedResource()
            },
        securityScopeStopper:
            @escaping (URL) -> Void = {
                folderURL in

                folderURL
                    .stopAccessingSecurityScopedResource()
            },
        folderOpener:
            @escaping (URL) -> Int32 = {
                folderURL in

                open(
                    folderURL.path,
                    O_EVTONLY
                )
            },
        fileDescriptorCloser:
            @escaping (Int32) -> Void = {
                fileDescriptor in

                close(
                    fileDescriptor
                )
            }
    ) {
        self.monitoringQueue =
            monitoringQueue

        self.securityScopeStarter =
            securityScopeStarter

        self.securityScopeStopper =
            securityScopeStopper

        self.folderOpener =
            folderOpener

        self.fileDescriptorCloser =
            fileDescriptorCloser
    }

    deinit
    {
        /*
         Normal shutdown should call stopMonitoring()
         while still on the main actor. This fallback
         prevents the DispatchSource from remaining
         active if the service is unexpectedly released.
         */
        eventSource?
            .cancel()
    }

    func startMonitoring(
        folderURL:
            URL,
        onFolderChanged:
            @escaping @MainActor () -> Void
    ) -> ScreenshotFolderMonitorStartResult {
        guard
            !isMonitoring
        else {
            return .alreadyMonitoring
        }

        let standardizedFolderURL =
            folderURL
                .standardizedFileURL

        guard
            securityScopeStarter(
                standardizedFolderURL
            )
        else {
            return .securityScopedAccessFailed
        }

        let openedFileDescriptor =
            folderOpener(
                standardizedFolderURL
            )

        guard
            openedFileDescriptor >=
                0
        else {
            securityScopeStopper(
                standardizedFolderURL
            )

            return .folderOpenFailed
        }

        let newEventSource =
            DispatchSource
                .makeFileSystemObjectSource(
                    fileDescriptor:
                        openedFileDescriptor,
                    eventMask: [
                        .write,
                        .extend,
                        .attrib,
                        .rename,
                        .delete
                    ],
                    queue:
                        monitoringQueue
                )

        newEventSource
            .setEventHandler {
                Task {
                    @MainActor in

                    onFolderChanged()
                }
            }

        newEventSource
            .setCancelHandler {
                [fileDescriptorCloser]
                in

                fileDescriptorCloser(
                    openedFileDescriptor
                )
            }

        eventSource =
            newEventSource

        folderFileDescriptor =
            openedFileDescriptor

        securityScopedFolderURL =
            standardizedFolderURL

        monitoredFolderURL =
            standardizedFolderURL

        isMonitoring =
            true

        newEventSource
            .resume()

        return .started
    }

    func stopMonitoring()
    {
        guard
            isMonitoring
        else {
            return
        }

        eventSource?
            .cancel()

        eventSource =
            nil

        folderFileDescriptor =
            -1

        if let securityScopedFolderURL {
            securityScopeStopper(
                securityScopedFolderURL
            )
        }

        securityScopedFolderURL =
            nil

        monitoredFolderURL =
            nil

        isMonitoring =
            false
    }
}
