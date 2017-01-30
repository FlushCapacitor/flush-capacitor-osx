//
//  ViewController.swift
//  FlushCapacitor
//
//  Created by Pavel Zdenek on 27/01/2017.
//  Copyright © 2017 Salsita s.r.o. All rights reserved.
//

import Foundation
import AppKit

// There is really no statusbar metric API ???
private let kStatusBarItemWidth = CGFloat(15.0)
private let kStatusBarItemHeight = CGFloat(15.0)

final class ViewController: NSObject
{
  private let viewModel: ViewModel
  private let wsURLEditor: MenuValueEditor
  private typealias DoorStatusItems = [StateModel.DoorLocation: NSMenuItem]
  private let doorStatusItems: DoorStatusItems

  public var onTerminationRequested: (() -> Void)?

  init(stateModel: StateModel)
  {
    viewModel = ViewModel(model: stateModel, rect: NSRect(x:0, y:0, width:kStatusBarItemWidth, height:kStatusBarItemHeight))

    let menu = NSMenu()
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    statusItem.menu = menu

    var items = DoorStatusItems()
    for location in StateModel.allLocations {
      let item = NSMenuItem(title: ViewModel.doorName(for: location), action: nil, keyEquivalent: "")
      items[location] = item
      menu.addItem(item)
    }
    doorStatusItems = items

    let urlEditorItem = NSMenuItem()
    menu.addItem(urlEditorItem)
    wsURLEditor = MenuValueEditor(menuItem: urlEditorItem, value: stateModel.websocket)
    super.init()

    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    menu.addItem(withTitle: "Version: \(appVersion)", action: nil, keyEquivalent: "")

    let quitItem = NSMenuItem(title: "Quit", action: #selector(terminationRequested(_:)), keyEquivalent: "")
    quitItem.target = self
    menu.addItem(quitItem)

    viewModel.subscribeNextImage { statusItem.image = $0 }
    viewModel.onTitleChange = { [weak self] (location, title) in
      if let item = self?.doorStatusItems[location] {
        item.title = title
      }
    }
  }

  @objc public func terminationRequested(_ sender: AnyObject?)
  {
    onTerminationRequested?()
  }
}
