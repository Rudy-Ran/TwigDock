import XCTest
@testable import TwigDock

final class PortServiceTests: XCTestCase {
    private let service = PortService()

    func testParsesTCPListenersAndKeepsProcessContext() {
        let output = """
        p301
        cnode
        f19
        PTCP
        n127.0.0.1:5173
        f20
        PTCP
        n*:3000
        p402
        cpython3
        f8
        PTCP
        n[::1]:8000
        """

        XCTAssertEqual(
            service.parseLsof(output, protocolHint: "TCP"),
            [
                LsofListener(
                    pid: 301,
                    processName: "node",
                    protocolName: "TCP",
                    endpoint: "127.0.0.1:5173",
                    port: 5173
                ),
                LsofListener(
                    pid: 301,
                    processName: "node",
                    protocolName: "TCP",
                    endpoint: "*:3000",
                    port: 3000
                ),
                LsofListener(
                    pid: 402,
                    processName: "python3",
                    protocolName: "TCP",
                    endpoint: "[::1]:8000",
                    port: 8000
                )
            ]
        )
    }

    func testIgnoresConnectedUDPEndpointsAndNonNumericPorts() {
        let output = """
        p77
        cmDNSResponder
        f5
        PUDP
        n*:5353
        f6
        PUDP
        n10.0.0.2:5353->224.0.0.251:5353
        f7
        PUDP
        n*:*
        """

        XCTAssertEqual(
            service.parseLsof(output, protocolHint: "UDP"),
            [
                LsofListener(
                    pid: 77,
                    processName: "mDNSResponder",
                    protocolName: "UDP",
                    endpoint: "*:5353",
                    port: 5353
                )
            ]
        )
    }

    func testParsesIPv4IPv6AndListenSuffix() {
        XCTAssertEqual(PortService.port(from: "127.0.0.1:4173"), 4173)
        XCTAssertEqual(PortService.port(from: "[::1]:8080"), 8080)
        XCTAssertEqual(PortService.port(from: "*:3000 (LISTEN)"), 3000)
        XCTAssertNil(PortService.port(from: "*:*"))
        XCTAssertNil(PortService.port(from: "127.0.0.1:10->127.0.0.1:11"))
    }

    func testParsesCurrentDirectories() {
        let output = """
        p101
        cnode
        fcwd
        n/Users/me/Code/alpha
        p202
        cpython
        fcwd
        n/Users/me/Code/beta
        """

        let result = service.parseCurrentDirectories(output)
        XCTAssertEqual(result[101]?.path, "/Users/me/Code/alpha")
        XCTAssertEqual(result[202]?.path, "/Users/me/Code/beta")
    }

    func testParsesProcessMetadataWithSpacesInCommand() {
        let output = """
          101  01:03:20 node /Users/me/app/server.js --port 3000
          202     02:11 python3 -m http.server 8000
        """

        let result = service.parseProcessMetadata(output)
        XCTAssertEqual(
            result[101],
            ProcessMetadata(
                elapsed: "01:03:20",
                command: "node /Users/me/app/server.js --port 3000"
            )
        )
        XCTAssertEqual(
            result[202],
            ProcessMetadata(elapsed: "02:11", command: "python3 -m http.server 8000")
        )
    }
}
