//
//  EchoServer.swift
//  TestSocketServer
//
//  Created by Ivan Kh on 17.03.2021.
//

import Foundation
import Socket
import BlackUtils

fileprivate extension String {
    static let threadNameServer = "socket-run"
}


public class SocketServer {
    private let port: Int
    private var continueRunning = true
    private let house = SocketHouse()
    
    public init(port: Int) {
        self.port = port
    }
    
    deinit {
        house.close()
    }
    
    public func run() {
        print("Running in progress...")

        execAsync(name: .threadNameServer) { [self] in
            runSync()
        }
    }
    
    public func runSync() {
        do {
            let socket = try Socket.create(family: .inet)
            try socket.listen(on: self.port)
            
            print("Listening on port: \(socket.listeningPort)")
            
            repeat {
                let connectedSocket = try socket.acceptClientConnection()
                let connection = SocketConnection(socket: connectedSocket, house: house)

                print("Accepted connection from: \(connectedSocket.remoteHostname) on port \(connectedSocket.remotePort)")
                print("Socket Signature: \(String(describing: connectedSocket.signature?.description))")
                
                house.append(socket)
                connection.run()

            } while self.continueRunning
        }
        catch {
            guard let socketError = error as? Socket.Error else {
                print("Unexpected error...")
                return
            }
            
            if self.continueRunning {
                print("Error reported:\n \(socketError.description)")
            }
        }

        house.close()
    }

    public func stop() {
        print("Shutdown in progress...")

        self.continueRunning = false
        house.close()
    }
}

