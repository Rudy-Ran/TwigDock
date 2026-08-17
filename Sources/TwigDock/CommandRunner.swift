import Foundation

struct CommandResult: Sendable {
    let standardOutput: String
    let standardError: String
    let exitCode: Int32
}

struct CommandFailure: LocalizedError, Sendable {
    let executable: String
    let arguments: [String]
    let exitCode: Int32
    let errorOutput: String

    var errorDescription: String? {
        let command = ([executable] + arguments).joined(separator: " ")
        let detail = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty
            ? "命令执行失败（退出码 \(exitCode)）：\(command)"
            : "\(detail)\n\n命令：\(command)"
    }
}

struct CommandRunner: Sendable {
    func run(
        _ executable: String,
        arguments: [String] = [],
        currentDirectory: URL? = nil
    ) throws -> CommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return CommandResult(
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }

    func runSuccessful(
        _ executable: String,
        arguments: [String] = [],
        currentDirectory: URL? = nil
    ) throws -> String {
        let result = try run(
            executable,
            arguments: arguments,
            currentDirectory: currentDirectory
        )
        guard result.exitCode == 0 else {
            throw CommandFailure(
                executable: executable,
                arguments: arguments,
                exitCode: result.exitCode,
                errorOutput: result.standardError
            )
        }
        return result.standardOutput
    }
}
