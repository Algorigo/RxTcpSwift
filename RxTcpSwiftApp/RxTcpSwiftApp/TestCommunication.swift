//
//  TestCommunication.swift
//  App
//
//  Created by Jaehong Yoo on 2021/01/05.
//

import Foundation
import RxTcpSwift

class TestCommunication: ReceiveTcpSocketCommunication {
    
    init() {
        super.init(serverIp: "192.168.35.104", serverPort: 8081)
    }
    
    override func verifyReceivedData(data: Data) -> (returnData: Data?, rest: Data) {
        if data.count >= 3 {
            return (returnData: data.subdata(in: 0..<3), rest: data.subdata(in: 3..<data.count))
        } else {
            return (returnData: nil, rest: data)
        }
    }
}
