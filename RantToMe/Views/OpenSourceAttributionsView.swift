//
//  OpenSourceAttributionsView.swift
//  RantToMe
//

import SwiftUI

struct OpenSourceAttributionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedLicenses: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Open Source Licenses")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            List {
                ForEach(OpenSourceLicense.allLicenses) { license in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedLicenses.contains(license.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedLicenses.insert(license.id)
                                } else {
                                    expandedLicenses.remove(license.id)
                                }
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(license.copyright)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(license.licenseType)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Link(destination: license.repositoryURL) {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                    Text("View on GitHub")
                                }
                                .font(.subheadline)
                            }

                            Divider()

                            ScrollView {
                                Text(license.licenseText)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 150)
                        }
                        .padding(.top, 8)
                    } label: {
                        Text(license.name)
                            .font(.body)
                    }
                }
            }
        }
        .frame(width: 500, height: 450)
    }
}

#Preview {
    OpenSourceAttributionsView()
}
