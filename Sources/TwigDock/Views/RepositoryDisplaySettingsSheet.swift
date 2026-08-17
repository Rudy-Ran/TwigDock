import SwiftUI

struct RepositoryDisplaySettingsSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let repository: RepositoryRecord

    @State private var alias = ""

    private var trimmedAlias: String {
        alias.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewName: String {
        guard !trimmedAlias.isEmpty else { return repository.name }
        return "\(repository.name)（\(trimmedAlias)）"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text("项目显示设置")
                        .font(.title2.weight(.bold))
                    Text("只改变 TwigDock 中的展示，不修改 Git 仓库。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(22)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("仓库")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(repository.name)
                        .font(.headline.monospaced())
                    Text(repository.primaryPath.path.abbreviatingWithTildeInPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("额外显示名称")
                        .font(.headline)
                    TextField("例如：日常考勤、客户 A、联调环境", text: $alias)
                        .textFieldStyle(.roundedBorder)
                    Text("留空会恢复仓库原名；名称保存在本机。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("预览")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Label(previewName, systemImage: "shippingbox")
                        .font(.headline)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                }
            }
            .padding(22)

            Spacer(minLength: 0)
            Divider()

            HStack {
                if !model.repositoryAlias(for: repository).isEmpty {
                    Button("清除名称") {
                        alias = ""
                    }
                }
                Spacer()
                Button("取消") {
                    model.repositoryBeingConfigured = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("保存") {
                    model.setRepositoryAlias(alias, for: repository)
                    model.repositoryBeingConfigured = nil
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 430)
        .onAppear {
            alias = model.repositoryAlias(for: repository)
        }
    }
}
