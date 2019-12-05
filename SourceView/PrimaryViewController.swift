//
//  PrimaryViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/24.
//
//
/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller containing the lower UI controls and the embedded child view controller (split view controller).
 */
import Cocoa

// notification to instruct MyOutlineViewController to add a folder
let kAddFolderNotification = "AddFolderNotification"
// notification to instruct MyOutlineViewController to remove a folder
let kRemoveFolderNotification = "RemoveFolderNotification"
// notification to instruct MyOutlineViewController to add a bookmark
let kAddBookmarkNotification = "AddBookmarkNotification"
// notification to instruct MyOutlineViewController to edit a bookmark
let kEditBookmarkNotification = "EditBookmarkNotification"

@objc(PrimaryViewController)
class PrimaryViewController: NSViewController {
    
    @IBOutlet private weak var progIndicator: NSProgressIndicator!
    @IBOutlet private weak var removeButton: NSButton!
    @IBOutlet private weak var actionButton: NSPopUpButton!
    @IBOutlet private weak var urlField: NSTextField!
    @IBOutlet private var editBookmarkMenuItem: NSMenuItem!
    
    //MARK: -
    
    
    // -------------------------------------------------------------------------------
    //	viewDidLoad
    // -------------------------------------------------------------------------------
    override func viewDidLoad() {
        // Note: we keep the left split view item from growing as the window grows by setting its hugging priority to 200,
        // and the right to 199. The view with the lowest priority will be the first to take on additional width if the
        // split view grows or shrinks.
        //
        super.viewDidLoad()
        
        // insert an empty menu item at the beginning of the drown down button's menu and add its image
        let actionImage = NSImage(named: NSImage.actionTemplateName)!
        actionImage.size = NSMakeSize(10,10)
        
        let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        self.actionButton.menu?.insertItem(menuItem, at: 0)
        menuItem.image = actionImage
        
        self.actionButton.menu?.autoenablesItems = false
        
        // start off by disabling the Edit... menu item until we are notified of a selection
        self.editBookmarkMenuItem.isEnabled = false
        
        // truncate to the middle if the url is too long to fit
        self.urlField.cell?.lineBreakMode = .byTruncatingMiddle
    }
    
    // -------------------------------------------------------------------------------
    //	viewWillAppear
    // -------------------------------------------------------------------------------
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // listen for selection changes from the NSOutlineView inside MyOutlineViewController
        // note: we start observing after our outline view is populated so we don't receive unnecessary notifications at startup
        //
        NotificationCenter.default.addObserver(self,
            selector: #selector(self.selectionDidChange(_:)),
            name: NSOutlineView.selectionDidChangeNotification,
            object: nil)
        
        // notification so we know when the icon view controller is done populating its content
        NotificationCenter.default.addObserver(self,
            selector: #selector(self.contentReceived(_:)),
            name: Notification.Name(kReceivedContentNotification),
            object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	dealloc
    // -------------------------------------------------------------------------------
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSOutlineView.selectionDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(kReceivedContentNotification), object: nil)
    }
    
    
    //MARK: - NSNotifications
    
    // -------------------------------------------------------------------------------
    //  contentReceived:notif
    //
    //  Notification sent from IconViewController class,
    //  indicating the file system content has been received
    // -------------------------------------------------------------------------------
    @objc func contentReceived(_ notif: Notification) {
        self.progIndicator.isHidden = true
        self.progIndicator.stopAnimation(self)
    }
    
    // -------------------------------------------------------------------------------
    //  Listens for changes outline view row selection
    // -------------------------------------------------------------------------------
    @objc func selectionDidChange(_ notification: Notification) {
        // examine the current selection and adjust the UI
        //
        let outlineView = notification.object as! NSOutlineView
        let selectedRow = outlineView.selectedRow
        if selectedRow == -1 {
            // there is no current selection - no item to display
            self.removeButton.isEnabled = false
            self.urlField.stringValue = ""
            self.editBookmarkMenuItem.isEnabled = false
        } else {
            // single selection only
            self.removeButton.isEnabled = true
            
            // report the URL to our NSTextField
            let item = (outlineView.item(atRow: selectedRow)! as AnyObject).representedObject as! BaseNode
            
            if item.isBookmark {
                self.urlField.stringValue = item.url?.absoluteString ?? ""
            } else {
                
                self.urlField.stringValue = item.url?.path ?? ""
            }
            
            // enable the Edit... menu item if the selected node is a bookmark
            self.editBookmarkMenuItem.isEnabled = !(item.url?.isFileURL ?? true)
            
            if item.isDirectory {
                // we are populating the detail view controler with contents of a folder on disk
                // (may take a while)
                self.progIndicator.isHidden = false
            }
        }
    }
    
    
    //MARK: - Folders
    
    // -------------------------------------------------------------------------------
    //	addFolderAction:sender:
    // -------------------------------------------------------------------------------
    @IBAction func addFolderAction(_: AnyObject) {
        // post notification to MyOutlineViewController to add a new folder
        NotificationCenter.default.post(name: Notification.Name(kAddFolderNotification), object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	removeFolderAction:sender:
    // -------------------------------------------------------------------------------
    @IBAction func removeFolderAction(_: AnyObject) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Are you sure you want to remove this item?", comment: "")
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.beginSheetModal(for: self.view.window!) {returnCode in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                // post notification to MyOutlineViewController to remove the selected folder
                NotificationCenter.default.post(name: Notification.Name(kRemoveFolderNotification), object: nil)
            }
        }
    }
    
    
    //MARK: - Bookmarks
    
    // -------------------------------------------------------------------------------
    //	addBookmarkAction:sender
    // -------------------------------------------------------------------------------
    @IBAction func addBookmarkAction(_: AnyObject) {
        // post notification to MyOutlineViewController to add a new bookmark
        NotificationCenter.default.post(name: Notification.Name(kAddBookmarkNotification), object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	editChildAction:sender
    // -------------------------------------------------------------------------------
    @IBAction func editBookmarkAction(_: AnyObject) {
        // post notification to MyOutlineViewController to edit a selected bookmark
        NotificationCenter.default.post(name: Notification.Name(kEditBookmarkNotification), object: nil)
    }
    
}
