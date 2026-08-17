import SwiftUI

struct PortsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(
                        title: "端口管理",
                        subtitle: "查看本机 TCP 监听与 UDP 端点，并安全停止对应进程。"
                    )

                    HStack(spacing: 10) {
                        TextField("搜索端口、进程、PID 或项目", text: $model.portSearch)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 360)
                        Picker("范围", selection: $model.portScope) {
                            ForEach(PortScope.allCases) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 330)
                        Spacer()
                        Text("\(model.filteredPorts.count) 项")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)

                Divider()

                Table(model.filteredPorts, selection: $model.selectedPortID) {
                    TableColumn("端口") { port in
                        Text(String(port.port))
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.blue)
                            .monospacedDigit()
                    }
                    .width(min: 50, ideal: 58, max: 68)

                    TableColumn("进程") { port in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(port.processName)
                                .lineLimit(1)
                            Text("PID " + String(port.pid) + " · " + port.runtime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .width(min: 105, ideal: 120, max: 165)

                    TableColumn("项目") { port in
                        if port.projectName != nil {
                            Label(model.displayName(for: port), systemImage: "shippingbox")
                                .lineLimit(1)
                        } else {
                            Text("未关联")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .width(min: 78, ideal: 100, max: 150)

                    TableColumn("地址 / 协议") { port in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(port.localAddress)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                            Text(port.protocolName + " · " + port.state)
                                .font(.caption2.monospaced())
                                .foregroundStyle(
                                    port.protocolName == "TCP" ? Color.green : Color.blue
                                )
                                .lineLimit(1)
                        }
                        .help(port.localAddress)
                    }
                    .width(min: 115, ideal: 140, max: 200)
                }
                .scrollIndicators(.hidden, axes: .horizontal)
                .overlay {
                    if model.filteredPorts.isEmpty {
                        EmptyStateView(
                            systemImage: "antenna.radiowaves.left.and.right.slash",
                            title: model.ports.isEmpty ? "暂时没有监听端口" : "没有匹配结果",
                            detail: model.ports.isEmpty
                                ? "TwigDock 会每 5 秒自动刷新。"
                                : "试试调整搜索词或筛选范围。"
                        )
                    }
                }
            }
            .frame(minWidth: 520, idealWidth: 700)
            .layoutPriority(1)

            if let port = model.selectedPort {
                PortInspector(model: model, port: port)
                    .frame(minWidth: 245, idealWidth: 285, maxWidth: 350)
            } else {
                InspectorPlaceholder(
                    systemImage: "cursorarrow.click.2",
                    title: "选择一个端口",
                    detail: "这里会显示进程命令、运行目录和快捷操作。"
                )
                .frame(minWidth: 220, idealWidth: 250, maxWidth: 290)
            }
        }
    }
}

private struct PortInspector: View {
    @ObservedObject var model: AppModel
    let port: PortRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(":" + String(port.port))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(.blue)
                        Spacer()
                        PortStatePill(port: port)
                    }
                    Text(port.processName)
                        .font(.title3.weight(.semibold))
                    Text("PID " + String(port.pid) + " · 已运行 " + port.elapsed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if port.browserURL != nil {
                    ActionButton(
                        title: "在浏览器打开",
                        systemImage: "safari",
                        prominent: true
                    ) {
                        model.openInBrowser(port)
                    }
                }

                HStack(spacing: 8) {
                    ActionButton(title: "复制地址", systemImage: "doc.on.doc") {
                        model.copyAddress(port)
                    }
                    if let directory = port.currentDirectory {
                        ActionButton(title: "终端", systemImage: "terminal") {
                            model.openTerminal(at: directory)
                        }
                    }
                }

                Divider()

                InspectorSection("连接") {
                    InspectorValueRow(label: "本地地址", value: port.localAddress, monospaced: true)
                    InspectorValueRow(label: "协议", value: port.protocolName)
                    InspectorValueRow(label: "状态", value: port.state)
                }

                InspectorSection("进程") {
                    InspectorValueRow(label: "运行时", value: port.runtime)
                    InspectorValueRow(label: "PID", value: String(port.pid), monospaced: true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("启动命令")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(port.command)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
                    }
                }

                InspectorSection("项目关联") {
                    InspectorValueRow(label: "项目", value: model.displayName(for: port))
                    if let directory = port.currentDirectory {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("工作目录")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(directory.path.abbreviatingWithTildeInPath)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }

                Divider()

                Button(role: .destructive) {
                    model.requestStop(port)
                } label: {
                    Label("停止进程", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(model.isMutating)

                Text("停止操作会发送 SIGTERM，让进程有机会正常退出。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct InspectorPlaceholder: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        EmptyStateView(systemImage: systemImage, title: title, detail: detail)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
    }
}
