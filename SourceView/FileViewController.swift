//
//  FileViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/6.
//
//
/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller object to host the UI for file information
 */

import Cocoa

@objc(FileViewController)
class FileViewController: NSViewController {
    
    var url: URL?
    
    @IBOutlet private var fileIcon: NSImageView!
    @IBOutlet private var fileName: NSTextField!
    @IBOutlet private var fileSize: NSTextField!
    @IBOutlet private var modDate: NSTextField!
    @IBOutlet private var creationDate: NSTextField!
    @IBOutlet private var fileKindString: NSTextField!
    
    //MARK: -
    
    // -------------------------------------------------------------------------------
    //	awakeFromNib
    // -------------------------------------------------------------------------------
    override func awakeFromNib() {
        // listen for changes in the url for this view
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
    //	observeValueForKeyPath:ofObject:change:context
    //
    //	Listen for changes in the file url.
    // -------------------------------------------------------------------------------
    override func observeValue(forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?)
    {
        if let url = self.url {
            let path = url.path
            // name
            self.fileName.stringValue = FileManager.default.displayName(atPath: path)
            
            // icon
            let iconImage = NSWorkspace.shared().icon(forFile: path)
            iconImage.size = NSMakeSize(64, 64)
            self.fileIcon.image = iconImage
            if let attr = try? FileManager.default.attributesOfItem(atPath: path) {
                // file size
                let theFileSize = attr[FileAttributeKey.size] as! NSNumber
                self.fileSize.stringValue = "\(theFileSize.stringValue) KB on disk"
                
                // creation date
                let fileCreationDate = attr[FileAttributeKey.creationDate] as! Date
                self.creationDate.stringValue = fileCreationDate.description
                
                // mod date
                let fileModDate = attr[FileAttributeKey.modificationDate] as! Date
                self.modDate.stringValue = fileModDate.description
            }
            
            // kind string
            let resource = try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey])
            let kindStr = resource?.localizedTypeDescription
            if let str = kindStr {
                self.fileKindString.stringValue = str
            }
        } else {
            self.fileName.stringValue = ""
            self.fileIcon.image = nil
            self.fileSize.stringValue = ""
            self.creationDate.stringValue = ""
            self.modDate.stringValue = ""
            self.fileKindString.stringValue = ""
        }
    }
    
}
