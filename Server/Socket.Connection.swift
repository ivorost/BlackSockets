//
//  Socket.Data.swift
//  TestSocketServer
//
//  Created by Ivan Kh on 22.03.2021.
//

import Foundation
import CommonCrypto
import Starscream
import Socket
import BlackUtils


fileprivate struct SocketUpgrade {
    let url: URL
    let key: String
    let version: Int
}


fileprivate extension Int {
    static let bufferSize = 4096
}


fileprivate extension String {
    static let queryItemRoom = "room"
    static let upgradeKey = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    static let threadNamePrefix = "socket-"
}


class SocketConnection : FramerEventClient {
    private let framer = WSFramer(isServer: true)
    private let socket: Socket
    private let house: SocketHouse
    private(set) var roomID: String?

    init(socket: Socket, house: SocketHouse) {
        self.socket = socket
        self.house = house
        framer.register(delegate: self)
    }
        
    func run() {
        execAsync(name: "\(String.threadNamePrefix)\(socket.socketfd)") { [self, socket] in
            do {
                try _run()
                house.close(socket.socketfd)
                print("Socket: \(socket.remoteHostname):\(socket.remotePort) closed...")
            }
            catch {
                if let socketError = error as? Socket.Error {
                    print("Error reported by connection at \(socket.remoteHostname):\(socket.remotePort):\n \(socketError.description)")
                }
                else {
                    print("Unexpected error by connection at \(socket.remoteHostname):\(socket.remotePort)...")
                }
            }
        }
    }
    
    func _run() throws {
        var readData = Data(capacity: .bufferSize)
        var socketUpgrade: SocketUpgrade?

        repeat {
            let bytesRead = try socket.read(into: &readData)
            guard bytesRead > 0 else { break }

            if socketUpgrade == nil, let upgrade = SocketUpgrade(data: readData) {
                let upgradeResponse = String.response(upgrade: upgrade)
                
                socketUpgrade = upgrade
                
                if let urlComponents = URLComponents(string: upgrade.url.absoluteString),
                   let queryItems = urlComponents.queryItems,
                   let roomItem = queryItems.first(where: { $0.name == .queryItemRoom }),
                   let roomItemValue = roomItem.value {

                    roomID = roomItem.value
                    house.append(socket: socket, to: roomItemValue)
                }
                else {
                    print("[\(String.queryItemRoom)] is mandatory query parameter")
                    break
                }
                
                if let upgradeResponseData = upgradeResponse.data(using: .utf8) {
                    try socket.write(from: upgradeResponseData)
                }
                
                readData.count = 0
                continue
            }
            
            framer.add(data: readData)
            readData.count = 0
            
        } while true
    }
    
    func frameProcessed(event: FrameEvent) {
        switch event {
        case .frame(let frame):
            guard let roomID = roomID else { print("Error decoding response (missed room)..."); break }
            let roomSockets = house.sockets(in: roomID)
            
            for roomSocket in roomSockets {
                guard roomSocket.socketfd != socket.socketfd else { continue }
               
                do {
                    let data = framer.createWriteFrame(opcode: frame.opcode,
                                                       payload: frame.payload,
                                                       isCompressed: frame.needsDecompression)
                    try roomSocket.write(from: data)
                }
                catch {
                    print("error writing to socket \(roomSocket.socketfd): \(error)")
                }
            }

            print("frame: \(frame.payload.count)")
        case .error(let error):
            print("framer error: \(error)")
        }
    }
}


fileprivate extension SocketUpgrade {
    init?(data: Data) {
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        
        let splitArr = str.components(separatedBy: "\r\n")
        var path: String?
        var i = 0
        var headers = [String: String]()
        
        for str in splitArr {
            if i == 0 {
                let responseSplit = str.components(separatedBy: .whitespaces)
                guard responseSplit.count > 1 else { assert(false); return nil }
                path = responseSplit[1]
            }
            else {
                guard let separatorIndex = str.firstIndex(of: ":") else { break }
                let key = str.prefix(upTo: separatorIndex).trimmingCharacters(in: .whitespaces)
                let val = str.suffix(from: str.index(after: separatorIndex)).trimmingCharacters(in: .whitespaces)
                headers[key.lowercased()] = val
            }
            
            i += 1
        }
        
        guard
            headers["connection"]?.lowercased() == "upgrade",
            headers["upgrade"]?.lowercased() == "websocket",
            let thePath = path,
            let origin = headers["origin"],
            let url = URL(string: "\(origin)\(thePath)"),
            let key = headers["sec-websocket-key"],
            let versionString = headers["sec-websocket-version"],
            let version = Int(versionString)
        else {
            return nil
        }
        
        self.url = url
        self.key = key
        self.version = version
    }
}


fileprivate extension String {
    func sha1Base64() -> String {
        let data = self.data(using: .utf8)!
        let pointer = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
            CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
            return digest
        }
        
        return Data(pointer).base64EncodedString()
    }

    static func response(upgrade: SocketUpgrade) -> String {
        let accept = "\(upgrade.key)\(upgradeKey)".sha1Base64()
        
        return """
        HTTP/1.1 101 Switching Protocols
        Upgrade: websocket
        Connection: Upgrade
        Sec-WebSocket-Accept: \(accept)
        Sec-WebSocket-Protocol: chat


        """.replacingOccurrences(of: "\n", with: "\r\n")
    }
}
