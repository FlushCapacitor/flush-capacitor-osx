//
//  AppDelegate.swift
//  FlushCapacitor
//
//  Created by Pavel Zdeněk on 30/12/14.
//  Copyright (c) 2014 Salsita s.r.o. All rights reserved.
//

import Cocoa
import AppKit
import SocketRocket
import Reachability

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SRWebSocketDelegate  {

  // There is really no statusbar metric API ???
  let kStatusBarItemWidth = CGFloat(15.0)
  let kStatusBarItemHeight = CGFloat(15.0)
  let wholeRect: CGRect
  let renderRects: [String: CGRect]
  let nameNorthLeft = "L"
  let nameNorthRight = "R"
  let nameSouthLeft = "new office - left toilet"
  let nameSouthRight = "new office - right toilet"
  let nameSouthShower = "new office - shower"

  let kWebSocketURL = "ws://192.168.23.18/changes"
  let kHTTPQueryURL = "http://192.168.23.18/api/sensors" // @todo

  let dateFormatter = NSDateFormatter()
  // Colors
  let kColorUnknown = NSColor(white: 0.7, alpha: 1.0)
  // HSB easier to tweak for "look" than RGB if hue is basically fixed
  let kColorOccupied = NSColor(hue: 0/360.0, saturation: 0.7, brightness: 0.9, alpha: 1.0)
  let kColorAvailable = NSColor(hue: 120/360.0, saturation: 0.7, brightness: 0.9, alpha: 1.0)
  // View
  // Lazy creation if applicationDidFinishLaunching
  private var _statusItem: NSStatusItem?
  private var _reconnectItem: NSMenuItem?
  // Model
  private var _statuses = [String: (locked: Bool, since: NSDate)]()
  // Net
  private var _reachabilityHost: Reachability
  private var _reachabilityGeneral: Reachability
  // "SRWebSockets are intended one-time-use only" -> create lazily repeatedly
  private var _webSocket: SRWebSocket?
  
  override init() {
    wholeRect = NSMakeRect(0, 0, kStatusBarItemWidth, kStatusBarItemHeight)
    var northLeft = NSRect()
    var northRight = NSRect()
    var southLeft = NSRect()
    var southRight = NSRect()
    do {
      var allNorth = NSRect()
      var allSouth = NSRect()
      NSDivideRect(wholeRect, &allNorth, &allSouth, kStatusBarItemHeight/2, .MaxY)
      NSDivideRect(allNorth, &northLeft, &northRight, kStatusBarItemWidth/2, .MinX)
      NSDivideRect(allSouth, &southLeft, &southRight, kStatusBarItemWidth/2, .MinX)
    }
    renderRects = [
      nameNorthRight: northRight,
      nameNorthLeft: northLeft,
      nameSouthRight: southRight,
      nameSouthLeft: southLeft
    ]
    dateFormatter.dateFormat = "HH:mm"
    let appName = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleName") as? String ?? "FlushCapacitor"
    let host = NSURL(string: kWebSocketURL)?.host
    _reachabilityHost = Reachability(hostName: host)
    _reachabilityGeneral = Reachability.reachabilityForInternetConnection()
    let paths = NSSearchPathForDirectoriesInDomains(
      NSSearchPathDirectory.LibraryDirectory,
      NSSearchPathDomainMask.UserDomainMask,
      true)
    let logFolderURL = NSURL(fileURLWithPath: paths[0], isDirectory: true)
      .URLByAppendingPathComponent("Logs")
      .URLByAppendingPathComponent(appName)
    var isDirectory = ObjCBool(false)
    let fm = NSFileManager.defaultManager()
    if(!fm.fileExistsAtPath(logFolderURL.absoluteString, isDirectory: &isDirectory) || !isDirectory) {
      do {
        try fm.createDirectoryAtURL(logFolderURL, withIntermediateDirectories: true, attributes: nil)
        freopen(logFolderURL.URLByAppendingPathComponent("events.log").fileSystemRepresentation, "a+", stderr)
      } catch {
        NSLog("No logging, cannot create %@", logFolderURL.absoluteString)
      }
    }
  }
  
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    NSLog("DidFinishLaunching")
    let appVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as? String ?? "unknown"

    let menu = NSMenu()
    menu.addItemWithTitle(String(format:"Version: %@",appVersion), action: nil, keyEquivalent: "")
    menu.addItemWithTitle("Quit", action: #selector(AppDelegate.terminate(_:)), keyEquivalent: "")

    _statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    _statusItem?.menu = menu
    _statusItem?.image = imageWithStatus()
    
    NSNotificationCenter.defaultCenter().addObserver(
      self,
      selector: #selector(AppDelegate.reachabilityChanged(_:)),
      name: kReachabilityChangedNotification,
      object: nil)
    NSLog("Starting notifier")
    _reachabilityGeneral.startNotifier()
    _reachabilityHost.startNotifier()
    if _reachabilityHost.isReachable() {
      wsConnect()
    }
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    NSLog("WillTerminate")
    wsDisconnect()
  }

  func terminate(sender: AnyObject)
  {
    NSApplication.sharedApplication().terminate(self)
  }

  private func wsConnect() {
    NSLog("wsConnect %@", _webSocket == nil ? "nil, opening" : "already connected" )
    if(_webSocket == nil) {
      _webSocket = SRWebSocket(URL: NSURL(string: kWebSocketURL))
      _webSocket?.delegate = self
      _webSocket?.open()
    }
  }
  
  private func wsDisconnect() {
    NSLog("wsDisconnect %@", _webSocket == nil ? "already disconnected" : "connected, closing")
    if(_webSocket != nil) {
      _webSocket?.close()
      _webSocket = nil
    }
    _statuses.removeAll()
  }

  func reachabilityChanged(notification:NSNotification) {
    guard let r = notification.object as? Reachability else {
      return
    }
    var reachabilityType = "unknown"
    var reachabilityOther = "unknown"
    if(r == _reachabilityHost) {
      reachabilityType = "host"
      reachabilityOther = _reachabilityGeneral.currentReachabilityString()
    } else if(r == _reachabilityGeneral) {
      reachabilityType = "general"
      reachabilityOther = _reachabilityHost.currentReachabilityString()
    }
    NSLog("Reachability '%@' changed '%@' flags '%@' other '%@'",
      reachabilityType, r.currentReachabilityString(), r.currentReachabilityFlags(),
reachabilityOther)
    if(r.currentReachabilityStatus() == NetworkStatus.NotReachable) {
      wsDisconnect()
    } else {
      wsConnect()
    }
  }
  
  private func imageWithStatus() -> NSImage
  {
    let img = NSImage(size:wholeRect.size)
    img.lockFocus()
    var statuses = ""
    for (name, rect) in renderRects {
      let (color, stateStr) = { () -> (NSColor, String) in
        guard let (locked, since) = _statuses[name] else {
          return (kColorUnknown, "unknown")
        }
        return (
          locked ? kColorOccupied : kColorAvailable,
          String(format: "%@ since %@", locked ? "occupied": "free", dateFormatter.stringFromDate(since))
        )
      }()
      statuses += String("\(name): \(stateStr)\n")
      color.set()
      NSRectFill(rect)
    }
    _statusItem?.toolTip = statuses
    let kRectInset = NSInsetRect(wholeRect, kStatusBarItemWidth/15, kStatusBarItemHeight/15)
    let dotRadius = kStatusBarItemWidth/10
    let ptL = CGPointMake(kRectInset.origin.x+dotRadius,kRectInset.origin.y+dotRadius)
    let ptR = CGPointMake(CGRectGetMaxX(kRectInset)-dotRadius, kRectInset.origin.y+dotRadius)
    let ptU = CGPointMake(kRectInset.origin.x+kRectInset.size.width/2, CGRectGetMaxY(kRectInset)-dotRadius)
    let ptM = CGPointMake(kRectInset.origin.x+kRectInset.size.width/2, kRectInset.origin.y+kRectInset.size.height/2)
    NSColor.blackColor().set()
    NSBezierPath.setDefaultLineCapStyle(NSLineCapStyle.RoundLineCapStyle)
    // dots
    NSBezierPath.setDefaultLineWidth(dotRadius*2)
    NSBezierPath.strokeLineFromPoint(ptL, toPoint: ptL)
    NSBezierPath.strokeLineFromPoint(ptR, toPoint: ptR)
    NSBezierPath.strokeLineFromPoint(ptU, toPoint: ptU)
    // lines
    NSBezierPath.setDefaultLineWidth(1.0)
    NSBezierPath.strokeLineFromPoint(ptM, toPoint: ptL)
    NSBezierPath.strokeLineFromPoint(ptM, toPoint: ptR)
    NSBezierPath.strokeLineFromPoint(ptM, toPoint: ptU)
    img.unlockFocus()
    return img
  }
  
  // MARK: SRWebSocketDelegate
  
  func webSocketDidOpen(webSocket: SRWebSocket!) {
    NSLog("webSocket: didOpen")
  }
  
  func webSocket(webSocket: SRWebSocket!, didReceiveMessage message: AnyObject!) {
    guard let msg: [String: String] = {
      do {
        return try NSJSONSerialization.JSONObjectWithData(
          message.dataUsingEncoding(NSUTF8StringEncoding)!,
          options: []) as? [String: String]
      } catch let e {
        NSLog("webSocket: receiveMessage failed %@", String(e))
        return nil
      }
    }() else {
      return
    }
    NSLog("webSocket: receiveMessage %@", msg)
    if let name = msg["name"], let state = msg["state"] {
      _statuses[name] = (locked: (state == "locked"), since: NSDate())
      _statusItem?.image = imageWithStatus()
    }
  }

  func webSocket(webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
    NSLog("webSocket: didClose")
    wsDisconnect()
    _statusItem?.image = imageWithStatus()
  }

  func webSocket(webSocket: SRWebSocket!, didFailWithError error: NSError!) {
    NSLog("webSocket: didFailWithError %d %@", error.code, error.localizedDescription)
    wsDisconnect()
    _statusItem?.image = imageWithStatus()
  }
}

