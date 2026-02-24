import SwiftUI

struct KeyExportView: View {
    let base64Key: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Encryption Key")
                .font(.headline)

            Text(base64Key)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                UIPasteboard.general.string = base64Key
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            } label: {
                Label(
                    copied ? "Copied!" : "Copy to Clipboard",
                    systemImage: copied ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(copied ? .green : .accentColor)

            Text("Copy this key once and paste it into your agent config. It never leaves your device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
