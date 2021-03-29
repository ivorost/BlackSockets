//
//  Socket.Apart.swift
//  TestSocketServer
//
//  Created by Ivan Kh on 22.03.2021.
//

import Foundation
import Socket

class SocketHouse {
    private var sockets = [Int32: Socket]()
    private var rooms = [String: [Socket]]() // roomID to many sockets
    private var socketRooms = [Int32: [String]]() // socketID to roomIDs
    private let lock = NSLock()
    
    func sockets(in room: String) -> [Socket] {
        return rooms[room] ?? []
    }
    
    func append(_ socket: Socket) {
        lock.locked {
            sockets[socket.socketfd] = socket
        }
    }
        
    func append(socket: Socket, to room: String) {
        lock.locked {
            if rooms[room] == nil {
                rooms[room] = []
            }

            if socketRooms[socket.socketfd] == nil {
                socketRooms[socket.socketfd] = []
            }

            rooms[room]?.append(socket)
            socketRooms[socket.socketfd]?.append(room)
        }
    }
    
    func remove(socket socketID: Int32, from room: String) {
        lock.locked {
            rooms[room]?.removeAll { $0.socketfd == socketID }
            socketRooms[socketID]?.removeAll { $0 == room }
        }
    }
    
    func close(_ socketID: Int32) {
        lock.locked {
            sockets[socketID] = nil
            
            if let socketRooms = socketRooms[socketID] {
                for room in socketRooms {
                    rooms[room]?.removeAll { $0.socketfd == socketID }
                }
            }
            
            socketRooms[socketID]?.removeAll()
        }
    }

    func close() {
        lock.locked {
            for socket in sockets.values {
                socket.close()
            }
            
            sockets.removeAll()
            rooms.removeAll()
        }
    }
}
