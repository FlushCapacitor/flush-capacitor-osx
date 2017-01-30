//
//  StateChannel.swift
//  FlushCapacitor
//
//  Created by Pavel Zdenek on 28/01/2017.
//  Copyright © 2017 Salsita s.r.o. All rights reserved.
//

import Foundation
import Starscream
import Reachability
import RxSwift

fileprivate let wireDoorLocations: [String: StateModel.DoorLocation] = [
  "old office - left toilet": .northLeft,
  "old office - right toilet": .northRight,
  "new office - left toilet": .southLeft,
  "new office - right toilet": .southRight,
  "new office - shower": .southShower
]

fileprivate let wireLockStates: [String: StateModel.DoorState] = [
  "locked": .locked,
  "unlocked": .unlocked
]

// NSObject unfortunate requirement of NSNotificationCenter observer
final class StateChannel: NSObject, WebSocketDelegate
{
  private let model: StateModel
  private let reachabilityHost: Reachability
  private let reachabilityGeneral: Reachability
  private let rxDisposeBag = DisposeBag()

  private var webSocket: WebSocket?

  init(stateModel: StateModel)
  {
    model = stateModel
    reachabilityHost = Reachability(hostName: model.websocket.value.host)
    reachabilityGeneral = Reachability.forInternetConnection()
    super.init()
    model.websocket.asObservable().subscribe(onNext: { [weak self] url in
      self?.reconnect(url: url)
    }).addDisposableTo(rxDisposeBag)
  }
  
  func start(url: URL)
  {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(StateChannel.reachabilityChanged(_:)),
      name: NSNotification.Name.reachabilityChanged,
      object: nil)
    reachabilityGeneral.startNotifier()
    reachabilityHost.startNotifier()
    if reachabilityHost.isReachable() {
      connect(url: url)
    }
  }

  func stop()
  {
    NotificationCenter.default.removeObserver(
      self,
      name: NSNotification.Name.reachabilityChanged,
      object: nil)
    reachabilityGeneral.stopNotifier()
    reachabilityHost.stopNotifier()
    disconnect()
  }

  fileprivate var isWebsocketConnected: Bool {
    get { return webSocket?.isConnected ?? false }
  }

  fileprivate func reconnect(url: URL)
  {
    NSLog("WS reconnect %@", url.absoluteString)
    if isWebsocketConnected {
      disconnect()
    }
    connect(url: url)
  }

  fileprivate func connect(url: URL) {
    NSLog("WS connect %@ %@", url.absoluteString, isWebsocketConnected ? "already connected" : "will connect" )
    if !isWebsocketConnected  {
      webSocket = WebSocket(url: url)
      webSocket?.delegate = self
      webSocket?.connect()
    }
  }

  fileprivate func disconnect() {
    NSLog("WS disconnect %@", isWebsocketConnected ? "will disconnect": "already disconnected")
    if isWebsocketConnected {
      webSocket?.disconnect()
    }
  }

  public func reachabilityChanged(_ notification:Notification) {
    guard let r = notification.object as? Reachability else {
      return
    }
    var reachabilityType = "unknown"
    var reachabilityOther = "unknown"
    if(r == reachabilityHost) {
      reachabilityType = "host"
      reachabilityOther = reachabilityGeneral.currentReachabilityString()
    } else if(r == reachabilityGeneral) {
      reachabilityType = "general"
      reachabilityOther = reachabilityHost.currentReachabilityString()
    }
    NSLog("Reachability '%@' changed '%@' flags '%@' other '%@'",
          reachabilityType, r.currentReachabilityString(), r.currentReachabilityFlags(),
          reachabilityOther)
    if(r.currentReachabilityStatus() == NetworkStatus.NotReachable) {
      disconnect()
    } else {
      connect(url: model.websocket.value)
    }
  }

  // MARK: WebSocketDelegate

  func websocketDidConnect(socket: WebSocket)
  {
    NSLog("webSocket: didConnect")
    model.connected = true
    model.setAllTransitions(to: .unknown)
  }

  func websocketDidDisconnect(socket: WebSocket, error: NSError?)
  {
    NSLog("webSocket: didDisconnect")
    model.connected = false
    model.setAllTransitions(to: .unknown)
  }

  func websocketDidReceiveMessage(socket: WebSocket, text: String)
  {
    guard let data = text.data(using: .utf8) else {
      NSLog("webSocket: does not recognize incoming string message")
      return
    }
    websocketDidReceiveData(socket: socket, data: data)
  }

  func websocketDidReceiveData(socket: WebSocket, data: Data)
  {
    do {
      let jsonAny = try JSONSerialization.jsonObject(with: data, options: [])
      if let dict = jsonAny as? [String: String] {
        NSLog("webSocket: receiveData %@", dict)
        if let wireDoor = dict["name"], let wireState = dict["state"],
           let doorLocation = wireDoorLocations[wireDoor], let lockState = wireLockStates[wireState] {
          model.transitions[doorLocation] = StateModel.DoorTransition(state: lockState)
          return
        }
      } else {
        NSLog("webSocket: receiveData cannot parse json to dictionary")
      }
    } catch let e {
      NSLog("webSocket: receiveData failed %@", String(describing: e))
    }
    model.setAllTransitions(to: .unknown)
  }
}
