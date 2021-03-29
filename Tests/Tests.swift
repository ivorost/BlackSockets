//
//  BlackSocketsTests.swift
//  BlackSocketsTests
//
//  Created by Ivan Kh on 23.03.2021.
//

import BlackUtils
import Starscream
import XCTest
@testable import BlackSockets


class BlackSocketsTests: XCTestCase {

    func test_server_lifecycle() {
        for _ in 0 ..< 10 {
            let server = SocketServer(port: 1337)
            server.run()
            server.stop()
        }
    }
    
    func test_connection() throws {
        let server = SocketServer(port: 1337)
        server.run()

        let roomID = UUID().uuidString
        let socket1 = try WebSocket.connect(url: URL(string: "ws://localhost:1337?room=\(roomID)")!)
        let socket2 = try WebSocket.connect(url: URL(string: "ws://localhost:1337?room=\(roomID)")!)

        DispatchQueue.global().asyncAfter0_5 {
            socket1.write(data: "test".data(using: .utf8)!)
        }

        if let data = try socket2.read() {
            XCTAssert(String(data: data, encoding: .utf8) == "test")
        }
        else {
            XCTAssert(false)
        }

        server.stop()
    }
}
