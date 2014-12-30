//
//  AppDelegate.swift
//  FlushCapacitor
//
//  Created by Pavel Zdeněk on 30/12/14.
//  Copyright (c) 2014 Salsita s.r.o. All rights reserved.
//

import Cocoa
import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SRWebSocketDelegate  {
  
  let kWebSocketURL = "ws://itoilet/changes";
  let kHTTPQueryURL = "http://itoilet/api/sensors"; // @todo
  // There is really no statusbar metric API ???
  let kStatusBarItemWidth : CGFloat = 15.0;
  let kStatusBarItemHeight : CGFloat = 15.0;
  // Colors
  let kColorUnknown = NSColor(white: 0.7, alpha: 1.0);
  // HSB easier to tweak for "look" than RGB if hue is basically fixed
  let kColorOccupied = NSColor(hue: 0/360.0, saturation: 0.7, brightness: 0.9, alpha: 1.0);
  let kColorAvailable = NSColor(hue: 120/360.0, saturation: 0.7, brightness: 0.9, alpha: 1.0);
  
  // View
  // Lazy creation if applicationDidFinishLaunching
  private var _statusItem: NSStatusItem?;
  private var _reconnectItem: NSMenuItem?;
  // Model
  private var _statuses: NSMutableDictionary;
  // Net
  private var _reachability: Reachability;
  // "SRWebSockets are intended one-time-use only" -> create lazily repeatedly
  private var _webSocket: SRWebSocket?;
  
  override init() {
    _statuses = NSMutableDictionary();
    let host = NSURL(string: kWebSocketURL)?.host;
    _reachability = Reachability(hostName: host);
  }
  
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    let menu = NSMenu();
    menu.addItemWithTitle("Quit", action: "terminate:", keyEquivalent: "");
    
    // https://devforums.apple.com/message/1001121#1001121
    // NSVariableStatusItemLength is linker undefined symbol ??? :facepalm:
    let omgwtfVariableLength = CGFloat(-1.0);
    _statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(omgwtfVariableLength);
    _statusItem?.menu = menu;
    _statusItem?.image = imageWithStatus();
    
    NSNotificationCenter.defaultCenter().addObserver(
      self,
      selector: "reachabilityChanged:",
      name: kReachabilityChangedNotification,
      object: nil);
    _reachability.startNotifier();
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    wsDisconnect();
  }

  private func wsConnect() {
    if(_webSocket == nil) {
      _webSocket = SRWebSocket(URL: NSURL(string: kWebSocketURL));
      _webSocket?.delegate = self;
      _webSocket?.open();
    }
  }
  
  private func wsDisconnect() {
    if(_webSocket != nil) {
      _webSocket?.close();
      _webSocket = nil;
    }
    _statuses.removeAllObjects();
  }

  func reachabilityChanged(notification:NSNotification) {
    let r = notification.object as Reachability;
    if(r.currentReachabilityStatus() == NetworkStatus.NotReachable) {
      wsDisconnect();
    } else {
      wsConnect();
    }
  }
  
  private func imageWithStatus() -> NSImage {
    
    func drawStateRect(status:AnyObject?, rect:CGRect ) {
      var color = kColorUnknown;
      if let validStatus = status as? NSNumber {
        if validStatus.isEqualToNumber(0) {
          color = kColorAvailable;
        } else if validStatus.isEqualToNumber(1) {
          color = kColorOccupied;
        }
      }
      color.set();
      NSRectFill(rect);
    }

    let wholeRect = NSMakeRect(0, 0, kStatusBarItemWidth, kStatusBarItemHeight);
    let img = NSImage(size:wholeRect.size);
    var left: NSRect = NSRect();
    var right: NSRect = NSRect();
    NSDivideRect(wholeRect, &left, &right, kStatusBarItemWidth/2, NSMinXEdge);
    img.lockFocus();
    drawStateRect(_statuses["L"], left);
    drawStateRect(_statuses["R"], right);
    let kRectInset = NSInsetRect(wholeRect, kStatusBarItemWidth/15, kStatusBarItemHeight/15);
    let dotRadius = kStatusBarItemWidth/10;
    let ptL = CGPointMake(kRectInset.origin.x+dotRadius,kRectInset.origin.y+dotRadius);
    let ptR = CGPointMake(CGRectGetMaxX(kRectInset)-dotRadius, kRectInset.origin.y+dotRadius);
    let ptU = CGPointMake(kRectInset.origin.x+kRectInset.size.width/2, CGRectGetMaxY(kRectInset)-dotRadius);
    let ptM = CGPointMake(kRectInset.origin.x+kRectInset.size.width/2, kRectInset.origin.y+kRectInset.size.height/2);
    NSColor.blackColor().set();
    NSBezierPath.setDefaultLineCapStyle(NSLineCapStyle.RoundLineCapStyle);
    // dots
    NSBezierPath.setDefaultLineWidth(dotRadius*2);
    NSBezierPath.strokeLineFromPoint(ptL, toPoint: ptL);
    NSBezierPath.strokeLineFromPoint(ptR, toPoint: ptR);
    NSBezierPath.strokeLineFromPoint(ptU, toPoint: ptU);
    // lines
    NSBezierPath.setDefaultLineWidth(1.0);
    NSBezierPath.strokeLineFromPoint(ptM, toPoint: ptL);
    NSBezierPath.strokeLineFromPoint(ptM, toPoint: ptR);
    NSBezierPath.strokeLineFromPoint(ptM, toPoint: ptU);
    img.unlockFocus();
    return img;
  }
  
  // MARK: SRWebSocketDelegate
  
  func webSocketDidOpen(webSocket: SRWebSocket!) {
  }
  
  func webSocket(webSocket: SRWebSocket!, didReceiveMessage message: AnyObject!) {
    var err : NSError?;
    if let msg = NSJSONSerialization.JSONObjectWithData(
      message.dataUsingEncoding(NSUTF8StringEncoding)!,
      options: nil,
      error: &err) as? NSDictionary
    {
      let locked = msg["state"]?.isEqualToString("locked");
      let name = msg["name"] as String;
      _statuses[name] = locked;
      _statusItem?.image = imageWithStatus();
    }
  }

  func webSocket(webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
    wsDisconnect();
    _statusItem?.image = imageWithStatus();
  }

  func webSocket(webSocket: SRWebSocket!, didFailWithError error: NSError!) {
    wsDisconnect();
    _statusItem?.image = imageWithStatus();
  }
}

