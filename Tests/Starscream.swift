//
//  Starscream.swift
//  Tests
//
//  Created by Ivan Kh on 26.03.2021.
//

import Foundation
import Starscream
import BlackUtils

extension WebSocket {
    static func connect(url: URL) throws -> WebSocket {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        let socket = WebSocket(request: request)
        var completed: Func = { }
        var error: Error?
        
        socket.callbackQueue = DispatchQueue.global()
        socket.onEvent = { (event: WebSocketEvent) -> Void in
            switch event {
            case .connected(_):
                completed()
            case .error(let e):
                error = e
            completed()
            default:
                break
            }
        }
        
        socket.connect()
        
        wait { (done) in
            completed = done
        }
        
        if let error = error {
            throw error
        }
        
        return socket
    }
    
    func read() throws -> Data? {
        var result: Data?
        var error: Error?
        var completed: Func = { }
        
        onEvent = { (event: WebSocketEvent) -> Void in
            switch event {
            case .binary(let data):
                result = data
                completed()
                break
            case .error(let e):
                error = e
                completed()
            default:
                break
            }
        }
        
        wait { (done) in
            completed = done
        }
        
        if let error = error {
            throw error
        }
        
        return result
    }
}
