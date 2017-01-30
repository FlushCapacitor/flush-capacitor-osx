//
//  AppDelegate.swift
//  FlushCapacitor
//
//  Created by Pavel Zdeněk on 30/12/14.
//  Copyright (c) 2014 Salsita s.r.o. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
  private var stateModel = StateModel(defaultWs: URL(string: "ws://itoilet/changes")!)
  private let channel: StateChannel
  private let viewController: ViewController

  override init()
  {
    channel = StateChannel(stateModel: stateModel)
    viewController = ViewController(stateModel: stateModel)
    super.init()
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
    setupLogging(appName: appName ?? "FlushCapacitor")
  }
  
  func applicationDidFinishLaunching(_ aNotification: Notification)
  {
    viewController.onTerminationRequested = { _ in
      NSApplication.shared().terminate(self)
    }
    stateModel.setAllTransitions(to: .unknown)
    channel.start(url: stateModel.websocket.value)
  }

  func applicationWillTerminate(_ aNotification: Notification)
  {
    channel.stop()
  }

  private func setupLogging(appName: String)
  {
    let paths = NSSearchPathForDirectoriesInDomains(
      FileManager.SearchPathDirectory.libraryDirectory,
      FileManager.SearchPathDomainMask.userDomainMask,
      true)
    let logFolderURL = URL(fileURLWithPath: paths[0], isDirectory: true)
      .appendingPathComponent("Logs")
      .appendingPathComponent(appName)
    var isDirectory = ObjCBool(false)
    let fm = FileManager.default
    if(!fm.fileExists(atPath: logFolderURL.absoluteString, isDirectory: &isDirectory) || !isDirectory.boolValue) {
      do {
        try fm.createDirectory(at: logFolderURL, withIntermediateDirectories: true, attributes: nil)
        freopen((logFolderURL.appendingPathComponent("events.log") as NSURL).fileSystemRepresentation, "a+", stderr)
      } catch {
        NSLog("No logging, cannot create %@", logFolderURL.absoluteString)
      }
    }
  }
}

