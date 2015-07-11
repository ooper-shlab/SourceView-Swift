//
//  ChildEditController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/6.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Controller object for the edit sheet panel.
 */

import Cocoa

@objc(ChildEditController)
class ChildEditController: NSWindowController {
    
    private var cancelled: Bool = false
    private var savedFields: [String: String] = [:]
    
    @IBOutlet private var doneButton: NSButton!
    @IBOutlet private var nameField: NSTextField!
    @IBOutlet private var urlField: NSTextField!
    
    //MARK: -
    
    // -------------------------------------------------------------------------------
    //	windowNibName
    // -------------------------------------------------------------------------------
    override var windowNibName: String {
        return "ChildEdit"
    }
    
    // -------------------------------------------------------------------------------
    //	edit:startingValues:from
    // -------------------------------------------------------------------------------
    func edit(startingValues: [String: String]?, from sender: MyWindowController) -> [String: String] {
        let window = self.window!
        cancelled = false
        
        if startingValues != nil {
            // we are editing current entry, use its values as the default
            savedFields = startingValues!
            
            nameField.stringValue = startingValues!["name"]!
            urlField.stringValue = startingValues!["url"]!
        } else {
            // we are adding a new entry,
            // make sure the form fields are empty due to the fact that this controller is recycled
            // each time the user opens the sheet -
            //
            nameField.stringValue = ""
            urlField.stringValue = ""
        }
        
        nameField.becomeFirstResponder()
        
        NSApp.beginSheet(window, modalForWindow: sender.window!, modalDelegate: nil, didEndSelector: nil, contextInfo: nil)
        
        // done button enabled only if both edit fields have text
        doneButton.enabled = (!nameField.stringValue.isEmpty && !urlField.stringValue.isEmpty)
        
        NSApp.runModalForWindow(window)
        // sheet is up here...
        
        NSApp.endSheet(window)
        window.orderOut(self)
        
        return savedFields
    }
    
    // -------------------------------------------------------------------------------
    //	done:sender
    // -------------------------------------------------------------------------------
    @IBAction func done(_: AnyObject) {
        let urlStr: String
        if !urlField.stringValue.hasPrefix("http://") {
            urlStr = "http://\(urlField.stringValue)"
        } else {
            urlStr = urlField.stringValue
        }
        savedFields = [
            "name": nameField.stringValue,
            "url": urlStr,
        ]
        
        NSApp.stopModal()
    }
    
    // -------------------------------------------------------------------------------
    //	cancel:sender
    // -------------------------------------------------------------------------------
    @IBAction func cancel(_: AnyObject) {
        NSApp.stopModal()
        cancelled = true
    }
    
    // -------------------------------------------------------------------------------
    //	wasCancelled:
    // -------------------------------------------------------------------------------
    var wasCancelled: Bool {
        return cancelled
    }
    
    // -------------------------------------------------------------------------------
    //	controlTextDidChange:obj
    //
    //  for this to be called, we need to be a delegate to both NSTextFields
    // -------------------------------------------------------------------------------
    override func controlTextDidChange(obj: NSNotification) {
        doneButton.enabled = (!nameField.stringValue.isEmpty && !urlField.stringValue.isEmpty)
    }
    
}