//
//  ViewModel.swift
//  FlushCapacitor
//
//  Created by Pavel Zdenek on 30/01/2017.
//  Copyright © 2017 Salsita s.r.o. All rights reserved.
//

import Foundation
import AppKit
import RxSwift

// HSB easier to tweak for "look" than RGB if hue is basically fixed
private func colorWith(hue degrees: CGFloat) -> NSColor
{
  return NSColor(hue: degrees/360.0, saturation: 0.7, brightness: 0.9, alpha: 1.0)
}

final class ViewModel {

  private let rxDisposeBag = DisposeBag()
  
  private let wholeRect: NSRect
  private let renderRects: [StateModel.DoorLocation: NSRect]

  private var logoImage: NSImage
  private var completeImage: Variable<NSImage>

  public var onTitleChange: ((StateModel.DoorLocation, String) -> Void)?

  init(model: StateModel, rect: NSRect)
  {
    wholeRect = rect
    logoImage = ViewModel.drawLogo(connected: model.connected, into: rect)
    completeImage = Variable<NSImage>(logoImage)
    renderRects = ViewModel.dissect(rect: rect)
    for location in StateModel.allLocations {
      onTitleChange?(location, ViewModel.doorName(for: location))
    }
    model.subscribeNextConnected { connected in
      self.logoImage = ViewModel.drawLogo(connected: connected, into: rect)
      self.completeImage.value = self.drawComplete(from: model.transitions)
    }
    model.subscribeNextTransition { transitions in
      self.completeImage.value = self.drawComplete(from: transitions)
      self.emitDoorTitles(from: transitions)
    }
  }

  func subscribeNextImage(onNext: @escaping (NSImage) -> Void)
  {
    completeImage.asObservable().subscribe(onNext: onNext).addDisposableTo(rxDisposeBag)
  }

  private func emitDoorTitles(from transitions: StateModel.Transitions)
  {
    let now = Date()
    for (location, transition) in transitions {
      let minutes = UInt(now.timeIntervalSince(transition.since) / 60)
      let title: String
      if location == .southShower {
        title = String(format: "%@ %@",
        ViewModel.doorName(for: location), ViewModel.lockLabel(for: transition.state))
      } else {
        title = String(format:"%@ %@ %lu min",
        ViewModel.doorName(for: location), ViewModel.lockLabel(for: transition.state), minutes)
      }
      onTitleChange?(location, title)
    }
  }

  private func drawComplete(from transitions: StateModel.Transitions) -> NSImage
  {
    let img = NSImage(size: wholeRect.size)
    img.lockFocus()
    StateModel.allLocations.forEach { location in
      guard let rect = renderRects[location] else {
        return
      }
      let transition = transitions[location] ?? StateModel.DoorTransition(state: .unknown)
      let color = ViewModel.lockColor(for: transition.state)
      color.set()
      NSRectFill(rect)
    }
    logoImage.draw(in: wholeRect)
    img.unlockFocus()
    return img
  }

  // MARK: - Static utility

  public static func doorName(for location: StateModel.DoorLocation) -> String {
    switch location {
    case .northLeft: return "north left"
    case .northRight: return "north right"
    case .southLeft: return "south left"
    case .southRight: return "south right"
    case .southShower: return "shower"
    }
  }

  private static func lockColor(for state: StateModel.DoorState) -> NSColor {
    switch state {
    case .unknown: return NSColor(white: 0.7, alpha: 1.0)
    case .unlocked: return colorWith(hue: 120)
    case .locked: return colorWith(hue: 0)
    }
  }

  private static func lockLabel(for state: StateModel.DoorState) -> String {
    switch state {
    case .unknown: return "unknown"
    case .unlocked: return "unlocked"
    case .locked: return "locked"
    }
  }

  private static func drawLogo(connected: Bool, into rect: NSRect) -> NSImage
  {
    let img = NSImage(size: rect.size)
    img.lockFocus()
    let kRectInset = NSInsetRect(rect, rect.width/15, rect.height/15)
    let dotRadius = rect.width/10
    let ptL = CGPoint(x: kRectInset.origin.x+dotRadius,y: kRectInset.origin.y+dotRadius)
    let ptR = CGPoint(x: kRectInset.maxX-dotRadius, y: kRectInset.origin.y+dotRadius)
    let ptU = CGPoint(x: kRectInset.origin.x+kRectInset.size.width/2, y: kRectInset.maxY-dotRadius)
    let ptM = CGPoint(x: kRectInset.origin.x+kRectInset.size.width/2, y: kRectInset.origin.y+kRectInset.size.height/2)
    (connected ? NSColor.black : NSColor.white).set()
    NSBezierPath.setDefaultLineCapStyle(NSLineCapStyle.roundLineCapStyle)
    // dots
    NSBezierPath.setDefaultLineWidth(dotRadius*2)
    NSBezierPath.strokeLine(from: ptL, to: ptL)
    NSBezierPath.strokeLine(from: ptR, to: ptR)
    NSBezierPath.strokeLine(from: ptU, to: ptU)
    // lines
    NSBezierPath.setDefaultLineWidth(1.0)
    NSBezierPath.strokeLine(from: ptM, to: ptL)
    NSBezierPath.strokeLine(from: ptM, to: ptR)
    NSBezierPath.strokeLine(from: ptM, to: ptU)
    img.unlockFocus()
    return img
  }

  private static func dissect(rect: NSRect) -> [StateModel.DoorLocation: NSRect]
  {
    var northLeft = NSRect(), northRight = NSRect()
    var southLeft = NSRect(), southRight = NSRect(), southShower = NSRect()
    var northAll = NSRect(), southAll = NSRect(), southToilets = NSRect()
    NSDivideRect(rect, &northAll, &southAll, rect.height/2, .maxY)
    NSDivideRect(northAll, &northLeft, &northRight, rect.width/2, .minX)
    NSDivideRect(southAll, &southShower, &southToilets, 2, .minX)
    NSDivideRect(southToilets, &southLeft, &southRight, rect.width/2, .minX)

    return [
      .northLeft: northLeft,
      .northRight: northRight,
      .southLeft: southLeft,
      .southRight: southRight,
      .southShower: southShower
    ]
  }

}
