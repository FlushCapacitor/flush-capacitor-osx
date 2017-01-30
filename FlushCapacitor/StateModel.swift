//
//  StateModel.swift
//  FlushCapacitor
//
//  Created by Pavel Zdenek on 28/01/2017.
//  Copyright © 2017 Salsita s.r.o. All rights reserved.
//

import Foundation
import RxSwift

private let WSDefaultsKey = "WebSocketURL"

final class StateModel
{
  public enum DoorLocation
  {
    case northLeft
    case northRight
    case southLeft
    case southRight
    case southShower
  }

  public enum DoorState
  {
    case unknown
    case unlocked
    case locked
  }

  public struct DoorTransition {
    let state: DoorState
    let since = Date()
  }

  public typealias Transitions = [DoorLocation: DoorTransition]

  private let rxDisposeBag = DisposeBag()

  private let rxTransitions = Variable<Transitions>([:])
  private let rxConnected = Variable<Bool>(false)
  public let websocket: Variable<URL>

  public static let allLocations: [DoorLocation] = [
    .northLeft, .northRight,
    .southLeft, .southRight, .southShower
  ]

  public var transitions: Transitions {
    get {
      return rxTransitions.value
    }
    set {
      rxTransitions.value = newValue
    }
  }

  public var connected: Bool {
    get {
      return rxConnected.value
    }
    set {
      rxConnected.value = newValue
    }
  }

  init(defaultWs: URL)
  {
    UserDefaults.standard.register(defaults: [WSDefaultsKey : defaultWs])
    websocket = Variable<URL>(UserDefaults.standard.url(forKey: WSDefaultsKey)!)
    websocket.asObservable().subscribe(onNext: { url in
      UserDefaults.standard.set(url, forKey: WSDefaultsKey)
      UserDefaults.standard.synchronize()
    }).addDisposableTo(rxDisposeBag)
  }

  public func subscribeNextTransition(onNext: @escaping (Transitions) -> Void)
  {
    rxTransitions.asObservable().subscribe(onNext: onNext).addDisposableTo(rxDisposeBag)
  }

  public func subscribeNextConnected(onNext: @escaping (Bool) -> Void)
  {
    rxConnected.asObservable().subscribe(onNext: onNext).addDisposableTo(rxDisposeBag)
  }

  public func setAllTransitions(to state: DoorState)
  {
    rxTransitions.value = StateModel.allLocations.reduce(Transitions(), { (partial, location) in
      var retval = partial
      retval[location] = DoorTransition(state: state)
      return retval
    })
  }


}
