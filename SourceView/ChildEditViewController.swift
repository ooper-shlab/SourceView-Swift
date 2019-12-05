//
//  ChildEditViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/24.
//
//
/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller object for the edit bookmark sheet.
 */
import Cocoa

// keys to use to obtain the name and url values from the returned NSDictionary
let kName_Key = "name"
let kURL_Key = "url"

@objc(ChildEditViewController)
class ChildEditViewController: NSViewController {
    
    var savedValues: [String: Any] = [:]
    
    @IBOutlet private weak var doneButton: NSButton!
    @IBOutlet private weak var nameField: NSTextField!
    @IBOutlet private weak var urlField: NSTextField!
    
    
    //MARK: -
    
    // -------------------------------------------------------------------------------
    //	viewWillAppear
    // -------------------------------------------------------------------------------
    override func viewWillAppear() {
        super.viewWillAppear()
        
        self.nameField.stringValue = self.savedValues[kName_Key] as! String? ?? ""
        self.urlField.stringValue = String(describing: self.savedValues[kURL_Key] ?? "")
        self.doneButton.isEnabled = self.doneAllowed
    }
    
    // -------------------------------------------------------------------------------
    //	doneAllowed
    // -------------------------------------------------------------------------------
    private var doneAllowed: Bool {
        return (!self.nameField.stringValue.isEmpty && !self.urlField.stringValue.isEmpty)
    }
    
    // -------------------------------------------------------------------------------
    //	done:sender
    // -------------------------------------------------------------------------------
    @IBAction func done(_: AnyObject) {
        let urlStr: String
        if !self.urlField.stringValue.hasPrefix(HTTP_PREFIX) {
            urlStr = "\(HTTP_PREFIX)\(self.urlField.stringValue)"
        } else {
            urlStr = self.urlField.stringValue
        }
        savedValues = [
            kName_Key : self.nameField.stringValue as AnyObject,
            kURL_Key : URL(string: urlStr)! as AnyObject
        ]
        self.clearValues()
        
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSApplication.ModalResponse.OK)
    }
    
    // -------------------------------------------------------------------------------
    //	clearValues
    // -------------------------------------------------------------------------------
    private func clearValues() {
        self.nameField.stringValue = ""
        self.urlField.stringValue = ""
    }
    
    // -------------------------------------------------------------------------------
    //	cancel:sender
    // -------------------------------------------------------------------------------
    @IBAction func cancel(_: AnyObject) {
        self.clearValues()
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSApplication.ModalResponse.cancel)
    }
    
    // -------------------------------------------------------------------------------
    //	controlTextDidChange:obj
    //
    //  For this to be called, we need to be a delegate to both NSTextFields
    // -------------------------------------------------------------------------------
    func controlTextDidChange(_ obj: Notification) {
        self.doneButton.isEnabled = self.doneAllowed
    }
    
}
