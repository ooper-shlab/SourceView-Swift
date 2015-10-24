//
//  ChildEditViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/24.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller object for the edit bookmark sheet
 */
import Cocoa

// keys to use to obtain the name and url values from the returned NSDictionary
let kName_Key = "name"
let kURL_Key = "url"

@objc(ChildEditViewController)
class ChildEditViewController: NSViewController {
    
    var savedValues: [String: String] = [:]
    
    @IBOutlet private weak var doneButton: NSButton!
    @IBOutlet private weak var nameField: NSTextField!
    @IBOutlet private weak var urlField: NSTextField!
    
    
    //MARK: -
    
    // -------------------------------------------------------------------------------
    //	viewWillAppear
    // -------------------------------------------------------------------------------
    override func viewWillAppear() {
        super.viewWillAppear()
        
        self.nameField.stringValue = self.savedValues[kName_Key] ?? ""
        self.urlField.stringValue = self.savedValues[kURL_Key] ?? ""
        self.doneButton.enabled = self.doneAllowed
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
        if !self.urlField.stringValue.hasPrefix("http://") {
            urlStr = "http://\(self.urlField.stringValue)"
        } else {
            urlStr = self.urlField.stringValue
        }
        savedValues = [
            kName_Key : self.nameField.stringValue,
            kURL_Key : urlStr
        ]
        self.clearValues()
        
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSModalResponseOK)
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
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSModalResponseCancel)
    }
    
    // -------------------------------------------------------------------------------
    //	controlTextDidChange:obj
    //
    //  For this to be called, we need to be a delegate to both NSTextFields
    // -------------------------------------------------------------------------------
    override func controlTextDidChange(obj: NSNotification) {
        self.doneButton.enabled = self.doneAllowed
    }
    
}