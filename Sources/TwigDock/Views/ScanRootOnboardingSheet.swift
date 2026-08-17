import SwiftUI

struct ScanRootOnboardingSheet: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 17)
                    )

                VStack(spacing: 7) {
                    Text("选择你的代码目录")
                        .font(.title2.weight(.bold))
                    Text("TwigDock 只会在你明确选择的目录中发现 Git 仓库和工作树。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("不会自动使用或猜测目录", systemImage: "checkmark.circle.fill")
                    Label("选择前不会开始端口与仓库扫描", systemImage: "checkmark.circle.fill")
                    Label("之后可随时在左下角更改", systemImage: "checkmark.circle.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
            }
            .padding(26)

            Divider()

            HStack {
                Text("首次使用必须先完成此配置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.chooseScanRoot()
                } label: {
                    Label("选择代码目录…", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 390)
    }
}
