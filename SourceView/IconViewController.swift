//
//  IconViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/5.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller object to host the icon collection view.
 */

import Cocoa

// notification for indicating file system content has been received
let kReceivedContentNotification = "ReceivedContentNotification"

// key values for the icon view dictionary
private let KEY_NAME = "name"
private let KEY_ICON = "icon"

// notification for indicating file system content has been received

@objc(IconViewBox)
class IconViewBox: NSBox {
    override func hitTest(aPoint: NSPoint) -> NSView? {
        // don't allow any mouse clicks for subviews in this NSBox
        return nil
    }
}


//MARK: -

@objc(IconViewController)
class IconViewController: NSViewController {
    
    dynamic var url: NSURL?
    
    @IBOutlet private var iconArrayController: NSArrayController!
    dynamic var icons: [AnyObject] = []
    
    
    // -------------------------------------------------------------------------------
    //	awakeFromNib
    // -------------------------------------------------------------------------------
    override func awakeFromNib() {
        // listen for changes in the url for this view
        //###Neither the receiver, nor anObserver, are retained.
        self.addObserver(self,
            forKeyPath: "url",
            options: [.New, .Old],
            context: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	dealloc
    // -------------------------------------------------------------------------------
    deinit {
        self.removeObserver(self, forKeyPath: "url")
    }
    
    // -------------------------------------------------------------------------------
    //	updateIcons:iconArray
    //
    //	The incoming object is the NSArray of file system objects to display.
    //-------------------------------------------------------------------------------
    private func updateIcons(iconArray: [AnyObject]) {
        self.icons = iconArray
        
        NSNotificationCenter.defaultCenter().postNotificationName(kReceivedContentNotification, object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	gatherContents:inObject
    //
    //	Gathering the contents and their icons could be expensive.
    //	This method is being called on a separate thread to avoid blocking the UI.
    // -------------------------------------------------------------------------------
    private func gatherContents(inObject: NSURL) {
        var contentArray: [AnyObject] = []
        autoreleasepool {
            
            do {
                let fileURLs = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(self.url!,
                    includingPropertiesForKeys: [],
                    options: [])
                for element in fileURLs {
                    let elementIcon = NSWorkspace.sharedWorkspace().iconForFile(element.path!)
                    
                    // only allow visible objects
                    var hiddenFlag: AnyObject? = nil
                    try element.getResourceValue(&hiddenFlag, forKey: NSURLIsHiddenKey)
                    if !(hiddenFlag as! Bool) {
                        var elementNameStr: AnyObject? = nil
                        try element.getResourceValue(&elementNameStr, forKey: NSURLLocalizedNameKey)
                        // file system object is visible so add to our array
                        contentArray.append([
                            "icon": elementIcon,
                            "name": elementNameStr as! String
                            ])
                    }
                }
            } catch _ {}
            
            // call back on the main thread to update the icons in our view
            dispatch_sync(dispatch_get_main_queue()) {
                self.updateIcons(contentArray)
            }
        }
    }
    
    // -------------------------------------------------------------------------------
    //	observeValueForKeyPath:ofObject:change:context
    //
    //	Listen for changes in the file url.
    //	Given a url, obtain its contents and add only the invisible items to the collection.
    // -------------------------------------------------------------------------------
    override func observeValueForKeyPath(keyPath: String?,
        ofObject object: AnyObject?,
        change: [String : AnyObject]?,
        context: UnsafeMutablePointer<Void>)
    {
        // build our directory contents on a separate thread,
        // some portions are from disk which could get expensive depending on the size
        //
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.gatherContents(self.url!)
        }
    }
    
}