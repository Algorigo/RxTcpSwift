//
//  SendingTcpSocketCommunication.swift
//  RxTcpSwift
//
//  Created by Jaehong Yoo on 2021/01/05.
//

import Foundation
import RxSwift

open class SendingTcpSocketCommunication {
    
    public static let TIMEOUT_MILLIS = 30000
    
    private let serverIp: String
    private let serverPort: Int
    let outputSubject = PublishSubject<Data>()
    var sendDataArray = [(id: Int, subject: PublishSubject<Data>, data: Data, receivedDataVerifier: (Data) -> Bool)]()
    var sendingData: (id: Int, subject: PublishSubject<Data>, data: Data, receivedDataVerifier: (Data) -> Bool)?
    
    public init(serverIp: String, serverPort: Int) {
        self.serverIp = serverIp
        self.serverPort = serverPort
    }
    
    public func connect(timeout: Int = SendingTcpSocketCommunication.TIMEOUT_MILLIS, printLog: Bool = false) -> Observable<SendingTcpSocketCommunication> {
        var disposable: Disposable? = nil
        var cacheData = Data()
        return RxTcp(url: serverIp, port: serverPort)
            .connect(output: outputSubject)
            .do(onNext: { (rxTcp) in
                disposable = rxTcp.getObservable()
                    .subscribe { (event) in
                        switch event {
                        case .next(let data):
                            cacheData.append(data)
                            if let tuple = self.sendingData,
                               tuple.receivedDataVerifier(cacheData) {
                                tuple.subject.onNext(cacheData)
                                cacheData = Data()
                            }
                        case .completed:
                            self.outputSubject.onCompleted()
                        case .error(let error):
                            self.outputSubject.onError(error)
                        }
                    }
            }, onDispose: {
                disposable?.dispose()
            })
            .map { (rxTcp) -> SendingTcpSocketCommunication in
                self
            }
    }
    
    public func sendData(data: Data, receivedDataVerifier: @escaping (Data) -> Bool) -> Single<Data> {
        let subject = PublishSubject<Data>()
        var id: Int!
        return subject
            .first()
            .map { (data) -> Data in
                if let data = data {
                    return data
                } else {
                    throw RxError.noElements
                }
            }
            .do(onSubscribe: {
                id = Int.random(in: Int.min...Int.max)
                self.sendDataArray.append((id: id, subject: subject, data: data, receivedDataVerifier: receivedDataVerifier))
                self.sendDataInner()
            }, onDispose: {
                if self.sendingData?.id == id {
                    self.sendingData = nil
                    self.sendDataInner()
                }
            })
    }
    
    public func finalizeConnection() {
        outputSubject.onCompleted()
    }
    
    private func sendDataInner() {
        if sendingData == nil,
           let first = sendDataArray.first {
            sendingData = first
            sendDataArray.removeFirst()
            outputSubject.onNext(first.data)
        }
    }
}
