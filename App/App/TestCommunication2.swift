//
//  TestCommunication2.swift
//  App
//
//  Created by Jaehong Yoo on 2021/01/06.
//

import Foundation
import RxTcpSwift
import RxSwift

class TestCommunication2: SendingTcpSocketCommunication {
    
    init() {
        super.init(serverIp: "192.168.35.104", serverPort: 8082)
    }
    
    func connectCompletable(timeout: Int = SendingTcpSocketCommunication.TIMEOUT_MILLIS, printLog: Bool = false) -> Completable {
        connect(timeout: timeout, printLog: printLog)
            .flatMap { (communication) -> Observable<Int> in
                communication.sendDataCompletable(text: "123")
                    .andThen(communication.sendDataCompletable(text: "456"))
                    .andThen(Observable.just(1))
                    .do(onCompleted: {
                        communication.finalizeConnection()
                    })
            }
            .ignoreElements()
    }
}

extension SendingTcpSocketCommunication {
    fileprivate func sendDataCompletable(text: String) -> Completable {
        sendData(data: text.data(using: .utf8)!) { (data) -> Bool in
            return data.count == 2
        }
        .asCompletable()
    }
}
