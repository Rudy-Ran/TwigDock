import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TwigDockMark(size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text("TwigDock")
                        .font(.headline)
                        .lineLimit(1)
                    Text("枝坞 · 本地开发控制台")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 7) {
                Text("工作区")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)

                VStack(spacing: 3) {
                    ForEach(AppSection.allCases) { section in
                        SidebarNavigationRow(
                            section: section,
                            isSelected: model.selectedSection == section
                        ) {
                            model.selectedSection = section
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("扫描目录", systemImage: "folder")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Button("更改") {
                        model.chooseScanRoot()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.tint)
                }
                Text(model.scanRoot?.path.abbreviatingWithTildeInPath ?? "尚未配置")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .help(model.scanRoot?.path ?? "请先选择代码目录")

                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    if !model.hasConfiguredScanRoot {
                        Text("需要选择目录")
                    } else if model.isRefreshing {
                        Text("正在刷新…")
                    } else if let date = model.lastUpdated {
                        Text("更新于 \(date.formatted(date: .omitted, time: .shortened))")
                    } else {
                        Text("等待首次扫描")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.035))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationSplitViewColumnWidth(min: 208, ideal: 224, max: 270)
    }

    private var statusColor: Color {
        if !model.hasConfiguredScanRoot { return .secondary }
        return model.isRefreshing ? .orange : .green
    }
}

private struct SidebarNavigationRow: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                Text(section.title)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.body)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(section.title)
    }

    private var rowBackground: Color {
        if isSelected { return .accentColor }
        if isHovering { return Color.primary.opacity(0.065) }
        return .clear
    }
}
