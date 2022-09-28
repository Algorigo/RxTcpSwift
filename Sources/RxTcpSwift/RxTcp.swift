//
//  RxTcp.swift
//  RxTcpSwift
//
//  Created by Jaehong Yoo on 2020/12/29.
//

import Foundation
import RxSwift

public class RxTcp: NSObject {
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    public enum RxTcpError: Error {
        case alreadyConnected
        case notConnected
        case connectError
        case inputStreamOpenError(rawValue: UInt)
        case outputStreamOpenError(rawValue: UInt)
        case outputStreamError(error: Error)
        case disconnected
    }
    
    let url: String
    let port: Int
    
    private var connectionState = ConnectionState.disconnected
    private var inputSubject: PublishSubject<Data>?
    private var inputOpenSubject: PublishSubject<Any>?
    private var outputOpenSubject: PublishSubject<Any>?
    
    public init(url: String, port: Int) {
        self.url = url
        self.port = port
        super.init()
    }
    
    public func connect(output: Observable<Data>) -> Observable<RxTcp> {
        if connectionState != .disconnected {
            return Observable.error(RxTcpError.alreadyConnected)
        }
        
        connectionState = .connecting
        inputSubject = PublishSubject<Data>()
        let connectionSubject = ReplaySubject<RxTcp>.create(bufferSize: 1)
        inputOpenSubject = PublishSubject<Any>()
        outputOpenSubject = PublishSubject<Any>()
        var inputStream: InputStream?
        var outputStream: OutputStream?
        var disposable: Disposable?
        return inputOpenSubject!.ignoreElements().asCompletable()
            .andThen(outputOpenSubject!.ignoreElements().asCompletable())
            .do(onCompleted: {
                self.connectionState = .connected
                connectionSubject.onNext(self)
            })
            .andThen(connectionSubject)
            .do(onSubscribe: {
               if connectionSubject.hasObservers == false {
                    Stream.getStreamsToHost(withName: self.url, port: self.port, inputStream: &inputStream, outputStream: &outputStream)
                    if let inputStream = inputStream,
                       let outputStream = outputStream {
                        // Set delegate
                        inputStream.delegate = self
                        outputStream.delegate = self
                        
                        // Schedule
                        inputStream.schedule(in: .main, forMode: .default)
                        outputStream.schedule(in: .main, forMode: .default)

                        // Open!
                        inputStream.open()
                        outputStream.open()
                        
                        disposable = output
                            .observe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                            .subscribe { [weak self] (event) in
                                switch event {
                                case .next(let data):
                                    data.withUnsafeBytes { (pointer) -> Void in
                                        outputStream.write(pointer.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
                                    }
                                case .completed:
                                    connectionSubject.onCompleted()
                                case .error(let error):
                                    self?.inputSubject?.onError(RxTcpError.outputStreamError(error: error))
                                }
                            }
                    } else {
                        connectionSubject.onError(RxTcpError.connectError)
                    }
                }
            }, onDispose: {
                if !connectionSubject.hasObservers {
                    debugPrint("disconnect")
                    self.connectionState = .disconnected
                    self.inputSubject = nil
                    if connectionSubject.hasObservers {
                        connectionSubject.onCompleted()
                    }
                    inputStream?.close()
                    outputStream?.close()
                    disposable?.dispose()
                }
            })
                .observe(on: MainScheduler.instance)
    }
    
    public func getObservable() -> Observable<Data> {
        return inputSubject
            ?? Observable.error(RxTcpError.notConnected)
    }
}

extension RxTcp: StreamDelegate {
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if let inputStream = aStream as? InputStream {
            switch eventCode {
            case .openCompleted:
                inputOpenSubject?.onCompleted()
            case .endEncountered:
                inputSubject?.onError(RxTcpError.disconnected)
            case .errorOccurred:
                inputOpenSubject?.onError(RxTcpError.inputStreamOpenError(rawValue: eventCode.rawValue))
            case .hasBytesAvailable:
                var data = Data()
                let bufferSize = 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                while inputStream.hasBytesAvailable {
                    let read = inputStream.read(buffer, maxLength: bufferSize)
                    data.append(buffer, count: read)
                }
                buffer.deallocate()
                if data.count > 0 {
                    inputSubject?.onNext(data)
                }
            default:
                break
            }
        } else if aStream is OutputStream {
            switch eventCode {
            case .openCompleted:
                outputOpenSubject?.onCompleted()
            case .endEncountered:
                inputSubject?.onError(RxTcpError.disconnected)
            case .errorOccurred:
                outputOpenSubject?.onError(RxTcpError.inputStreamOpenError(rawValue: eventCode.rawValue))
            default:
                break
            }
        }
    }
}
