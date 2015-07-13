//
//  MyWindowController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/6.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Interface for MyWindowController class, the main controller class for this sample.
 */

import Cocoa

import WebKit

private let COLUMNID_NAME = "NameColumn"	// the single column name in our outline view
private let INITIAL_INFODICT = "Outline"		// name of the dictionary file to populate our outline view

private let ICONVIEW_NIB_NAME = "IconView"		// nib name for the icon view
private let FILEVIEW_NIB_NAME = "FileView"		// nib name for the file view
private let CHILDEDIT_NAME = "ChildEdit"	// nib name for the child edit window //
private let UNTITLED_NAME = "Untitled"		// default name for added folders and leafs

private let HTTP_PREFIX = "http://"

// default folder titles
private let PLACES_NAME = "PLACES"
private let BOOKMARKS_NAME = "BOOKMARKS"

// keys in our disk-based dictionary representing our outline view's data
private let KEY_NAME = "name"
private let KEY_URL = "url"
private let KEY_SEPARATOR = "separator"
private let KEY_GROUP = "group"
private let KEY_FOLDER = "folder"
private let KEY_ENTRIES = "entries"

let kMinOutlineViewSplit: CGFloat = 120.0

let kIconImageSize: CGFloat = 16.0

private let kNodesPBoardType = "myNodesPBoardType"	// drag and drop pasteboard type

//MARK: -

// -------------------------------------------------------------------------------
//	TreeAdditionObj
//
//	This object is used for passing data between the main and secondary thread
//	which populates the outline view.
// -------------------------------------------------------------------------------
@objc(TreeAdditionObj)
class TreeAdditionObj: NSObject {
    
    let nodeURL: String?
    let nodeName: String?
    let selectItsParent: Bool
    
    
    //MARK: -
    
    // -------------------------------------------------------------------------------
    //  initWithURL:url:name:select
    // -------------------------------------------------------------------------------
    init(URL url: String?, withName name: String?, selectItsParent select: Bool) {
        
        nodeName = name
        nodeURL = url
        selectItsParent = select
        super.init()
        
    }
}


//MARK: -

@objc(MyWindowController)
class MyWindowController: NSWindowController, NSOutlineViewDelegate, NSSplitViewDelegate,
        WebFrameLoadDelegate, WebUIDelegate {
    @IBOutlet private var myOutlineView: NSOutlineView!
    @IBOutlet private var treeController: NSTreeController!
    @IBOutlet private var placeHolderView: NSView!
    @IBOutlet private var splitView: NSSplitView!
    @IBOutlet private var webView: WebView!
    @IBOutlet private var progIndicator: NSProgressIndicator!
    @IBOutlet private var addFolderButton: NSButton!
    @IBOutlet private var removeButton: NSButton!
    @IBOutlet private var actionButton: NSPopUpButton!
    @IBOutlet private var urlField: NSTextField!
    
    // cached images for generic folder and url document
    private var folderImage: NSImage?
    private var urlImage: NSImage?
    
    private var currentView: NSView?
    private var iconViewController: IconViewController!
    private var fileViewController: FileViewController!
    private var childEditController: ChildEditController!
    
    private var retargetWebView: Bool = false
    
    private var separatorCell: SeparatorCell!	// the cell used to draw a separator line in the outline view
    //}
    
    private var dragNodesArray: [NSTreeNode] = [] // used to keep track of dragged nodes
    dynamic private var contents: [AnyObject] = [] // used to keep track of dragged nodes
    
    
    //MARK: -
    
    // -------------------------------------------------------------------------------
    //	initWithWindow:window
    // -------------------------------------------------------------------------------
    override init(window: NSWindow?) {
        super.init(window: window)
        
        // cache the reused icon images
        folderImage = NSWorkspace.sharedWorkspace().iconForFileType(NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
        folderImage!.size = NSMakeSize(kIconImageSize, kIconImageSize)
        
        urlImage = NSWorkspace.sharedWorkspace().iconForFileType(NSFileTypeForHFSTypeCode(OSType(kGenericURLIcon)))
        urlImage!.size = NSMakeSize(kIconImageSize, kIconImageSize)
        
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // -------------------------------------------------------------------------------
    //	dealloc
    // -------------------------------------------------------------------------------
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kReceivedContentNotification, object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	awakeFromNib
    // -------------------------------------------------------------------------------
    override func awakeFromNib() {
        // load the icon view controller for later use
        iconViewController = IconViewController(nibName: ICONVIEW_NIB_NAME, bundle: nil)
        
        // load the file view controller for later use
        fileViewController = FileViewController(nibName: FILEVIEW_NIB_NAME, bundle: nil)
        
        // load the child edit view controller for later use
        childEditController = ChildEditController(windowNibName: CHILDEDIT_NAME)
        
        self.window?.setAutorecalculatesContentBorderThickness(true, forEdge: NSRectEdge.MinY)
        self.window?.setContentBorderThickness(40, forEdge: NSRectEdge.MinY)
        
        // apply our custom ImageAndTextCell for rendering the first column's cells
        let tableColumn = myOutlineView.tableColumnWithIdentifier(COLUMNID_NAME)!
        let imageAndTextCell = ImageAndTextCell(textCell: "")
        imageAndTextCell.editable = true
        tableColumn.dataCell = imageAndTextCell
        
        separatorCell = SeparatorCell()
        separatorCell.editable = false
        
        // add our content
        self.populateOutlineContents()
        
        // add images to our add/remove buttons
        let addImage = NSImage(named: NSImageNameAddTemplate)
        addFolderButton.image = addImage
        let removeImage = NSImage(named: NSImageNameRemoveTemplate)
        removeButton.image = removeImage
        
        // insert an empty menu item at the beginning of the drown down button's menu and add its image
        let actionImage = NSImage(named: NSImageNameActionTemplate)!
        actionImage.size = NSMakeSize(10, 10)
        
        let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        actionButton.menu!.insertItem(menuItem, atIndex: 0)
        menuItem.image = actionImage
        
        // truncate to the middle if the url is too long to fit
        (urlField.cell as! NSTextFieldCell).lineBreakMode = .ByTruncatingMiddle
        
        // scroll to the top in case the outline contents is very long
        myOutlineView.enclosingScrollView?.verticalScroller?.floatValue = 0.0
        myOutlineView.enclosingScrollView?.contentView.scrollToPoint(NSMakePoint(0, 0))
        
        // make our outline view appear with gradient selection, and behave like the Finder, iTunes, etc.
        myOutlineView.selectionHighlightStyle = .SourceList
        
        // drag and drop support
        myOutlineView.registerForDraggedTypes([kNodesPBoardType,			// our internal drag type
            NSURLPboardType,			// single url from pasteboard
            NSFilenamesPboardType,		// from Safari or Finder
            NSFilesPromisePboardType])
        
        webView.UIDelegate = self	// be the webView's delegate to capture NSResponder calls
        webView.frameLoadDelegate = self    // so we can receive any possible errors
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "contentReceived:",
            name: kReceivedContentNotification,
            object: nil)
    }
    
    
    //MARK: - Actions
    
    // -------------------------------------------------------------------------------
    //	selectParentFromSelection
    //
    //	Take the currently selected node and select its parent.
    // -------------------------------------------------------------------------------
    private func selectParentFromSelection() {
        if !treeController.selectedNodes.isEmpty {
            let firstSelectedNode = treeController.selectedNodes[0] as NSTreeNode
            if let parentNode = firstSelectedNode.parentNode {
                // select the parent
                let parentIndex = parentNode.indexPath
                treeController.setSelectionIndexPath(parentIndex)
            } else {
                // no parent exists (we are at the top of tree), so make no selection in our outline
                let selectionIndexPaths = treeController.selectionIndexPaths
                treeController.removeSelectionIndexPaths(selectionIndexPaths)
            }
        }
    }
    
    // -------------------------------------------------------------------------------
    //	performAddFolder:treeAddition
    // -------------------------------------------------------------------------------
    private func performAddFolder(treeAddition: TreeAdditionObj) {
        // NSTreeController inserts objects using NSIndexPath, so we need to calculate this
        var indexPath: NSIndexPath? = nil
        
        // if there is no selection, we will add a new group to the end of the contents array
        if treeController.selectedObjects.isEmpty {
            // there's no selection so add the folder to the top-level and at the end
            indexPath = NSIndexPath(index: self.contents.count)
        } else {
            // get the index of the currently selected node, then add the number its children to the path -
            // this will give us an index which will allow us to add a node to the end of the currently selected node's children array.
            //
            indexPath = treeController.selectionIndexPath
            if (treeController.selectedObjects.first! as! BaseNode).isLeaf {
                // user is trying to add a folder on a selected child,
                // so deselect child and select its parent for addition
                self.selectParentFromSelection()
            } else {
                indexPath = indexPath!.indexPathByAddingIndex((treeController.selectedObjects[0] as! BaseNode).children.count)
            }
        }
        
        let node = ChildNode()
        node.nodeTitle = treeAddition.nodeName!
        
        // the user is adding a child node, tell the controller directly
        treeController.insertObject(node, atArrangedObjectIndexPath: indexPath!)
        
    }
    
    // -------------------------------------------------------------------------------
    //	addFolder:folderName
    // -------------------------------------------------------------------------------
    private func addFolder(folderName: String) {
        let treeObjInfo = TreeAdditionObj(URL: nil, withName: folderName, selectItsParent: false)
        self.performAddFolder(treeObjInfo)
    }
    
    // -------------------------------------------------------------------------------
    //	addFolderAction:sender:
    // -------------------------------------------------------------------------------
    @IBAction func addFolderAction(_: AnyObject) {
        self.addFolder(UNTITLED_NAME)
    }
    
    // -------------------------------------------------------------------------------
    //	performAddChild:treeAddition
    // -------------------------------------------------------------------------------
    func performAddChild(treeAddition: TreeAdditionObj) {
        if !treeController.selectedObjects.isEmpty {
            // we have a selection
            if (treeController.selectedObjects[0] as! BaseNode).isLeaf {
                // trying to add a child to a selected leaf node, so select its parent for add
                self.selectParentFromSelection()
            }
        }
        
        // find the selection to insert our node
        var indexPath: NSIndexPath? = nil
        if !treeController.selectedObjects.isEmpty {
            // we have a selection, insert at the end of the selection
            indexPath = treeController.selectionIndexPath
            indexPath = indexPath!.indexPathByAddingIndex((treeController.selectedObjects[0] as! BaseNode).children.count)
        } else {
            // no selection, just add the child to the end of the tree
            indexPath = NSIndexPath(index: self.contents.count)
        }
        
        // create a leaf node
        let node = ChildNode(leaf: ())
        node.urlString = treeAddition.nodeURL
        
        if treeAddition.nodeURL != nil {
            if !treeAddition.nodeURL!.isEmpty {
                // the child to insert has a valid URL, use its display name as the node title
                if treeAddition.nodeName != nil {
                    node.nodeTitle = treeAddition.nodeName!
                } else {
                    node.nodeTitle = NSFileManager.defaultManager().displayNameAtPath(node.urlString!)
                }
            } else {
                // the child to insert will be an empty URL
                node.nodeTitle = UNTITLED_NAME
                node.urlString = HTTP_PREFIX
            }
        }
        
        // the user is adding a child node, tell the controller directly
        treeController.insertObject(node, atArrangedObjectIndexPath: indexPath!)
        
        // adding a child automatically becomes selected by NSOutlineView, so keep its parent selected
        if treeAddition.selectItsParent {
            self.selectParentFromSelection()
        }
    }
    
    // -------------------------------------------------------------------------------
    //	addChild:url:withName:selectParent
    // -------------------------------------------------------------------------------
    private func addChild(url: String?, withName nameStr: String?, selectParent select: Bool) {
        let treeObjInfo = TreeAdditionObj(URL: url,
            withName: nameStr,
            selectItsParent: select)
        self.performAddChild(treeObjInfo)
    }
    
    // -------------------------------------------------------------------------------
    //	addBookmarkAction:sender
    // -------------------------------------------------------------------------------
    @IBAction func addBookmarkAction(_: AnyObject) {
        // ask our edit sheet for information on the new child to be added
        let newValues = childEditController.edit(nil, from: self)
        
        if !childEditController.wasCancelled && !newValues.isEmpty {
            let itemStr = newValues["name"]!
            self.addChild(newValues["url"],
                withName: !itemStr.isEmpty ? itemStr : UNTITLED_NAME,
                selectParent: false)	// add empty untitled child
        }
    }
    
    // -------------------------------------------------------------------------------
    //	editChildAction:sender
    // -------------------------------------------------------------------------------
    @IBAction func editBookmarkAction(_: AnyObject) {
        let indexPath = treeController.selectionIndexPath
        
        // get the selected item's name and url
        let selectedRow = myOutlineView.selectedRow
        let node = myOutlineView.itemAtRow(selectedRow)!.representedObject as! BaseNode
        let editInfo: [String: String] = ["name": node.nodeTitle,
            "url": node.urlString ?? ""]
        
        // only open the edit alert sheet for URL leafs (not folders or file system objects)
        //
        if node.urlString?.isEmpty ?? true || !node.urlString!.hasPrefix(HTTP_PREFIX) {
            // it's a folder or a file-system based object, just allow editing the cell title
            myOutlineView.editColumn(0, row: selectedRow, withEvent: NSApp.currentEvent, select: true)
        } else {
            // ask our sheet to edit these two values
            let newValues = childEditController.edit(editInfo, from: self)
            if !childEditController.wasCancelled && !newValues.isEmpty {
                // create a child node
                let childNode = ChildNode(leaf: ())
                childNode.urlString = newValues["url"]
                
                let nodeStr = newValues["name"]!
                childNode.nodeTitle = !nodeStr.isEmpty ? nodeStr : UNTITLED_NAME
                // remove the current selection and replace it with the newly edited child
                treeController.remove(self)
                treeController.insertObject(childNode, atArrangedObjectIndexPath: indexPath!)
            }
        }
    }
    
    // -------------------------------------------------------------------------------
    //	addEntries:discloseParent:
    // -------------------------------------------------------------------------------
    private func addEntries(entries: [[NSObject: AnyObject]], discloseParent: Bool) {
        for entry in entries {
            let urlStr = entry[KEY_URL] as! String?
            
            if entry[KEY_SEPARATOR] != nil {
                // its a separator mark, we treat is as a leaf
                self.addChild(nil, withName: nil, selectParent: true)
            } else if entry[KEY_FOLDER] != nil {
                // we treat file system folders as a leaf and show its contents in the NSCollectionView
                let folderName = entry[KEY_FOLDER]! as! String
                self.addChild(urlStr, withName: folderName, selectParent: true)
            } else if entry[KEY_URL] != nil {
                // its a leaf item with a URL
                let nameStr = entry[KEY_NAME] as! String?
                self.addChild(urlStr, withName: nameStr, selectParent: true)
            } else {
                // it's a generic container
                let folderName = entry[KEY_GROUP]! as! String
                self.addFolder(folderName)
                
                // add its children
                let newChildren = entry[KEY_ENTRIES]! as! [[NSObject: AnyObject]]
                self.addEntries(newChildren, discloseParent: false)
                
                self.selectParentFromSelection()
            }
        }
        
        if !discloseParent {
            // inserting children automatically expands its parent, we want to close it
            if !treeController.selectedNodes.isEmpty {
                let lastSelectedNode: AnyObject = treeController.selectedNodes.first!
                myOutlineView.collapseItem(lastSelectedNode)
            }
        }
    }
    
    // -------------------------------------------------------------------------------
    //	populateOutline
    //
    //	Populate the tree controller from disk-based dictionary (Outline.dict)
    // -------------------------------------------------------------------------------
    private func populateOutline() {
        // add the "Bookmarks" section
        self.addFolder(BOOKMARKS_NAME)
        
        let initData = NSDictionary(contentsOfFile:
            NSBundle.mainBundle().pathForResource(INITIAL_INFODICT, ofType: "dict")!)!
        let entries = initData[KEY_ENTRIES]! as! [[NSObject: AnyObject]]
        self.addEntries(entries, discloseParent: true)
        
        self.selectParentFromSelection()
    }
    
    // -------------------------------------------------------------------------------
    //	addPlacesSection
    // -------------------------------------------------------------------------------
    private func addPlacesSection() {
        // add the "Places" section
        self.addFolder(PLACES_NAME)
        
        // add its children
        self.addChild(NSHomeDirectory(), withName: "Home", selectParent: true)
        
        let appsDirectory = NSSearchPathForDirectoriesInDomains(.ApplicationDirectory, .LocalDomainMask, true)
        self.addChild(appsDirectory[0], withName: nil, selectParent: true)
        
        self.selectParentFromSelection()
    }
    
    // -------------------------------------------------------------------------------
    //	populateOutlineContents
    // -------------------------------------------------------------------------------
    private func populateOutlineContents() {
        // hide the outline view - don't show it as we are building the content
        myOutlineView.hidden = true
        
        self.addPlacesSection()		// add the "Places" outline section
        self.populateOutline()			// add the "Bookmark" outline content
        
        // remove the current selection
        let selection = treeController.selectionIndexPaths
        treeController.removeSelectionIndexPaths(selection)
        
        myOutlineView.hidden = false	// we are done populating the outline view content, show it again
    }
    
    
    //MARK: - WebView
    
    // -------------------------------------------------------------------------------
    //	webView:makeFirstResponder
    //
    //	We want to keep the outline view in focus as the user clicks various URLs.
    //
    //	So this workaround applies to an unwanted side affect to some web pages that might have
    //	JavaScript code thatt focus their text fields as we target the web view with a particular URL.
    //
    // -------------------------------------------------------------------------------
    func webView(sender: WebView!, makeFirstResponder responder: NSResponder!) {
        if retargetWebView {
            // we are targeting the webview ourselves as a result of the user clicking
            // a url in our outlineview: don't do anything, but reset our target check flag
            //
            retargetWebView = false
        } else {
            // continue the responder chain
            self.window?.makeFirstResponder(sender)
        }
    }
    
    // -------------------------------------------------------------------------------
    //	didFailProvisionalLoadWithError
    // -------------------------------------------------------------------------------
    func webView(sender: WebView!, didFailProvisionalLoadWithError error: NSError!, forFrame frame: WebFrame!) {
        // the URL failed to load in our web view, remove the detail view
        self.removeSubview()
        currentView = nil
    }
    
    
    //MARK: - Menu management
    
    // -------------------------------------------------------------------------------
    //  validateMenuItem:item
    // -------------------------------------------------------------------------------
    override func validateMenuItem(item: NSMenuItem) -> Bool {
        var enabled = false
        
        // is it our "Edit..." menu item in our action button?
        if item.action == Selector("editBookmarkAction:") {
            if !treeController.selectedNodes.isEmpty {
                // only allow for editing http url items or items with out a URL
                // (this avoids accidentally renaming real file system items)
                //
                let firstSelectedNode = treeController.selectedNodes.first! as NSTreeNode
                let node = firstSelectedNode.representedObject as! BaseNode
                if node.urlString?.isEmpty ?? true || node.urlString!.hasPrefix(HTTP_PREFIX) {
                    enabled = true
                }
            }
        }
        
        return enabled
    }
    
    
    //MARK: - Node checks
    
    // -------------------------------------------------------------------------------
    //	isSeparator:node
    // -------------------------------------------------------------------------------
    private func isSeparator(node: BaseNode) -> Bool {
        return node.nodeIcon == nil && node.nodeTitle.isEmpty
    }
    
    // -------------------------------------------------------------------------------
    //	isSpecialGroup:groupNode
    // -------------------------------------------------------------------------------
    private func isSpecialGroup(groupNode: BaseNode) -> Bool {
        return (groupNode.nodeIcon == nil &&
            (groupNode.nodeTitle == BOOKMARKS_NAME || groupNode.nodeTitle == PLACES_NAME))
    }
    
    
    //MARK: - Managing Views
    
    // -------------------------------------------------------------------------------
    //  contentReceived:notif
    //
    //  Notification sent from IconViewController class,
    //  indicating the file system content has been received
    // -------------------------------------------------------------------------------
    func contentReceived(notif: NSNotification) {
        progIndicator.hidden = true
        progIndicator.stopAnimation(self)
    }
    
    // -------------------------------------------------------------------------------
    //	removeSubview
    // -------------------------------------------------------------------------------
    private func removeSubview() {
        // empty selection
        let subViews = placeHolderView.subviews
        if !subViews.isEmpty {
            subViews[0].removeFromSuperview()
        }
        
        placeHolderView.displayIfNeeded()	// we want the removed views to disappear right away
    }
    
    // -------------------------------------------------------------------------------
    //	changeItemView
    // ------------------------------------------------------------------------------
    private func changeItemView() {
        let selection = treeController.selectedNodes
        if !selection.isEmpty {
            let node = selection[0].representedObject as! BaseNode
            if let urlStr = node.urlString {
                if urlStr.hasPrefix(HTTP_PREFIX) {
                    // 1) the url is a web-based url
                    //
                    if currentView !== webView {
                        // change to web view
                        self.removeSubview()
                        currentView = nil
                        placeHolderView.addSubview(webView)
                        currentView = webView
                    }
                    
                    // this will tell our WebUIDelegate not to retarget first responder since some web pages force
                    // forus to their text fields - we want to keep our outline view in focus.
                    retargetWebView = true
                    
                    webView.mainFrameURL = urlStr	// re-target to the new url
                } else {
                    // 2) the url is file-system based (folder or file)
                    //
                    if currentView !== fileViewController.view || currentView !== iconViewController.view {
                        let targetURL = NSURL(fileURLWithPath: urlStr)
                        
                        // detect if the url is a directory
                        var isDirectory: AnyObject? = nil
                        
                        do {
                            try targetURL.getResourceValue(&isDirectory, forKey: NSURLIsDirectoryKey)
                        } catch _ {
                        }
                        if isDirectory?.boolValue ?? false {
                            // avoid a flicker effect by not removing the icon view if it is already embedded
                            if currentView !== iconViewController.view {
                                // remove the old subview
                                self.removeSubview()
                                currentView = nil
                            }
                            
                            // change to icon view to display folder contents
                            placeHolderView.addSubview(iconViewController.view)
                            currentView = iconViewController.view
                            
                            // its a directory - show its contents using NSCollectionView
                            iconViewController.url = targetURL
                            
                            // add a spinning progress gear in case populating the icon view takes too long
                            progIndicator.hidden = false
                            progIndicator.startAnimation(self)
                            
                            // note: we will be notifed back to stop our progress indicator
                            // as soon as iconViewController is done fetching its content.
                        } else {
                            // 3) its a file, just show the item info
                            //
                            // remove the old subview
                            self.removeSubview()
                            currentView = nil
                            
                            // change to file view
                            placeHolderView.addSubview(fileViewController.view)
                            currentView = fileViewController.view
                            
                            // update the file's info
                            fileViewController.url = targetURL
                        }
                    }
                }
                
                var newBounds = NSRect()
                newBounds.origin.x = 0
                newBounds.origin.y = 0
                newBounds.size.width = currentView?.superview!.frame.size.width ?? 0.0
                newBounds.size.height = currentView?.superview!.frame.size.height ?? 0.0
                currentView?.frame = currentView!.superview!.frame
                
                // make sure our added subview is placed and resizes correctly
                currentView?.setFrameOrigin(NSMakePoint(0, 0))
                currentView?.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
            } else {
                // there's no url associated with this node
                // so a container was selected - no view to display
                self.removeSubview()
                currentView = nil
            }
        }
    }
    
    
    //MARK: - NSOutlineViewDelegate
    
    // -------------------------------------------------------------------------------
    //	shouldSelectItem:item
    // -------------------------------------------------------------------------------
    func outlineView(outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
        // don't allow special group nodes (Places and Bookmarks) to be selected
        let node = item.representedObject as! BaseNode
        return !self.isSpecialGroup(node) && !self.isSeparator(node)
    }
    
    // -------------------------------------------------------------------------------
    //	dataCellForTableColumn:tableColumn:item
    // -------------------------------------------------------------------------------
    func outlineView(outlineView: NSOutlineView, dataCellForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSCell? {
        var returnCell = tableColumn?.dataCell as! NSCell?
        
        if tableColumn?.identifier == COLUMNID_NAME {
            // we are being asked for the cell for the single and only column
            let node = item.representedObject as! BaseNode
            if self.isSeparator(node) {
                returnCell = separatorCell
            }
        }
        
        return returnCell
    }
    
    // -------------------------------------------------------------------------------
    //	textShouldEndEditing:fieldEditor
    // -------------------------------------------------------------------------------
    func control(control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if fieldEditor.string?.isEmpty ?? true {
            // don't allow empty node names
            return false
        } else {
            return true
        }
    }
    
    // -------------------------------------------------------------------------------
    //	shouldEditTableColumn:tableColumn:item
    //
    //	Decide to allow the edit of the given outline view "item".
    // -------------------------------------------------------------------------------
    func outlineView(outlineView: NSOutlineView, shouldEditTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> Bool {
        var result: Bool = true
        
        let itemNode = item.representedObject as! BaseNode
        if self.isSpecialGroup(itemNode) {
            result = false // don't allow special group nodes to be renamed
        } else {
            if (itemNode.urlString as NSString?)?.absolutePath ?? false {
                result = false	// don't allow file system objects to be renamed
            }
        }
        
        return result
    }
    
    // -------------------------------------------------------------------------------
    //	outlineView:willDisplayCell:forTableColumn:item
    // -------------------------------------------------------------------------------
    func outlineView(olv: NSOutlineView, willDisplayCell cell: AnyObject, forTableColumn tableColumn: NSTableColumn?, item: AnyObject) {
        if tableColumn?.identifier == COLUMNID_NAME {
            // we are displaying the single and only column
            if cell is ImageAndTextCell {
                let node = item.representedObject as! BaseNode
                if node.isLeaf {
                    // does it have a URL string?
                    if let urlStr = node.urlString {
                        let iconImage: NSImage?
                        if urlStr.hasPrefix(HTTP_PREFIX) {
                            iconImage = urlImage
                        } else {
                            iconImage = NSWorkspace.sharedWorkspace().iconForFile(urlStr)
                        }
                        node.nodeIcon = iconImage
                    } else {
                        // it's a separator, don't bother with the icon
                    }
                } else {
                    // check if it's a special folder (PLACES or BOOKMARKS), we don't want it to have an icon
                    if self.isSpecialGroup(node) {
                        node.nodeIcon = nil
                    } else {
                        // it's a folder, use the folderImage as its icon
                        node.nodeIcon = folderImage
                    }
                }
                
                // set the cell's image
                node.nodeIcon?.size = NSMakeSize(kIconImageSize, kIconImageSize)
                let myCell = cell as! ImageAndTextCell
                myCell.myImage = node.nodeIcon
            }
        }
    }
    
    // -------------------------------------------------------------------------------
    //	outlineViewSelectionDidChange:notification
    // -------------------------------------------------------------------------------
    func outlineViewSelectionDidChange(notification: NSNotification) {
        // ask the tree controller for the current selection
        let selection = treeController.selectedObjects
        if selection.count > 1 {
            // multiple selection - clear the right side view
            self.removeSubview()
            currentView = nil
        } else {
            if selection.count == 1 {
                // single selection
                self.changeItemView()
            } else {
                // there is no current selection - no view to display
                self.removeSubview()
                currentView = nil
            }
        }
    }
    
    // ----------------------------------------------------------------------------------------
    // outlineView:isGroupItem:item
    // ----------------------------------------------------------------------------------------
    func outlineView(outlineView: NSOutlineView, isGroupItem item: AnyObject) -> Bool {
        let result = self.isSpecialGroup(item.representedObject as! BaseNode)
        return result
    }
    
    
    //MARK: - NSOutlineView drag and drop
    
    // ----------------------------------------------------------------------------------------
    // outlineView:writeItems:toPasteboard
    // ----------------------------------------------------------------------------------------
    func outlineView(ov: NSOutlineView, writeItems items: [AnyObject], toPasetBoard pboard: NSPasteboard) -> Bool {
        pboard.declareTypes([kNodesPBoardType], owner: self)
        
        // keep track of this nodes for drag feedback in "validateDrop"
        self.dragNodesArray = items as! [NSTreeNode]
        
        return true
    }
    
    // -------------------------------------------------------------------------------
    //	outlineView:validateDrop:proposedItem:proposedChildrenIndex:
    //
    //	This method is used by NSOutlineView to determine a valid drop target.
    // -------------------------------------------------------------------------------
    func outlineView(ov: NSOutlineView,
        validateDrop info: NSDraggingInfo,
        proposedItem item: AnyObject?,
        proposedChildIndex index: Int) -> NSDragOperation
    {
        var result = NSDragOperation.None
        
        if item == nil {
            // no item to drop on
        } else {
            if self.isSpecialGroup(item!.representedObject as! BaseNode) {
                // don't allow dragging into special grouped sections (i.e. Places and Bookmarks)
            } else {
                if index == -1 {
                    // don't allow dropping on a child
                    result = .None
                } else {
                    // drop location is a container
                    result = .Move
                    
                    let dropLocation = item!.representedObject as! BaseNode  // item we are dropping on
                    let draggedItem = self.dragNodesArray[0].representedObject as! BaseNode
                    
                    // don't allow an item to drop onto itself, or within it's content
                    if dropLocation === draggedItem ||
                        dropLocation.isDescendantOfNodes([draggedItem]) {
                            result = .None
                    }
                }
            }
        }
        
        return result
    }
    
    // -------------------------------------------------------------------------------
    //	handleWebURLDrops:pboard:withIndexPath:
    //
    //	The user is dragging URLs from Safari.
    // -------------------------------------------------------------------------------
    private func handleWebURLDrops(pboard: NSPasteboard, withIndexPath indexPath: NSIndexPath) {
        let pbArray = pboard.propertyListForType("WebURLsWithTitlesPboardType") as! [AnyObject]
        let urlArray = pbArray[0] as! [String]
        let nameArray = pbArray[1] as! [String]
        
        for i in lazy(0..<urlArray.count).reverse() {
            let node = ChildNode()
            
            node.isLeaf = true
            
            node.nodeTitle = nameArray[i]
            
            node.urlString = urlArray[i]
            treeController.insertObject(node, atArrangedObjectIndexPath: indexPath)
        }
    }
    
    // -------------------------------------------------------------------------------
    //	handleInternalDrops:pboard:withIndexPath:
    //
    //	The user is doing an intra-app drag within the outline view.
    // -------------------------------------------------------------------------------
    private func handleInternalDrops(pboard: NSPasteboard, withIndexPath indexPath: NSIndexPath) {
        // user is doing an intra app drag within the outline view:
        //
        let newNodes = self.dragNodesArray
        
        // move the items to their new place (we do this backwards, otherwise they will end up in reverse order)
        for idx in lazy(0..<newNodes.count).reverse() {
            treeController.moveNode(newNodes[idx], toIndexPath: indexPath)
        }
        
        // keep the moved nodes selected
        var indexPathList: [NSIndexPath] = []
        for i in 0..<newNodes.count {
            indexPathList.append(newNodes[i].indexPath)
        }
        treeController.setSelectionIndexPaths(indexPathList)
    }
    
    // -------------------------------------------------------------------------------
    //	handleFileBasedDrops:pboard:withIndexPath:
    //
    //	The user is dragging file-system based objects (probably from Finder)
    // -------------------------------------------------------------------------------
    private func handleFileBasedDrops(pboard: NSPasteboard, withIndexPath indexPath: NSIndexPath) {
        let fileNames = pboard.propertyListForType(NSFilenamesPboardType) as! [String]
        if !fileNames.isEmpty {
            let count = fileNames.count
            
            for i in lazy(0..<count - 1).reverse() {
                let node = ChildNode()
                
                let url = NSURL(fileURLWithPath: fileNames[i])
                let name = NSFileManager.defaultManager().displayNameAtPath(url.path!)
                node.isLeaf = true
                
                node.nodeTitle = name
                node.urlString = url.path!
                
                treeController.insertObject(node, atArrangedObjectIndexPath: indexPath)
            }
        }
    }
    
    // -------------------------------------------------------------------------------
    //	handleURLBasedDrops:pboard:withIndexPath:
    //
    //	Handle dropping a raw URL.
    // -------------------------------------------------------------------------------
    private func handleURLBasedDrops(pboard: NSPasteboard, withIndexPath indexPath: NSIndexPath) {
        if let url = NSURL(fromPasteboard: pboard) {
            let node = ChildNode()
            
            if url.fileURL {
                // url is file-based, use it's display name
                let name = NSFileManager.defaultManager().displayNameAtPath(url.path!)
                node.nodeTitle = name
                node.urlString = url.path!
            } else {
                // url is non-file based (probably from Safari)
                //
                // the url might not end with a valid component name, use the best possible title from the URL
                if url.path!.pathComponents.count == 1 {
                    if url.absoluteString.hasPrefix(HTTP_PREFIX) ?? false {
                        // use the url portion without the prefix
                        let prefixRange = url.absoluteString.rangeOfString(HTTP_PREFIX)!
                        let newRange = prefixRange.endIndex..<url.absoluteString.endIndex
                       node.nodeTitle = url.absoluteString[newRange]
                    } else {
                        // prefix unknown, just use the url as its title
                        node.nodeTitle = url.absoluteString
                    }
                } else {
                    // use the last portion of the URL as its title
                    node.nodeTitle = url.path!.lastPathComponent
                }
                
                node.urlString = url.absoluteString
            }
            node.isLeaf = true
            
            treeController.insertObject(node, atArrangedObjectIndexPath: indexPath)
        }
    }
    
    // -------------------------------------------------------------------------------
    //	outlineView:acceptDrop:item:childIndex
    //
    //	This method is called when the mouse is released over an outline view that previously decided to allow a drop
    //	via the validateDrop method. The data source should incorporate the data from the dragging pasteboard at this time.
    //	'index' is the location to insert the data as a child of 'item', and are the values previously set in the validateDrop: method.
    //
    // -------------------------------------------------------------------------------
    func outlineView(ov: NSOutlineView, acceptDrop info: NSDraggingInfo, item targetItem: AnyObject?, childIndex index: Int) -> Bool {
        // note that "targetItem" is a NSTreeNode proxy
        //
        var result = false
        
        // find the index path to insert our dropped object(s)
        let indexPath: NSIndexPath
        if let itemNode = targetItem as! NSTreeNode? {
            // drop down inside the tree node:
            // feth the index path to insert our dropped node
            indexPath = itemNode.indexPath.indexPathByAddingIndex(index)
        } else {
            // drop at the top root level
            if index == -1 {	// drop area might be ambibuous (not at a particular location)
                indexPath = NSIndexPath(index: self.contents.count) // drop at the end of the top level
            } else {
                indexPath = NSIndexPath(index: index) // drop at a particular place at the top level
            }
        }
        
        let pboard = info.draggingPasteboard()	// get the pasteboard
        
        // check the dragging type -
        if pboard.availableTypeFromArray([kNodesPBoardType]) != nil {
            // user is doing an intra-app drag within the outline view
            self.handleInternalDrops(pboard, withIndexPath: indexPath)
            result = true
        } else if pboard.availableTypeFromArray(["WebURLsWithTitlesPboardType"]) != nil {
            // the user is dragging URLs from Safari
            self.handleWebURLDrops(pboard, withIndexPath: indexPath)
            result = true
        } else if pboard.availableTypeFromArray([NSFilenamesPboardType]) != nil {
            // the user is dragging file-system based objects (probably from Finder)
            self.handleFileBasedDrops(pboard, withIndexPath: indexPath)
            result = true
        } else if pboard.availableTypeFromArray([NSURLPboardType]) != nil {
            // handle dropping a raw URL
            self.handleURLBasedDrops(pboard, withIndexPath: indexPath)
            result = true
        }
        
        return result
    }
    
    
    //MARK: - NSSplitViewDelegate
    
    // -------------------------------------------------------------------------------
    //	splitView:constrainMinCoordinate:
    //
    //	What you really have to do to set the minimum size of both subviews to kMinOutlineViewSplit points.
    // -------------------------------------------------------------------------------
    func splitView(splitView: NSSplitView, constrainMinCoordinate proposedCoordinate: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        return proposedCoordinate + kMinOutlineViewSplit
    }
    
    // -------------------------------------------------------------------------------
    //	splitView:constrainMaxCoordinate:
    // -------------------------------------------------------------------------------
    func splitView(splitView: NSSplitView, constrainMaxCoordinate proposedCoordinate: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        return proposedCoordinate - kMinOutlineViewSplit
    }
    
    // -------------------------------------------------------------------------------
    //	splitView:resizeSubviewsWithOldSize:
    //
    //	Keep the left split pane from resizing as the user moves the divider line.
    // -------------------------------------------------------------------------------
    func splitView(sender: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        let newFrame = sender.frame // get the new size of the whole splitView
        let left = sender.subviews[0] as NSView
        var leftFrame = left.frame
        let right = sender.subviews[1] as NSView
        var rightFrame = right.frame
        
        let dividerThickness = sender.dividerThickness
        
        leftFrame.size.height = newFrame.size.height
        
        rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dividerThickness
        rightFrame.size.height = newFrame.size.height
        rightFrame.origin.x = leftFrame.size.width + dividerThickness
        
        left.frame = leftFrame
        right.frame = rightFrame
    }
    
}