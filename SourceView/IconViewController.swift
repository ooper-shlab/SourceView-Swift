//
//  IconViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/5.
//
//
/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller object to host the icon collection view.
 */

import Cocoa

// notification for indicating file system content has been received
let kReceivedContentNotification = "ReceivedContentNotification"

// Key values for the icon view dictionary.
private let KEY_NAME = "name"
private let KEY_ICON = "icon"


//MARK: -

@objc(IconViewController)
class IconViewController: NSViewController {
    
    // This view controller can be populated two ways:
    //    file system url, or from a BaseNode of internet shortcuts
    //
    @objc dynamic var url: URL?
    var baseNode: BaseNode? {
        didSet {didSetBaseNode(oldValue)}
    }
    
    @objc dynamic var icons: [[String: Any]] = []
    
    
    //MARK: -
    
    // -------------------------------------------------------------------------------
    //	awakeFromNib
    // -------------------------------------------------------------------------------
    override func awakeFromNib() {
        // Listen for changes in the url for this view.
        //###Neither the receiver, nor anObserver, are retained.
        self.addObserver(self,
                         forKeyPath: "url",
                         options: [.new, .old],
                         context: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	dealloc
    // -------------------------------------------------------------------------------
    deinit {
        self.removeObserver(self, forKeyPath: "url")
    }
    
    // -------------------------------------------------------------------------------
    //	setBaseNode:baseNode
    // -------------------------------------------------------------------------------
    private func didSetBaseNode(_ oldBaseNode: BaseNode?) {
        // Our base node has changed, notify ourselves to update our data source.
        self.gatherContents(baseNode!)
    }
    
    // -------------------------------------------------------------------------------
    //	updateIcons:iconArray
    //
    //	The incoming object is the NSArray of file system objects to display.
    //-------------------------------------------------------------------------------
    //@objc
    private func updateIcons(_ iconArray: [[String: Any]]) {
        self.icons = iconArray
        
        NotificationCenter.default.post(name: Notification.Name(kReceivedContentNotification), object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	gatherContents:inObject
    //
    //	Gathering the contents and their icons could be expensive.
    //	This method is being called on a separate thread to avoid blocking the UI.
    // -------------------------------------------------------------------------------
    private func gatherContents(_ inObject: Any) {
        autoreleasepool {
            
            var contentArray: [[String: Any]] = []
            
            if inObject is BaseNode {
                // We are populating our collection view with a set of internet shortcuts from our baseNode.
                //
                let shortcuts = self.baseNode!.children
                for node in shortcuts {
                    // the node's icon was set to a smaller size before, for this collection view we need to make it bigger
                    var content: [String: Any] = [
                        KEY_NAME: node.nodeTitle
                    ]
                    if let shortcutIcon = node.nodeIcon?.copy() as! NSImage? {
                        shortcutIcon.size = NSMakeSize(kIconLargeImageSize, kIconLargeImageSize)
                        content[KEY_ICON] = shortcutIcon
                    }
                    
                    contentArray.append(content)
                }
            } else {
                // We are populating our collection view with a file system directory URL.
                //
                let urlToDirectory = inObject as! URL
                do {
                    let fileURLs = try FileManager.default.contentsOfDirectory(at: urlToDirectory,
                                                                               includingPropertiesForKeys: [], options: [])
                    for element in fileURLs {
                        let elementIcon = NSWorkspace.shared.icon(forFile: element.path)
                        
                        // only allow visible objects
                        let resource = try element.resourceValues(forKeys: [.isHiddenKey, .localizedNameKey])
                        let isHidden = resource.isHidden!
                        if !isHidden {
                            let elementNameStr = resource.localizedName!
                            // file system object is visible so add to our array
                            contentArray.append([
                                KEY_ICON: elementIcon,
                                KEY_NAME: elementNameStr
                                ])
                        }
                    }
                } catch _ {}
            }
            
            // call back on the main thread to update the icons in our view
            //### Seems DispatchQueue.main.sync does not work as performSelector(onMainThread:with:waitUntilDone:)
            //### DispatchQueue.main.async does not `waitUntilDone`, but enough for updating icons...
            DispatchQueue.main.async {
                self.updateIcons(contentArray)
            }
//            self.performSelector(onMainThread: #selector(updateIcons(_:)), with: contentArray, waitUntilDone: true)
        }
    }
    
    
    //MARK: - KVO
    
    // -------------------------------------------------------------------------------
    //	observeValueForKeyPath:ofObject:change:context
    //
    //	Listen for changes in the file url.
    //	Given a url, obtain its contents and add only the invisible items to the collection.
    // -------------------------------------------------------------------------------
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?)
    {
        // build our directory contents on a separate thread,
        // some portions are from disk which could get expensive depending on the size
        //
        DispatchQueue.global(qos: .default).async {
            self.gatherContents(self.url!)
        }
    }
    
}
