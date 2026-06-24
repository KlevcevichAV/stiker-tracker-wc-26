import SwiftUI
import UIKit

struct MigrationErrorView: View {
    let errorText: String
    @State private var copied = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            Text("Migration Error")
                .font(.title2.bold())

            Text("The database could not be opened. Your data is safe — the app will not start until the issue is resolved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ScrollView {
                Text(errorText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 260)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                UIPasteboard.general.string = errorText
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            } label: {
                Label(copied ? "Copied!" : "Copy Error", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(copied ? .green : .blue)
        }
        .padding(24)
    }
}
