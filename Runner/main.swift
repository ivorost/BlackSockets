//
//  main.swift
//  Runner
//
//  Created by Ivan Kh on 30.03.2021.
//

import Foundation

let portArgument = ProcessInfo.processInfo.arguments.count > 1 ? ProcessInfo.processInfo.arguments[1] : ""
let port = Int(portArgument) ?? 1337

SocketServer(port: port).runSync()
