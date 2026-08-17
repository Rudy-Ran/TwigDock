import Darwin
import Foundation

struct LsofListener: Equatable, Sendable {
    let pid: Int32
    let processName: String
    let protocolName: String
    let endpoint: String
    let port: Int
}

struct ProcessMetadata: Equatable, Sendable {
    let elapsed: String
    let command: String
}

enum PortServiceError: LocalizedError {
    case refusingToStopSelf
    case invalidProcess
    case stopFailed(pid: Int32, code: Int32)

    var errorDescription: String? {
        switch self {
        case .refusingToStopSelf:
            "不能在 TwigDock 内停止 TwigDock 自身。"
        case .invalidProcess:
            "进程标识无效。"
        case let .stopFailed(pid, code):
            "无法停止进程 \(pid)：\(String(cString: strerror(code)))"
        }
    }
}

struct PortService: Sendable {
    private let runner = CommandRunner()

    func scan() throws -> [PortRecord] {
        let tcpResult = try runner.run(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcPn"]
        )
        let udpResult = try runner.run(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-iUDP", "-FpcPn"]
        )

        let tcp = try listeners(from: tcpResult, protocolHint: "TCP")
        let udp = try listeners(from: udpResult, protocolHint: "UDP")
        let listeners = deduplicate(tcp + udp)
        guard !listeners.isEmpty else { return [] }

        let processIDs = Array(Set(listeners.map(\.pid))).sorted()
        let currentDirectories = currentDirectories(for: processIDs)
        let metadata = processMetadata(for: processIDs)

        return listeners.map { listener in
            let detail = metadata[listener.pid]
            return PortRecord(
                id: "\(listener.pid)-\(listener.protocolName)-\(listener.port)",
                port: listener.port,
                processName: listener.processName,
                pid: listener.pid,
                protocolName: listener.protocolName,
                localAddress: listener.endpoint,
                state: listener.protocolName == "TCP" ? "监听中" : "UDP",
                runtime: Self.inferRuntime(
                    processName: listener.processName,
                    command: detail?.command ?? ""
                ),
                command: detail?.command ?? listener.processName,
                elapsed: detail?.elapsed ?? "—",
                currentDirectory: currentDirectories[listener.pid],
                projectName: nil,
                worktreeID: nil
            )
        }
        .sorted {
            if $0.port == $1.port { return $0.pid < $1.pid }
            return $0.port < $1.port
        }
    }

    func stop(pid: Int32) throws {
        guard pid > 0 else { throw PortServiceError.invalidProcess }
        guard pid != getpid() else { throw PortServiceError.refusingToStopSelf }
        guard Darwin.kill(pid, SIGTERM) == 0 else {
            if errno == ESRCH { return }
            throw PortServiceError.stopFailed(pid: pid, code: errno)
        }
    }

    func parseLsof(_ output: String, protocolHint: String) -> [LsofListener] {
        var currentPID: Int32?
        var currentProcess = "未知进程"
        var currentProtocol = protocolHint
        var listeners: [LsofListener] = []

        for line in output.split(whereSeparator: \.isNewline) {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())

            switch field {
            case "p":
                currentPID = Int32(value)
                currentProcess = "未知进程"
                currentProtocol = protocolHint
            case "c":
                currentProcess = value
            case "P":
                currentProtocol = value.uppercased()
            case "n":
                guard let pid = currentPID,
                      !value.contains("->"),
                      let port = Self.port(from: value) else { continue }
                listeners.append(
                    LsofListener(
                        pid: pid,
                        processName: currentProcess,
                        protocolName: currentProtocol,
                        endpoint: value,
                        port: port
                    )
                )
            default:
                continue
            }
        }

        return listeners
    }

    func parseCurrentDirectories(_ output: String) -> [Int32: URL] {
        var currentPID: Int32?
        var values: [Int32: URL] = [:]

        for line in output.split(whereSeparator: \.isNewline) {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())
            if field == "p" {
                currentPID = Int32(value)
            } else if field == "n", let currentPID, value.hasPrefix("/") {
                values[currentPID] = URL(fileURLWithPath: value).standardizedFileURL
            }
        }
        return values
    }

    func parseProcessMetadata(_ output: String) -> [Int32: ProcessMetadata] {
        var values: [Int32: ProcessMetadata] = [:]

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let components = rawLine.split(
                maxSplits: 2,
                omittingEmptySubsequences: true,
                whereSeparator: \.isWhitespace
            )
            guard components.count == 3, let pid = Int32(components[0]) else { continue }
            values[pid] = ProcessMetadata(
                elapsed: String(components[1]),
                command: String(components[2])
            )
        }
        return values
    }

    static func port(from endpoint: String) -> Int? {
        let cleaned = endpoint
            .replacingOccurrences(of: " (LISTEN)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.contains("->"),
              let separator = cleaned.lastIndex(of: ":") else { return nil }
        let value = cleaned[cleaned.index(after: separator)...]
        return Int(value)
    }

    static func inferRuntime(processName: String, command: String) -> String {
        let value = "\(processName) \(command)".lowercased()
        if value.contains("node") || value.contains("npm") || value.contains("pnpm") || value.contains("yarn") {
            return "Node.js"
        }
        if value.contains("python") { return "Python" }
        if value.contains("java") { return "Java"
        }
        if value.contains("ruby") { return "Ruby" }
        if value.contains("docker") { return "Docker" }
        if value.contains("swift") { return "Swift" }
        return processName
    }

    private func listeners(
        from result: CommandResult,
        protocolHint: String
    ) throws -> [LsofListener] {
        if result.exitCode != 0 && result.exitCode != 1 {
            throw CommandFailure(
                executable: "/usr/sbin/lsof",
                arguments: [],
                exitCode: result.exitCode,
                errorOutput: result.standardError
            )
        }
        return parseLsof(result.standardOutput, protocolHint: protocolHint)
    }

    private func deduplicate(_ values: [LsofListener]) -> [LsofListener] {
        var seen: Set<String> = []
        return values.filter { value in
            seen.insert("\(value.pid)-\(value.protocolName)-\(value.port)").inserted
        }
    }

    private func currentDirectories(for pids: [Int32]) -> [Int32: URL] {
        guard !pids.isEmpty else { return [:] }
        let result = try? runner.run(
            "/usr/sbin/lsof",
            arguments: [
                "-a", "-p", pids.map(String.init).joined(separator: ","),
                "-d", "cwd", "-Fpcn"
            ]
        )
        return result.map { parseCurrentDirectories($0.standardOutput) } ?? [:]
    }

    private func processMetadata(for pids: [Int32]) -> [Int32: ProcessMetadata] {
        guard !pids.isEmpty else { return [:] }
        let result = try? runner.run(
            "/bin/ps",
            arguments: [
                "-p", pids.map(String.init).joined(separator: ","),
                "-o", "pid=,etime=,command="
            ]
        )
        return result.map { parseProcessMetadata($0.standardOutput) } ?? [:]
    }
}
