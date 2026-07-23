//
//  ClipboardLinkClassificationService.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/15/26.
//

import Foundation

enum ClipboardLinkClassificationService
{
    /*
     Common filename extensions that would otherwise
     resemble a scheme-less domain.
     */
    private static let likelyFileExtensions:
        Set<String> =
            [
                "app",
                "csv",
                "dmg",
                "doc",
                "docx",
                "gif",
                "heic",
                "jpeg",
                "jpg",
                "json",
                "mov",
                "mp3",
                "mp4",
                "pdf",
                "png",
                "ppt",
                "pptx",
                "rtf",
                "swift",
                "txt",
                "xls",
                "xlsx",
                "zip"
            ]

    static func isLink(
        _ text:
            String
    ) -> Bool {
        normalizedURLString(
            for:
                text
        ) !=
            nil
    }

    static func normalizedURLString(
        for text:
            String
    ) -> String? {
        let trimmedText =
            text
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard
            !trimmedText.isEmpty,
            trimmedText
                .rangeOfCharacter(
                    from:
                        .whitespacesAndNewlines
                ) ==
                nil,
            !trimmedText.contains(
                "@"
            )
        else {
            return nil
        }

        if let existingScheme =
            URLComponents(
                string:
                    trimmedText
            )?
            .scheme
        {
            let normalizedScheme =
                existingScheme
                    .lowercased()

            guard
                normalizedScheme ==
                    "http" ||
                    normalizedScheme ==
                    "https"
            else {
                return nil
            }

            return validatedURLString(
                trimmedText,
                requiresPublicDomain:
                    false,
                originalTextHadScheme:
                    true
            )
        }

        return validatedURLString(
            "https://" +
                trimmedText,
            requiresPublicDomain:
                true,
            originalTextHadScheme:
                false
        )
    }

    private static func validatedURLString(
        _ candidate:
            String,
        requiresPublicDomain:
            Bool,
        originalTextHadScheme:
            Bool
    ) -> String? {
        guard
            let components =
                URLComponents(
                    string:
                        candidate
                ),
            let scheme =
                components
                    .scheme?
                    .lowercased(),
            scheme ==
                "http" ||
                scheme ==
                "https",
            let host =
                components
                    .host?
                    .lowercased(),
            !host.isEmpty
        else {
            return nil
        }

        if requiresPublicDomain {
            guard
                isValidPublicDomain(
                    host
                )
            else {
                return nil
            }

            if
                looksLikeStandaloneFilename(
                    components:
                        components,
                    host:
                        host
                )
            {
                return nil
            }
        } else {
            /*
             Explicit HTTP and HTTPS URLs may use
             localhost or another host form supported by
             URLComponents.
             */
            guard
                host ==
                    "localhost" ||
                    isValidPublicDomain(
                        host
                    ) ||
                    isValidIPv4Address(
                        host
                    )
            else {
                return nil
            }
        }

        guard
            let normalizedURL =
                components
                    .url
        else {
            return nil
        }

        /*
         Preserve the user's explicit HTTP or HTTPS
         spelling. Scheme-less addresses are normalized
         to HTTPS for opening and preview loading.
         */
        return originalTextHadScheme
            ? candidate
            : normalizedURL
                .absoluteString
    }

    private static func isValidPublicDomain(
        _ host:
            String
    ) -> Bool {
        guard
            host.contains(
                "."
            ),
            !host.hasPrefix(
                "."
            ),
            !host.hasSuffix(
                "."
            )
        else {
            return false
        }

        let labels =
            host.split(
                separator:
                    ".",
                omittingEmptySubsequences:
                    false
            )

        guard
            labels.count >=
                2
        else {
            return false
        }

        for label in labels {
            guard
                !label.isEmpty,
                label.count <=
                    63,
                label.first !=
                    "-",
                label.last !=
                    "-"
            else {
                return false
            }

            let isValidLabel =
                label.allSatisfy {
                    character in

                    character.isLetter ||
                    character.isNumber ||
                    character ==
                        "-"
                }

            guard
                isValidLabel
            else {
                return false
            }
        }

        guard
            let topLevelDomain =
                labels.last
        else {
            return false
        }

        let isPunycodeTopLevelDomain =
            topLevelDomain
                .lowercased()
                .hasPrefix(
                    "xn--"
                )

        let isAlphabeticTopLevelDomain =
            topLevelDomain.count >=
                2 &&
            topLevelDomain
                .allSatisfy {
                    $0.isLetter
                }

        return isAlphabeticTopLevelDomain ||
            isPunycodeTopLevelDomain
    }

    private static func looksLikeStandaloneFilename(
        components:
            URLComponents,
        host:
            String
    ) -> Bool {
        guard
            components.path.isEmpty ||
            components.path ==
                "/",
            components.query ==
                nil,
            components.fragment ==
                nil,
            let finalComponent =
                host
                    .split(
                        separator:
                            "."
                    )
                    .last
        else {
            return false
        }

        return likelyFileExtensions
            .contains(
                finalComponent
                    .lowercased()
            )
    }

    private static func isValidIPv4Address(
        _ host:
            String
    ) -> Bool {
        let parts =
            host.split(
                separator:
                    "."
            )

        guard
            parts.count ==
                4
        else {
            return false
        }

        return parts.allSatisfy {
            part in

            guard
                let value =
                    Int(
                        part
                    )
            else {
                return false
            }

            return value >=
                0 &&
                value <=
                    255
        }
    }
}
