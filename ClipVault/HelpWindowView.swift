//
//  HelpWindowView.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/24/26.
//

import SwiftUI

private enum HelpSection:
    String,
    CaseIterable,
    Identifiable
{
    case gettingStarted
    case clipboardTypes
    case screenshots
    case privacy
    case appRules
    case backups
    case excel
    case troubleshooting

    var id:
        Self
    {
        self
    }

    var title:
        String
    {
        switch self {
        case .gettingStarted:
            return "Getting Started"

        case .clipboardTypes:
            return "Clipboard Types"

        case .screenshots:
            return "Screenshots"

        case .privacy:
            return "Privacy"

        case .appRules:
            return "App Rules"

        case .backups:
            return "Backups"

        case .excel:
            return "Excel"

        case .troubleshooting:
            return "Troubleshooting"
        }
    }

    var systemImage:
        String
    {
        switch self {
        case .gettingStarted:
            return "play.circle"

        case .clipboardTypes:
            return "doc.on.clipboard"

        case .screenshots:
            return "camera.viewfinder"

        case .privacy:
            return "hand.raised"

        case .appRules:
            return "shield.lefthalf.filled"

        case .backups:
            return "externaldrive"

        case .excel:
            return "tablecells"

        case .troubleshooting:
            return "wrench.and.screwdriver"
        }
    }
    
    var searchableText:
        String
    {
        switch self {
        case .gettingStarted:
            return """
            Getting Started
            Show ClipVault
            Control Option V
            copy earlier item
            paste clipboard
            search
            Escape
            pause monitoring
            Control Option P
            pinned items
            color markers
            orange text
            green links
            blue images
            yellow files folders
            """

        case .clipboardTypes:
            return """
            Clipboard Types
            text
            plain text
            rich text
            RTF
            HTML
            formatting
            links
            web addresses
            URLs
            scheme
            images
            Quick Look
            files
            folders
            Finder
            unavailable
            moved
            renamed
            deleted
            disconnected volume
            clear history
            system clipboard
            """

        case .screenshots:
            return """
            Screenshots
            automatic screenshot capture
            Privacy settings
            screenshot folder
            macOS App Sandbox
            folder permission
            folder access
            monitoring
            processing delay
            incomplete image
            screenshot destination
            disable screenshot capture
            """

        case .privacy:
            return """
            Privacy
            local history
            sandboxed storage
            sensitive text protection
            passwords
            access tokens
            API keys
            secrets
            false positive
            Command C
            skipped text
            system clipboard
            Option selection capture
            blocked
            skipped item notices
            warning row
            """

        case .appRules:
            return """
            App Rules
            Allowed
            Smart
            Blocked
            sensitive content screening
            password managers
            developer tools
            authentication apps
            source application
            reset app rules
            default rules
            """

        case .backups:
            return """
            Backups
            Export Backup
            clipvaultbackup
            history manifest
            managed images
            backup retention
            Import Latest Backup
            drag and drop import
            Reveal Latest Backup
            Finder
            Delete Old Backups
            Exports folder
            Export History
            text export
            restore
            """

        case .excel:
            return """
            Excel
            spreadsheet
            cells
            rows
            columns
            values
            cell arrangement
            editable
            formatting
            rich text
            HTML
            formulas
            calculated values
            formula limitation
            private clipboard data
            """

        case .troubleshooting:
            return """
            Troubleshooting
            new copy does not appear
            monitoring paused
            app rules
            blocked app
            sensitive content
            unsupported data
            file cannot be opened
            missing file
            disconnected drive
            screenshots not appearing
            folder permission
            screenshot destination
            Option selection capture
            Accessibility permission
            restart
            quit reopen
            """
        }
    }
}

struct HelpWindowView:
    View
{
    @EnvironmentObject
    private var clipboardStore:
        ClipboardStore

    @State private var selectedSection:
        HelpSection? =
            .gettingStarted
    
    @State private var searchText:
        String =
            ""

    var body:
        some View
    {
        NavigationSplitView {
            VStack(
                spacing:
                    0
            ) {
                List(
                    selection:
                        $selectedSection
                ) {
                    if filteredHelpSections
                        .isEmpty
                    {
                        Text(
                            "No Help Topics Found"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .center
                        )
                        .listRowSeparator(
                            .hidden
                        )
                        .listRowBackground(
                            Color.clear
                        )
                    } else {
                        ForEach(
                            filteredHelpSections
                        ) {
                            section in

                            Label(
                                section.title,
                                systemImage:
                                    section.systemImage
                            )
                            .tag(
                                section
                            )
                        }
                    }
                }
                .navigationTitle(
                    "ClipVault Help"
                )

                Divider()

                helpSearchField
                    .padding(
                        10
                    )
            }
            .navigationSplitViewColumnWidth(
                min:
                    180,
                ideal:
                    200,
                max:
                    240
            )
        } detail: {
            ScrollView {
                selectedHelpArticle
                    .frame(
                        maxWidth:
                            680,
                        alignment:
                            .leading
                    )
                    .padding(
                        32
                    )
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity,
                alignment:
                    .topLeading
            )
            .background(
                Color(
                    nsColor:
                        .textBackgroundColor
                )
            )
        }
        .frame(
            minWidth:
                760,
            minHeight:
                520
        )
    }
    
    private var filteredHelpSections:
        [HelpSection]
    {
        let trimmedSearchText =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !trimmedSearchText
                .isEmpty
        else {
            return HelpSection
                .allCases
        }

        return HelpSection
            .allCases
            .filter {
                section in

                section
                    .searchableText
                    .localizedCaseInsensitiveContains(
                        trimmedSearchText
                    )
            }
    }
    
    private var helpSearchField:
        some View
    {
        HStack(
            spacing:
                7
        ) {
            Image(
                systemName:
                    "magnifyingglass"
            )
            .foregroundStyle(
                .secondary
            )
            .accessibilityHidden(
                true
            )

            TextField(
                "Search Help",
                text:
                    $searchText
            )
            .textFieldStyle(
                .plain
            )
            .onSubmit {
                selectFirstMatchingSection()
            }

            if !searchText
                .isEmpty
            {
                Button {
                    searchText =
                        ""

                    selectFirstMatchingSection()
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .buttonStyle(
                    .plain
                )
                .help(
                    "Clear Help Search"
                )
                .accessibilityLabel(
                    "Clear Help Search"
                )
            }
        }
        .padding(
            .horizontal,
            8
        )
        .frame(
            height:
                28
        )
        .background(
            RoundedRectangle(
                cornerRadius:
                    7,
                style:
                    .continuous
            )
            .fill(
                Color(
                    nsColor:
                        .controlBackgroundColor
                )
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    7,
                style:
                    .continuous
            )
            .stroke(
                Color.secondary
                    .opacity(
                        0.22
                    ),
                lineWidth:
                    1
            )
        }
        .onChange(
            of:
                searchText
        ) {
            _,
            _ in

            selectFirstMatchingSection()
        }
    }

    @ViewBuilder
    private var selectedHelpArticle:
        some View
    {
        switch selectedSection ??
            .gettingStarted
        {
        case .gettingStarted:
            gettingStartedArticle

        case .clipboardTypes:
            clipboardTypesArticle

        case .screenshots:
            screenshotsArticle

        case .privacy:
            privacyArticle

        case .appRules:
            appRulesArticle

        case .backups:
            backupsArticle

        case .excel:
            excelArticle

        case .troubleshooting:
            troubleshootingArticle
        }
    }
    
    private func selectFirstMatchingSection()
    {
        let matchingSections =
            filteredHelpSections

        guard
            let firstMatchingSection =
                matchingSections
                    .first
        else {
            return
        }

        if let selectedSection,
           matchingSections
            .contains(
                selectedSection
            )
        {
            return
        }

        selectedSection =
            firstMatchingSection
    }

    private var gettingStartedArticle:
        some View
    {
        HelpArticle(
            title:
                "Getting Started",
            introduction:
                "ClipVault keeps a local, searchable history of supported content copied through the macOS clipboard."
        ) {
            HelpSectionView(
                title:
                    "Show ClipVault"
            ) {
                Text(
                    "Select Show ClipVault from the menu-bar icon or press Control–Option–V."
                )
            }

            HelpSectionView(
                title:
                    "Copy an Earlier Item"
            ) {
                Text(
                    "Select a normal row to place that item back onto the macOS clipboard. You can then paste it into another app normally."
                )
            }

            HelpSectionView(
                title:
                    "Search"
            ) {
                Text(
                    "Use the search field to filter saved items. Search checks the text and available metadata associated with each item."
                )

                Text(
                    "Press Escape while the search field is active to clear the current search."
                )
            }

            HelpSectionView(
                title:
                    "Pause Monitoring"
            ) {
                Text(
                    "Select Pause Monitoring from the menu-bar icon or press Control–Option–P."
                )

                Text(
                    "While monitoring is paused, ClipVault ignores new clipboard changes. Existing history remains available."
                )
            }

            HelpSectionView(
                title:
                    "Pinned Items"
            ) {
                Text(
                    "Pinned items remain in the Pinned section and are protected from ordinary unpinned-history cleanup."
                )
            }

            HelpSectionView(
                title:
                    "Color Markers"
            ) {
                HelpBullet(
                    title:
                        "Orange",
                    body:
                        "Text"
                )

                HelpBullet(
                    title:
                        "Green",
                    body:
                        "Links"
                )

                HelpBullet(
                    title:
                        "Blue",
                    body:
                        "Images"
                )

                HelpBullet(
                    title:
                        "Yellow",
                    body:
                        "Files and folders"
                )

                Text(
                    "The color bar is a supplemental visual cue. Icons, previews, labels, and accessibility descriptions also identify each item type."
                )
            }
        }
    }

    private var clipboardTypesArticle:
        some View
    {
        HelpArticle(
            title:
                "Clipboard Types",
            introduction:
                "ClipVault organizes supported history into Text, Links, Images, and Files."
        ) {
            HelpSectionView(
                title:
                    "Text"
            ) {
                Text(
                    "Plain text is stored as searchable, editable text."
                )

                Text(
                    "When available, ClipVault also preserves supported rich-text and HTML representations so formatting can survive when pasted into compatible apps."
                )
            }

            HelpSectionView(
                title:
                    "Links"
            ) {
                Text(
                    "Web addresses are stored as links and can include a generated title or preview when one is available."
                )

                Text(
                    "ClipVault recognizes common links even when the copied address does not include a visible scheme such as https://."
                )
            }

            HelpSectionView(
                title:
                    "Images"
            ) {
                Text(
                    "Copied images are stored in ClipVault’s managed local image storage."
                )

                Text(
                    "Use Quick Look to inspect an image without replacing the current system clipboard."
                )
            }

            HelpSectionView(
                title:
                    "Files and Folders"
            ) {
                Text(
                    "ClipVault stores references to copied Finder items. The original files and folders remain in their existing locations."
                )

                Text(
                    "A stored item may become unavailable if the original is moved, renamed outside ClipVault, deleted, or located on a disconnected volume."
                )
            }

            HelpSectionView(
                title:
                    "Clear History"
            ) {
                Text(
                    "Clearing ClipVault history permanently removes the selected saved history from ClipVault."
                )

                Text(
                    "It does not erase or replace the item currently held by the macOS system clipboard."
                )
            }
        }
    }

    private var screenshotsArticle:
        some View
    {
        HelpArticle(
            title:
                "Screenshots",
            introduction:
                "ClipVault can automatically capture new screenshots created by macOS."
        ) {
            HelpSectionView(
                title:
                    "Enable Screenshot Capture"
            ) {
                Text(
                    "Open Settings → Privacy and enable automatic screenshot capture."
                )

                Text(
                    "ClipVault may ask you to choose or approve the folder where macOS saves screenshots. This permission is required by the macOS App Sandbox."
                )
            }

            HelpSectionView(
                title:
                    "How It Works"
            ) {
                Text(
                    "ClipVault monitors the approved screenshot folder for newly created image files."
                )

                Text(
                    "After macOS finishes writing the image, ClipVault stores it in history and places it on the system clipboard once."
                )
            }

            HelpSectionView(
                title:
                    "Processing Delay"
            ) {
                Text(
                    "A brief delay is normal. ClipVault waits until the screenshot file is saved onto the screenshots folder before reading it so that it does not capture an incomplete image."
                )
            }

            HelpSectionView(
                title:
                    "Changing the Screenshot Folder"
            ) {
                Text(
                    "When the macOS screenshot destination changes, ClipVault may need access to the new folder before automatic capture can continue."
                )
            }

            HelpSectionView(
                title:
                    "Disabling the Feature"
            ) {
                Text(
                    "Turn the setting off to stop monitoring the screenshot folder. Ordinary clipboard monitoring continues normally."
                )
            }
        }
    }

    private var privacyArticle:
        some View
    {
        HelpArticle(
            title:
                "Privacy",
            introduction:
                "ClipVault is designed to keep clipboard history locally on your Mac while avoiding text that appears likely to contain sensitive information."
        ) {
            HelpSectionView(
                title:
                    "Local History"
            ) {
                Text(
                    "ClipVault saves its history and managed image files locally within the app’s sandboxed storage."
                )

                Text(
                    "ClipVault does not require an online account to maintain clipboard history."
                )
            }

            HelpSectionView(
                title:
                    "Sensitive Text Protection"
            ) {
                Text(
                    "When sensitive-text protection is enabled, ClipVault examines copied text for patterns associated with passwords, access tokens, API keys, and other secret-looking content."
                )

                Text(
                    "Detection is intentionally cautious, but no automated detector can identify every secret or avoid every false positive."
                )
            }

            HelpSectionView(
                title:
                    "Normal Command–C Copies"
            ) {
                Text(
                    "When ClipVault skips text copied normally with Command–C, the copied text remains available in the macOS system clipboard for immediate pasting. ClipVault simply does not add it to history."
                )
            }

            HelpSectionView(
                title:
                    "Option-Selection Capture"
            ) {
                Text(
                    "Option-selection capture is an optional feature that can copy selected text into ClipVault without a separate Command–C action."
                )

                Text(
                    "When an Option-selection is rejected as sensitive or blocked, ClipVault restores the clipboard contents that existed before the attempted capture."
                )
            }

            HelpSectionView(
                title:
                    "Skipped-Item Notices"
            ) {
                Text(
                    "When skipped-item notices are enabled, ClipVault adds a temporary warning row explaining that a likely sensitive or blocked item was not saved."
                )

                Text(
                    "The warning row does not contain the rejected secret."
                )
            }
        }
    }

    private var appRulesArticle:
        some View
    {
        HelpArticle(
            title:
                "App Rules",
            introduction:
                "App Rules control how ClipVault handles text copied from individual applications."
        ) {
            HelpSectionView(
                title:
                    "Allowed"
            ) {
                Text(
                    "Normal clipboard content from the app can be saved."
                )

                Text(
                    "Sensitive-text protection still applies when it is enabled."
                )
            }

            HelpSectionView(
                title:
                    "Smart"
            ) {
                Text(
                    "ClipVault applies sensitive-content screening to text copied from the app."
                )

                Text(
                    "Smart is appropriate for password managers, developer tools, authentication apps, and other sources that may frequently place secrets on the clipboard."
                )
            }

            HelpSectionView(
                title:
                    "Blocked"
            ) {
                Text(
                    "ClipVault does not save copied text originating from the app."
                )

                Text(
                    "A normal Command–C copy remains on the system clipboard even though ClipVault does not retain it."
                )
            }

            HelpSectionView(
                title:
                    "Resetting Rules"
            ) {
                Text(
                    "Reset App Rules removes your customized app-specific choices and restores ClipVault’s default rule behavior."
                )
            }
        }
    }

    private var backupsArticle:
        some View
    {
        HelpArticle(
            title:
                "Backups",
            introduction:
                "ClipVault backup packages preserve supported history data and managed image assets."
        ) {
            HelpSectionView(
                title:
                    "Export Backup"
            ) {
                Text(
                    "Export Backup creates a .clipvaultbackup package containing the history manifest and the managed image files required by that history."
                )

                Text(
                    "After an export, ClipVault keeps the newest \(clipboardStore.backupKeepCount) backup package(s) according to the current General setting."
                )
            }

            HelpSectionView(
                title:
                    "Import Latest Backup"
            ) {
                Text(
                    "Import Latest Backup restores the newest valid .clipvaultbackup package from ClipVault’s Exports folder."
                )
            }

            HelpSectionView(
                title:
                    "Drag-and-Drop Import"
            ) {
                Text(
                    "You can drag one .clipvaultbackup package onto the main ClipVault window to import that package directly."
                )
            }

            HelpSectionView(
                title:
                    "Reveal Latest Backup"
            ) {
                Text(
                    "Reveal Latest Backup opens the newest backup package in Finder."
                )
            }

            HelpSectionView(
                title:
                    "Delete Old Backups"
            ) {
                Text(
                    "Delete Old Backups keeps the newest \(clipboardStore.backupKeepCount) backup package(s) and removes older packages from the Exports folder."
                )

                Text(
                    "Deleting old backup packages does not delete the current clipboard history stored inside ClipVault."
                )
            }

            HelpSectionView(
                title:
                    "Text Export"
            ) {
                Text(
                    "Export History creates a readable text document containing supported text from normal saved items. It is not a complete restorable backup."
                )
            }
        }
    }

    private var excelArticle:
        some View
    {
        HelpArticle(
            title:
                "Excel",
            introduction:
                "ClipVault preserves Excel clipboard content as editable cells when Excel provides compatible text, rich-text, or HTML representations."
        ) {
            HelpSectionView(
                title:
                    "Values and Cell Arrangement"
            ) {
                Text(
                    "When an Excel cell or range is restored from ClipVault, separate rows and columns remain available for pasting back into spreadsheet cells."
                )
            }

            HelpSectionView(
                title:
                    "Formatting"
            ) {
                Text(
                    "Supported formatting may survive through Excel’s rich-text or HTML clipboard representations."
                )

                Text(
                    "The exact result depends on the source content and the app receiving the paste."
                )
            }

            HelpSectionView(
                title:
                    "Formula Limitation"
            ) {
                Text(
                    "Excel formulas are restored as their calculated values."
                )
                .fontWeight(
                    .semibold
                )

                Text(
                    "Cell arrangement and supported formatting are preserved, but the original formula expressions are not retained after recalling an Excel item from ClipVault."
                )

                Text(
                    "This occurs because Excel relies on private, live clipboard data that cannot be reconstructed reliably from stored clipboard history."
                )
            }
        }
    }

    private var troubleshootingArticle:
        some View
    {
        HelpArticle(
            title:
                "Troubleshooting",
            introduction:
                "These checks address the most common reasons ClipVault may not behave as expected."
        ) {
            HelpSectionView(
                title:
                    "A New Copy Does Not Appear"
            ) {
                HelpBullet(
                    title:
                        "Monitoring",
                    body:
                        "Confirm that clipboard monitoring is not paused."
                )

                HelpBullet(
                    title:
                        "App Rules",
                    body:
                        "Check whether the source application is set to Blocked."
                )

                HelpBullet(
                    title:
                        "Sensitive content",
                    body:
                        "The item may have been skipped by sensitive-text protection."
                )

                HelpBullet(
                    title:
                        "Unsupported data",
                    body:
                        "The source app may have copied a clipboard representation that ClipVault does not currently store."
                )
            }

            HelpSectionView(
                title:
                    "A File Cannot Be Opened"
            ) {
                Text(
                    "Confirm that the original file still exists and that its drive or network volume is connected."
                )

                Text(
                    "A stored Finder reference can become unavailable after the original item is moved, renamed, or deleted."
                )
            }

            HelpSectionView(
                title:
                    "Screenshots Are Not Appearing"
            ) {
                HelpBullet(
                    title:
                        "Setting",
                    body:
                        "Confirm that automatic screenshot capture is enabled."
                )

                HelpBullet(
                    title:
                        "Folder access",
                    body:
                        "Reapprove the current macOS screenshot folder when requested."
                )

                HelpBullet(
                    title:
                        "Destination",
                    body:
                        "Confirm that macOS is still saving screenshots to the folder ClipVault is monitoring."
                )
            }

            HelpSectionView(
                title:
                    "Option-Selection Capture Does Not Work"
            ) {
                Text(
                    "Confirm that the feature is enabled and that ClipVault has the required macOS Accessibility permission."
                )

                Text(
                    "Some apps or custom text controls may not expose selections in a form that the capture feature can use."
                )
            }

            HelpSectionView(
                title:
                    "Restarting"
            ) {
                Text(
                    "Quit ClipVault completely and reopen it after changing macOS permissions or when an external application has stopped communicating with the clipboard normally."
                )
            }
        }
    }
}

private struct HelpArticle<Content>:
    View
where Content: View
{
    let title:
        String

    let introduction:
        String

    @ViewBuilder
    let content:
        Content

    init(
        title:
            String,
        introduction:
            String,
        @ViewBuilder content:
            () -> Content
    ) {
        self.title =
            title

        self.introduction =
            introduction

        self.content =
            content()
    }

    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                24
        ) {
            VStack(
                alignment:
                    .leading,
                spacing:
                    8
            ) {
                Text(
                    title
                )
                .font(
                    .largeTitle
                )
                .fontWeight(
                    .semibold
                )

                Text(
                    introduction
                )
                .font(
                    .title3
                )
                .foregroundStyle(
                    .secondary
                )
                .fixedSize(
                    horizontal:
                        false,
                    vertical:
                        true
                )
            }

            Divider()

            VStack(
                alignment:
                    .leading,
                spacing:
                    28
            ) {
                content
            }
        }
        .textSelection(
            .enabled
        )
    }
}

private struct HelpSectionView<Content>:
    View
where Content: View
{
    let title:
        String

    @ViewBuilder
    let content:
        Content

    init(
        title:
            String,
        @ViewBuilder content:
            () -> Content
    ) {
        self.title =
            title

        self.content =
            content()
    }

    var body:
        some View
    {
        VStack(
            alignment:
                .leading,
            spacing:
                10
        ) {
            Text(
                title
            )
            .font(
                .title3
            )
            .fontWeight(
                .semibold
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {
                content
            }
            .foregroundStyle(
                .primary
            )
            .fixedSize(
                horizontal:
                    false,
                vertical:
                    true
            )
        }
    }
}

private struct HelpBullet:
    View
{
    let title:
        String

    let text:
        String

    init(
        title:
            String,
        body:
            String
    ) {
        self.title =
            title

        self.text =
            body
    }

    var body:
        some View
    {
        HStack(
            alignment:
                .firstTextBaseline,
            spacing:
                8
        ) {
            Text(
                "•"
            )

            Text(
                "\(title): \(text)"
            )
        }
        .fixedSize(
            horizontal:
                false,
            vertical:
                true
        )
    }
}
