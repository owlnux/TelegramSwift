//
//  AlertController.swift
//  Telegram
//
//  Created by keepcoder on 07/11/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

@available(OSX 10.12.2, *)
private extension NSTouchBarItem.Identifier {
    static let alertButtonOK = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.alertButtonOK")
    static let alertButtonCancel = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.alertButtonCancel")
    static let alertButtonThrid = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.alertButtonThrid")

}

private var global:AlertController? = nil

private class AlertBackgroundModalViewController : ModalViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
}

private let readyDisposable = MetaDisposable()


class AlertController: ViewController, NSTouchBarDelegate {

    fileprivate let alert: Window
    private let _window: NSWindow
    private let header: String
    private let text: String?
    private let okTitle:String
    private let cancelTitle:String?
    private let thridTitle:String?
    private let account: Account?
    private let peerId: PeerId?
    private let accessory: CGImage?
    private let disposable = MetaDisposable()
    init(_ window: NSWindow, account: Account?, peerId: PeerId?, header: String, text:String? = nil, okTitle: String? = nil, cancelTitle: String? = nil, thridTitle: String? = nil, accessory: CGImage? = nil) {
        self.account = account
        self.accessory = accessory
        self.peerId = peerId
        self._window = window
        self.header = header
        self.text = text
        self.okTitle = okTitle ?? tr(L10n.alertOK)
        self.cancelTitle = cancelTitle
        self.thridTitle = thridTitle
        alert = Window(contentRect: NSMakeRect(0, 0, 380, 130), styleMask: [], backing: .buffered, defer: true)
        alert.backgroundColor = .clear
        super.init(frame: NSMakeRect(0, 0, 380, 130))
        
        
        alert.rootViewController = self
    }
    
    private var temporaryTouchBar:Any?
    
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        
        
        if temporaryTouchBar == nil {
            let touchBar = NSTouchBar()
            
            touchBar.delegate = self
            touchBar.customizationIdentifier = .windowBar
            var itemIdentifiers: [NSTouchBarItem.Identifier] = [.flexibleSpace, .alertButtonCancel, .alertButtonOK, .flexibleSpace]
            if let _ = thridTitle {
                itemIdentifiers.insert(.alertButtonThrid, at: 1)
                itemIdentifiers.insert(.fixedSpaceLarge, at: 2)
            }
            touchBar.defaultItemIdentifiers = itemIdentifiers
            
            touchBar.customizationAllowedItemIdentifiers = touchBar.defaultItemIdentifiers
            touchBar.principalItemIdentifier = thridTitle != nil ? nil : .alertButtonOK
            
            temporaryTouchBar = touchBar
        }
       
        return temporaryTouchBar as? NSTouchBar
    }
    
    
    
    @available(OSX 10.12.2, *)
    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard let barIdentifier = touchBar.customizationIdentifier else { return nil }
        
        switch barIdentifier {
        case .windowBar:
            return touchBarItem(for: identifier)
        default:
            return nil
        }
    }
    @available(OSX 10.12.2, *)
    func touchBarItem(for identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .alertButtonOK:
            let item: NSCustomTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: self.okTitle, target: self, action: #selector(touchBarOKAction))
            button.addWidthConstraint(size: 160)
            button.bezelColor = theme.colors.blueUI
            item.view = button
            item.customizationLabel = self.okTitle
            return item
        case .alertButtonCancel:
            let item: NSCustomTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: self.cancelTitle ?? "", target: self, action: #selector(touchBarCancelAction))
            item.view = button;
            button.addWidthConstraint(size: 160)
            item.customizationLabel =  self.cancelTitle ?? ""
            return item
        case .alertButtonThrid:
            let item: NSCustomTouchBarItem = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: self.thridTitle ?? "", target: self, action: #selector(touchBarThridAction))
            button.bezelColor = self.checkBoxSelected ? theme.colors.blueIcon : nil
            item.view = button;
            item.customizationLabel =  self.thridTitle ?? ""
            return item
        default:
            break
        }
        return nil
    }
    @available(OSX 10.12.2, *)
    @objc private func touchBarOKAction() {
        self.close(self.checkBoxSelected ? .alertThirdButtonReturn : .OK)
    }
    @available(OSX 10.12.2, *)
    @objc private func touchBarCancelAction() {
        close()
    }
    @available(OSX 10.12.2, *)
    @objc private func touchBarThridAction() {
        self.genericView.checkbox.send(event: .Click)
    }
    @available(OSX 10.12.2, *)
    override func layoutTouchBar() {
        guard let touchBar = self.alert.touchBar else { return }
        guard let item = touchBar.item(forIdentifier: .alertButtonThrid) as? NSCustomTouchBarItem,
            let button = item.view as? NSButton else {return}
        button.bezelColor = checkBoxSelected ? theme.colors.blueIcon : nil
    }
    
    override func viewClass() -> AnyClass {
        return AlertControllerView.self
    }
    
    func close(_ reason: NSApplication.ModalResponse = .abort) {
        _window.endSheet(alert, returnCode: reason)
        global = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let peerId = peerId, let account = account {
            disposable.set((account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
                self?.layoutAndReady(peer)
            }))
        } else {
            layoutAndReady(nil)
        }
    }
    
    private func layoutAndReady(_ peer: Peer?) {
        let maxWidth = genericView.layoutButtons(okTitle: okTitle, cancelTitle: cancelTitle, okHandler: { [weak self] in
            guard let `self` = self else {return}
            self.close(self.thridTitle != nil && self.checkBoxSelected ? .alertThirdButtonReturn : .OK)
        }, cancelHandler: { [weak self] in
            self?.close(.cancel)
        })
        genericView.layoutTexts(with: peer?.displayTitle ?? self.header, information: text, account: account, peer: peer, thridTitle: thridTitle, accessory: accessory, maxWidth: maxWidth)
        alert.setFrame(NSMakeRect(0, 0, maxWidth, view.frame.height), display: true)
        view.frame = NSMakeRect(0, 0, maxWidth, view.frame.height)
        view.needsLayout = true
        
        genericView.checkbox.set(handler: { [weak self] checkbox in
            if #available(OSX 10.12.2, *) {
               self?.layoutTouchBar()
            }
            
        }, for: .Click)
        readyOnce()
    }
    
    deinit {
        disposable.dispose()
        alert.removeAllHandlers(for: self)
    }
    
    func show(completionHandler: @escaping(NSApplication.ModalResponse)->Void) {
        
        global = self

        loadViewIfNeeded()
        viewDidLoad()
        
        readyDisposable.set(ready.get().start(next: { [weak self] _ in
            self?.showInited(completionHandler: completionHandler)
        }))
    }
    
    private func showInited(completionHandler: @escaping(NSApplication.ModalResponse)->Void) {
        
        let modal = AlertBackgroundModalViewController(frame: NSZeroRect)
        if let _window = _window as? Window {
            showModal(with: modal, for: _window)
        }
        
        alert.setFrame(view.bounds, display: false)
        alert.contentView = self.view
        _window.beginSheet(alert) { [weak modal] response in
            modal?.close()
            global = nil
            completionHandler(response)
        }
        
        alert.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.close()
            return .invoked
        }, with: self, for: .Escape)
        
        alert.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.close()
            return .invoked
        }, with: self, for: .Space)
        
        alert.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.close(self.checkBoxSelected ? .alertThirdButtonReturn : .OK)
            return .invoked
        }, with: self, for: .Return)
    }
    private var checkBoxSelected: Bool {
        return genericView.checkbox.isSelected
    }
    
    private var genericView: AlertControllerView {
        return view as! AlertControllerView
    }
    
}
