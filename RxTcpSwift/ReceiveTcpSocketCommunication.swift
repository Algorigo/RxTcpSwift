//
//  TcpSocketCommunication.swift
//  RxTcpSwift
//
//  Created by Jaehong Yoo on 2021/01/05.
//

import Foundation
import RxSwift

open class ReceiveTcpSocketCommunication {
    
    public static let TIMEOUT_MILLIS = 30000
    
    private let serverIp: String
    private let serverPort: Int
    let outputSubject = PublishSubject<Data>()
    
    public init(serverIp: String, serverPort: Int) {
        self.serverIp = serverIp
        self.serverPort = serverPort
    }
    
    public func connect(timeout: Int = ReceiveTcpSocketCommunication.TIMEOUT_MILLIS, printLog: Bool = false) -> Completable {
        var cacheData = Data()
        return RxTcp(url: serverIp, port: serverPort)
            .connect(output: outputSubject)
            .flatMap({ (rxTcp) -> Observable<Data> in
                rxTcp.getObservable()
            })
            .do(onNext: { (data) in
                cacheData.append(data)
                while true {
                    let verified = self.verifyReceivedData(data: cacheData)
                    cacheData = verified.rest
                    if let returnData = verified.returnData {
                        self.outputSubject.onNext(returnData)
                    } else {
                        break
                    }
                }
            })
            .ignoreElements()
    }
    
    open func verifyReceivedData(data: Data) -> (returnData: Data?, rest: Data) {
        fatalError("implement this method")
    }
    
    public func finalizeConnection() {
        outputSubject.onCompleted()
    }
}
