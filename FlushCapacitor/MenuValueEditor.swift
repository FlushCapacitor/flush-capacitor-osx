//
//  MenuValueEditor.swift
//  FlushCapacitor
//
//  Created by Pavel Zdenek on 28/01/2017.
//  Copyright © 2017 Salsita s.r.o. All rights reserved.
//

import Cocoa
import RxSwift

final class MenuValueEditor: NSObject, NSTextFieldDelegate
{
  private let value: Variable<URL>
  private let textField: NSTextField
  private let rxDisposeBag = DisposeBag()

  init(menuItem: NSMenuItem, value: Variable<URL>)
  {
    self.value = value
    textField = NSTextField(frame: NSRect(x:0, y:0, width:200, height:25))
    menuItem.view = textField
    super.init()
    textField.isEditable = true
    textField.isEnabled = true
    textField.isSelectable = true
    textField.stringValue = value.value.absoluteString
    textField.delegate = self
    value.asObservable().subscribe(onNext: { [weak self] url in
      self?.textField.stringValue = url.absoluteString
    }).addDisposableTo(rxDisposeBag)
  }

  override func controlTextDidEndEditing(_ obj: Notification) {
    let string = textField.stringValue
    guard
      let url = URL(string: string),
      let _ = url.host,
      url.scheme == "ws" else {
        textField.backgroundColor = NSColor.yellow
        return
    }
    textField.backgroundColor = NSColor.textBackgroundColor
    value.value = url
    textField.resignFirstResponder()
  }
}
