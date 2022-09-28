//
//  ContentView.swift
//  App
//
//  Created by Jaehong Yoo on 2020/12/29.
//

import SwiftUI
import RxTcpSwift
import RxSwift

struct ContentView: View {
    
    fileprivate let TCP_URL_STAGE = "tcpstg.algorigo.com"
    fileprivate let TCP_PORT = 7782
    
    @State var url: String = "192.168.35.104"
    @State var port: Int = 8080
    @State var buttonTitle1: String = "Connect TCP"
    @State var receivedText: String = ""
    @State var sendingText: String = "Sending Message"
    @State var buttonTitle2: String = "Connect Receiving TCP"
    @State var buttonTitle3: String = "Connect Sending TCP"
    
    @State var disposable1: Disposable? = nil
    @State var disposable2: Disposable? = nil
    @State var disposable3: Disposable? = nil
    var inputSubject = PublishSubject<Data>()
    
    var portProxy: Binding<String> {
        Binding<String>(
            get: { String(self.port) },
            set: {
                if let value = Int($0) {
                    self.port = value
                }
            }
        )
    }
    
    var body: some View {
        VStack {
            Text(RxTcpSwift.version)
                .padding()
            HStack {
                Text("URL : ")
                TextField("url", text: $url)
            }
            HStack {
                Text("Port : ")
                TextField("port", text: portProxy)
            }
            Button(buttonTitle1) {
                if disposable1 != nil {
                    disposable1?.dispose()
                } else {
                    disposable1 = RxTcp(url: url, port: port)
                        .connect(output: self.inputSubject)
                        .flatMap({ (rxTcp) -> Observable<Data> in
                            rxTcp.getObservable()
                        })
                        .observe(on: MainScheduler.instance)
                        .do(onSubscribe: {
                            self.buttonTitle1 = "Disconnect TCP"
                        },onDispose: {
                            self.disposable1 = nil
                            self.buttonTitle1 = "Connect TCP"
                        })
                        .subscribe { (event) in
                            switch event {
                            case .next(let data):
                                receivedText = String(data: data, encoding: .utf8) ?? "empty"
                            case .completed:
                                print(".completed")
                            case .error(let error):
                                print(".error:\(error)")
                            }
                        }
                }
            }.padding(10)
            HStack {
                Text("Received Message : ")
                Text(receivedText)
                    .padding()
            }
            HStack {
                Text("Sending Message : ")
                TextField("message", text: $sendingText)
            }
            Button("Send Message") {
                inputSubject.onNext(sendingText.data(using: .utf8)!)
            }.padding(10)
            Button(buttonTitle2) {
                if disposable2 != nil {
                    disposable2?.dispose()
                } else {
                    disposable2 = TestCommunication()
                        .connect()
                        .observe(on: MainScheduler.instance)
                        .do(onSubscribe: {
                            self.buttonTitle2 = "Disconnect Receiving TCP"
                        },onDispose: {
                            self.disposable2 = nil
                            self.buttonTitle2 = "Connect Receiving TCP"
                        })
                        .subscribe { (event) in
                            switch event {
                            case .completed:
                                print(".completed")
                            case .error(let error):
                                print(".error:\(error)")
                            }
                        }
                }
            }.padding(10)
            Button(buttonTitle3) {
                if disposable3 != nil {
                    disposable3?.dispose()
                } else {
                    disposable3 = TestCommunication2()
                        .connectCompletable()
                        .do(onSubscribe: {
                            self.buttonTitle3 = "Disconnect Sending TCP"
                        },onDispose: {
                            self.disposable3 = nil
                            self.buttonTitle3 = "Connect Sending TCP"
                        })
                        .subscribe { (event) in
                            switch event {
                            case .completed:
                                print(".completed")
                            case .error(let error):
                                print(".error:\(error)")
                            }
                        }
                }
            }
        }.padding(10)
        .onAppear(perform: {
            
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
