//
//  MyOutlineViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/24.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 The master view controller containing the NSOutlineView and NSTreeController
 */
import Cocoa
import WebKit

private let INITIAL_INFODICT		= "Outline"		// name of the dictionary file to populate our outline view

private let ICONVIEW_IDENTIFIER		= "IconViewController"   // storyboard identifier for the icon view
private let FILEVIEW_IDENTIFIER		= "FileViewController"   // storyboard identifier for the file view
private let WEBVIEW_IDENTIFIER		= "WebViewController"    // storyboard identifier for the web view

private let CHILDEDIT_IDENTIFIER	= "ChildEditWindowController"	// storyboard identifier the child edit window controller

private let UNTITLED_NAME			= "Untitled"		// default name for added folders and leafs

private let HTTP_PREFIX				= "http://"

// default folder titles
private let PLACES_NAME				= "PLACES"
private let BOOKMARKS_NAME			= "BOOKMARKS"

// keys in our disk-based dictionary representing our outline view's data
private let KEY_NAME				= "name"
private let KEY_URL					= "url"
private let KEY_SEPARATOR			= "separator"
private let KEY_GROUP				= "group"
private let  KEY_FOLDER				= "folder"
private let KEY_ENTRIES				= "entries"

private let kIconImageSize: CGFloat          = 16.0

private let kNodesPBoardType		= "myNodesPBoardType"	// drag and drop pasteboard type


//MARK: -

// -------------------------------------------------------------------------------
//	TreeAdditionObj
//
//	This object is used for passing data between the main and secondary thread
//	which populates the outline view.
// -------------------------------------------------------------------------------
@objc(TreeAdditionObj)
class TreeAdditionObj: NSObject {
    
    //private(set) weak var indexPath: NSIndexPath?
    private(set) var nodeURL: String?
    private(set) var nodeName: String?
    private(set) var selectItsParent: Bool
    
    
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

@objc(MyOutlineViewController)
class MyOutlineViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    @IBOutlet var treeController: NSTreeController!
    
    @IBOutlet private weak var myOutlineView: NSOutlineView!
    @IBOutlet private weak var placeHolderView: NSView!
    
    // cached images for generic folder and url document
    private var folderImage: NSImage!
    private var urlImage: NSImage!
    
    private var dragNodesArray: [NSTreeNode]?
    dynamic var contents: [AnyObject] = []
    
    private var iconViewController: IconViewController!
    private var fileViewController: FileViewController!
    private var webViewController: WebViewController!
    
    private var childEditWindowController: NSWindowController!
    
    
    //MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // load the icon view controller for later use
        iconViewController = self.storyboard!.instantiateControllerWithIdentifier(ICONVIEW_IDENTIFIER) as! IconViewController
        self.iconViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // load the file view controller for later use
        fileViewController = self.storyboard!.instantiateControllerWithIdentifier(FILEVIEW_IDENTIFIER) as! FileViewController
        self.fileViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // load the web view controller for later use
        webViewController = self.storyboard!.instantiateControllerWithIdentifier(WEBVIEW_IDENTIFIER) as! WebViewController
        self.webViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // load the child edit view controller for later use
        childEditWindowController = self.storyboard!.instantiateControllerWithIdentifier(CHILDEDIT_IDENTIFIER) as! NSWindowController
        
        // cache the reused icon images
        folderImage = NSWorkspace.sharedWorkspace().iconForFileType(NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
        self.folderImage.size = NSMakeSize(kIconImageSize, kIconImageSize)
        
        urlImage = NSWorkspace.sharedWorkspace().iconForFileType(NSFileTypeForHFSTypeCode(OSType(kGenericURLIcon)))
        self.urlImage.size = NSMakeSize(kIconImageSize, kIconImageSize)
        
        self.populateOutlineContents()
        
        // scroll to the top in case the outline contents is very long
        self.myOutlineView.enclosingScrollView?.verticalScroller?.floatValue = 0.0
        self.myOutlineView.enclosingScrollView?.contentView.scrollToPoint(NSMakePoint(0,0))
        
        // make our outline view appear with gradient selection, and behave like the Finder, iTunes, etc.
        self.myOutlineView.selectionHighlightStyle = .SourceList
        
        // drag and drop support
        self.myOutlineView.registerForDraggedTypes([kNodesPBoardType,			// our internal drag type
            NSURLPboardType,			// single url from pasteboard
            NSFilenamesPboardType,		// from Safari or Finder
            NSFilesPromisePboardType])
        
        // notification to add a folder
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "addFolder:",
            name: kAddFolderNotification,
            object: nil)
        // notification to remove a folder
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "removeFolder:",
            name: kRemoveFolderNotification,
            object: nil)
        
        // notification to add a bookmark
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "addBookmark:",
            name: kAddBookmarkNotification,
            object: nil)
        
        // notification to edit a bookmark
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "editBookmark:",
            name: kEditBookmarkNotification,
            object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	dealloc
    // -------------------------------------------------------------------------------
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kAddFolderNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kRemoveFolderNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kAddBookmarkNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kEditBookmarkNotification, object: nil)
    }
    
    
    //MARK: - Actions
    
    // -------------------------------------------------------------------------------
    //	selectParentFromSelection
    //
    //	Take the currently selected node and select its parent.
    // -------------------------------------------------------------------------------
    private func selectParentFromSelection() {
        if !self.treeController.selectedNodes.isEmpty {
            let firstSelectedNode = self.treeController.selectedNodes[0]
            if let parentNode = firstSelectedNode.parentNode {
                // select the parent
                let parentIndex = parentNode.indexPath
                self.treeController.setSelectionIndexPath(parentIndex)
            } else {
                // no parent exists (we are at the top of tree), so make no selection in our outline
                let selectionIndexPaths = self.treeController.selectionIndexPaths
                self.treeController.removeSelectionIndexPaths(selectionIndexPaths)
            }
        }
    }
    
    // -------------------------------------------------------------------------------
    //	performAddFolder:treeAddition
    // -------------------------------------------------------------------------------
    private func performAddFolder(treeAddition: TreeAdditionObj) {
        // NSTreeController inserts objects using NSIndexPath, so we need to calculate this
        var indexPath: NSIndexPath
        
        // if there is no selection, we will add a new group to the end of the contents array
        if self.treeController.selectedObjects.isEmpty {
            // there's no selection so add the folder to the top-level and at the end
            indexPath = NSIndexPath(index: self.contents.count)
        } else {
            // get the index of the currently selected node, then add the number its children to the path -
            // this will give us an index which will allow us to add a node to the end of the currently selected node's children array.
            //
            indexPath = self.treeController.selectionIndexPath!
            if (self.treeController.selectedObjects[0] as! BaseNode).isLeaf {
                // user is trying to add a folder on a selected child,
                // so deselect child and select its parent for addition
                self.selectParentFromSelection()
            } else {
                indexPath = indexPath.indexPathByAddingIndex((self.treeController.selectedObjects[0] as! BaseNode).children.count)
            }
        }
        
        let node = ChildNode()
        node.nodeTitle = treeAddition.nodeName ?? ""
        
        // the user is adding a child node, tell the controller directly
        self.treeController.insertObject(node, atArrangedObjectIndexPath: indexPath)
    }
    
    // -------------------------------------------------------------------------------
    //	performAddChild:treeAddition
    // -------------------------------------------------------------------------------
    private func performAddChild(treeAddition: TreeAdditionObj) {
        if !self.treeController.selectedObjects.isEmpty {
            // we have a selection
            if (self.treeController.selectedObjects[0] as! BaseNode).isLeaf {
                // trying to add a child to a selected leaf node, so select its parent for add
                self.selectParentFromSelection()
            }
        }
        
        // find the selection to insert our node
        var indexPath: NSIndexPath
        if !self.treeController.selectedObjects.isEmpty {
            // we have a selection, insert at the end of the selection
            indexPath = self.treeController.selectionIndexPath!
            indexPath = indexPath.indexPathByAddingIndex((self.treeController.selectedObjects[0] as! BaseNode).children.count)
        } else {
            // no selection, just add the child to the end of the tree
            indexPath = NSIndexPath(index: self.contents.count)
        }
        
        // create a leaf node
        let node = ChildNode(leaf: ())
        node.urlString = treeAddition.nodeURL
        
        if let url = treeAddition.nodeURL {
            if !url.isEmpty {
                // the child to insert has a valid URL, use its display name as the node title
                if let name = treeAddition.nodeName {
                    node.nodeTitle = name
                } else {
                    node.nodeTitle = NSFileManager.defaultManager().displayNameAtPath(url)
                }
            } else {
                // the child to insert will be an empty URL
                node.nodeTitle = UNTITLED_NAME
                node.urlString = HTTP_PREFIX
            }
        }
        
        // the user is adding a child node, tell the controller directly
        self.treeController.insertObject(node, atArrangedObjectIndexPath: indexPath)
        
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
    //	addEntries:discloseParent:
    // -------------------------------------------------------------------------------
    private func addEntries(entries: [NSDictionary], discloseParent: Bool) {
        for entry in entries {
            let urlStr = entry[KEY_URL] as? String
            
            if entry[KEY_SEPARATOR] != nil {
                // its a separator mark, we treat is as a leaf
                self.addChild(nil, withName: nil, selectParent: true)
            } else if entry[KEY_FOLDER] != nil {
                // we treat file system folders as a leaf and show its contents in the NSCollectionView
                let folderName = entry[KEY_FOLDER] as! String
                self.addChild(urlStr, withName: folderName, selectParent: true)
            } else if entry[KEY_URL] != nil {
                // its a leaf item with a URL
                let nameStr = entry[KEY_NAME] as! String
                self.addChild(urlStr, withName: nameStr, selectParent: true)
            } else {
                // it's a generic container
                let folderName = entry[KEY_GROUP] as! String
                self.addFolderWithName(folderName)
                
                // add its children
                let newChildren = entry[KEY_ENTRIES] as! [NSDictionary]
                self.addEntries(newChildren, discloseParent: false)
                
                self.selectParentFromSelection()
            }
        }
        
        if !discloseParent {
            // inserting children automatically expands its parent, we want to close it
            if !self.treeController.selectedNodes.isEmpty {
                let lastSelectedNode = self.treeController.selectedNodes[0]
                self.myOutlineView.collapseItem(lastSelectedNode)
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
        self.addFolderWithName(BOOKMARKS_NAME)
        
        let initData = NSDictionary(contentsOfURL:
            NSBundle.mainBundle().URLForResource(INITIAL_INFODICT, withExtension: "dict")!)!
        let entries = initData[KEY_ENTRIES] as! [NSDictionary] //###
        self.addEntries(entries, discloseParent: true)
        
        self.selectParentFromSelection()
    }
    
    // -------------------------------------------------------------------------------
    //	addPlacesSection
    // -------------------------------------------------------------------------------
    private func addPlacesSection() {
        // add the "Places" section
        self.addFolderWithName(PLACES_NAME)
        
        // add its children
        self.addChild(NSHomeDirectory(), withName: "Home", selectParent: true)
        
        let appsURLs = NSFileManager.defaultManager().URLsForDirectory(.ApplicationDirectory, inDomains: .LocalDomainMask)
        self.addChild(appsURLs[0].path, withName: nil, selectParent: true)
        
        self.selectParentFromSelection()
    }
    
    // -------------------------------------------------------------------------------
    //	populateOutlineContents
    // -------------------------------------------------------------------------------
    private func populateOutlineContents() {
        // hide the outline view - don't show it as we are building the content
        self.myOutlineView.hidden = true
        
        self.addPlacesSection()		// add the "Places" outline section
        self.populateOutline()			// add the "Bookmark" outline content
        
        // remove the current selection
        let selection = self.treeController.selectionIndexPaths
        self.treeController.removeSelectionIndexPaths(selection)
        
        self.myOutlineView.hidden = false	// we are done populating the outline view content, show it again
    }
    
    // -------------------------------------------------------------------------------
    //	textFieldAction:sender
    // -------------------------------------------------------------------------------
    @IBAction func textFieldAction(textField: NSTextField) {
        // user was done editing an item, assign the new text value to it's represented object
        let selectedRow = self.myOutlineView.selectedRow
        let node = self.myOutlineView.itemAtRow(selectedRow)!.representedObject as! BaseNode
        node.nodeTitle = textField.stringValue
    }
    
    
    //MARK: - Node checks
    
    // -------------------------------------------------------------------------------
    //	isSeparator:node
    // -------------------------------------------------------------------------------
    private func isSeparator(node: BaseNode) -> Bool {
        return (node.nodeIcon == nil && node.nodeTitle.isEmpty)
    }
    
    // -------------------------------------------------------------------------------
    //	isSpecialGroup:groupNode
    // -------------------------------------------------------------------------------
    private func isSpecialGroup(groupNode: BaseNode) -> Bool {
        return (groupNode.nodeIcon == nil &&
            (groupNode.nodeTitle == BOOKMARKS_NAME || groupNode.nodeTitle == PLACES_NAME))
    }
    
    
    //MARK: - Notifications
    
    // -------------------------------------------------------------------------------
    //	addFolder:folderName
    // -------------------------------------------------------------------------------
    private func addFolderWithName(folderName: String) {
        let treeObjInfo = TreeAdditionObj(URL: nil, withName: folderName, selectItsParent: false)
        self.performAddFolder(treeObjInfo)
    }
    
    // -------------------------------------------------------------------------------
    //  addFolder:notif
    //
    //  Notification sent from PrimaryViewController class, to add a folder.
    // -------------------------------------------------------------------------------
    @objc func addFolder(notif: NSNotification) {
        self.addFolderWithName(UNTITLED_NAME)
    }
    
    // -------------------------------------------------------------------------------
    //  removeFolder:notif
    //
    //  Notification sent from PrimaryViewController class, to add a folder.
    // -------------------------------------------------------------------------------
    @objc func removeFolder(notif: NSNotification) {
        self.treeController.remove(self)
    }
    
    // -------------------------------------------------------------------------------
    //  addBookmark:notif
    //
    //  Notification sent from PrimaryViewController class, to add a bookmark
    // -------------------------------------------------------------------------------
    @objc func addBookmark(notif: NSNotification) {
        self.view.window?.beginSheet(self.childEditWindowController.window!) {returnCode in
            if returnCode == NSModalResponseOK {
                let childEditViewController = self.childEditWindowController.contentViewController as! ChildEditViewController
                
                let name: String
                if let itemStr = childEditViewController.savedValues[kName_Key] where !itemStr.isEmpty {
                    name = itemStr
                } else {
                    name = UNTITLED_NAME
                }
                self.addChild(childEditViewController.savedValues[kURL_Key],
                    withName: name,
                    selectParent: false)	// add empty untitled child
            }
        }
    }
    
    // -------------------------------------------------------------------------------
    //  editBookmark:notif
    //
    //  Notification sent from PrimaryViewController class, to edit a bookmark
    // -------------------------------------------------------------------------------
    @objc func editBookmark(notif: NSNotification) {
        let childEditViewController = self.childEditWindowController.contentViewController as! ChildEditViewController
        
        // get the selected item's name and url
        let selection = self.treeController.selectedObjects
        let node = selection[0] as! ChildNode
        
        if node.urlString == nil || node.urlString!.isEmpty || !node.isBookmark {
            // it's a folder or a file-system based object, just allow editing the cell title
            let selectedRow = self.myOutlineView.selectedRow
            self.myOutlineView.editColumn(0, row: selectedRow, withEvent: NSApp.currentEvent, select: true)
        } else {
            childEditViewController.savedValues = [kName_Key : node.nodeTitle, kURL_Key : node.urlString!]
            self.view.window?.beginSheet(self.childEditWindowController.window!) {returnCode in
                if returnCode == NSModalResponseOK {
                    // create a child node
                    let childNode = ChildNode(leaf: ())
                    childNode.urlString = childEditViewController.savedValues[kURL_Key]
                    if let newNodeStr = childEditViewController.savedValues[kName_Key]
                        where !newNodeStr.isEmpty {
                            childNode.nodeTitle = newNodeStr
                    } else {
                        childNode.nodeTitle = UNTITLED_NAME
                    }
                    
                    // remove the current selection and replace it with the newly edited child
                    let indexPath = self.treeController.selectionIndexPath!
                    self.treeController.remove(self)
                    self.treeController.insertObject(childNode, atArrangedObjectIndexPath: indexPath)
                }
            }
        }
    }
    
    
    //MARK: - Managing Views
    
    // -------------------------------------------------------------------------------
    //  viewControllerForSelection:selection
    // -------------------------------------------------------------------------------
    func viewControllerForSelection(selection: [NSTreeNode]?) -> NSViewController? {
        var returnViewController: NSViewController? = nil
        
        if let selection = selection where selection.count == 1 {
            let node = selection[0].representedObject as! BaseNode
            if let urlStr = node.urlString {
                if node.isBookmark {
                    // it's a bookmark,
                    // return a view controller with a web view, retarget with "urlStr"
                    let webView = self.webViewController.view as! WebView
                    webView.mainFrameURL = urlStr;	// re-target to the new url
                    returnViewController = self.webViewController
                    
                    self.webViewController.retargetWebView = true
                } else {
                    let url = NSURL(fileURLWithPath: urlStr)
                    
                    // detect if the url is a directory
                    if node.isDirectory {
                        // it's a folder
                        self.iconViewController.url = url
                        returnViewController = self.iconViewController
                    } else {
                        // it's a file
                        self.fileViewController.url = url
                        returnViewController = self.fileViewController
                    }
                }
            } else {
                // no view controller (it's a group)
            }
        } else {
            // no view controller (no selection)
        }
        
        return returnViewController
    }
    
    
    //MARK: - NSOutlineViewDelegate
    
    // -------------------------------------------------------------------------------
    //	shouldSelectItem:item
    // -------------------------------------------------------------------------------
    func outlineView(outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
        // don't allow special group nodes (Places and Bookmarks) to be selected
        let node = (item as! NSTreeNode).representedObject as! BaseNode
        return !isSpecialGroup(node) && !isSeparator(node)
    }
    
    // -------------------------------------------------------------------------------
    //	viewForTableColumn:tableColumn:item
    // -------------------------------------------------------------------------------
    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        var result = outlineView.makeViewWithIdentifier(tableColumn?.identifier ?? "", owner: self)
        
        if let node = (item as! NSTreeNode).representedObject as? BaseNode {
            if self.outlineView(outlineView, isGroupItem: item) {
                let identifier = outlineView.tableColumns[0].identifier
                result = outlineView.makeViewWithIdentifier(identifier, owner: self)
                let value = node.nodeTitle.uppercaseString
                (result as? NSTableCellView)?.textField?.stringValue = value
            } else if isSeparator(node) {
                // separators have no title or icon, just use the custom view to draw it
                result = outlineView.makeViewWithIdentifier("Separator", owner: self)
            } else {
                (result as? NSTableCellView)?.textField?.stringValue = node.nodeTitle
                
                if node.isLeaf {
                    // does it have a URL string?
                    if let urlStr = node.urlString {
                        var iconImage: NSImage
                        if node.isBookmark {
                            iconImage = self.urlImage
                        } else {
                            iconImage = NSWorkspace.sharedWorkspace().iconForFile(urlStr)
                        }
                        node.nodeIcon = iconImage
                        
                        (result as? NSTableCellView)?.textField?.editable = true
                    } else {
                        // it's a separator, don't bother with the icon
                    }
                } else {
                    // it's a folder, use the folderImage as its icon
                    node.nodeIcon = self.folderImage
                }
                
                // set the cell's image
                node.nodeIcon!.size = NSMakeSize(kIconImageSize, kIconImageSize)
                (result as? NSTableCellView)?.imageView?.image = node.nodeIcon
            }
        }
        
        return result
    }
    
    // -------------------------------------------------------------------------------
    //	textShouldEndEditing:fieldEditor
    // -------------------------------------------------------------------------------
    func control(control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        // don't allow empty node names
        return !(fieldEditor.string?.isEmpty ?? true)
    }
    
    // ----------------------------------------------------------------------------------------
    // outlineView:isGroupItem:item
    // ----------------------------------------------------------------------------------------
    func outlineView(outlineView: NSOutlineView, isGroupItem item: AnyObject) -> Bool {
        return isSpecialGroup((item as! NSTreeNode).representedObject as! BaseNode)
    }
    
    
    //MARK: - NSOutlineView drag and drop
    
    // ----------------------------------------------------------------------------------------
    // outlineView:writeItems:toPasteboard
    // ----------------------------------------------------------------------------------------
    func outlineView(ov: NSOutlineView, writeItems items: [AnyObject], toPasteboard pboard: NSPasteboard) -> Bool {
        pboard.declareTypes([kNodesPBoardType], owner: self)
        
        // keep track of this nodes for drag feedback in "validateDrop"
        self.dragNodesArray = items as? [NSTreeNode]
        
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
            result = .Generic
        } else {
            if isSpecialGroup((item as! NSTreeNode).representedObject as! BaseNode) {
                // don't allow dragging into special grouped sections (i.e. Places and Bookmarks)
                result = .None
            } else {
                if index == -1 {
                    // don't allow dropping on a child
                    result = .None
                } else {
                    // drop location is a container
                    result = .Move
                    
                    let dropLocation = (item as! NSTreeNode).representedObject as! BaseNode  // item we are dropping on
                    let draggedItem = self.dragNodesArray![0].representedObject as! BaseNode
                    
                    // don't allow an item to drop onto itself, or within it's content
                    if dropLocation === draggedItem ||
                        dropLocation.isDescendantOfNodes([draggedItem])
                    {
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
        let pbArray = pboard.propertyListForType("WebURLsWithTitlesPboardType") as! [[String]]
        let urlArray = pbArray[0]
        let nameArray = pbArray[1]
        
        for i in (0..<urlArray.count).reverse() {
            let node = ChildNode()
            
            node.isLeaf = true
            
            node.nodeTitle = nameArray[i]
            
            node.urlString = urlArray[i]
            self.treeController.insertObject(node, atArrangedObjectIndexPath: indexPath)
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
        let newNodes = self.dragNodesArray!
        
        // move the items to their new place (we do this backwards, otherwise they will end up in reverse order)
        for idx in (0..<newNodes.count).reverse() {
            self.treeController.moveNode(newNodes[idx], toIndexPath: indexPath)
        }
        
        // keep the moved nodes selected
        var indexPathList: [NSIndexPath] = []
        for node in newNodes {
            indexPathList.append(node.indexPath)
        }
        self.treeController.setSelectionIndexPaths(indexPathList)
    }
    
    // -------------------------------------------------------------------------------
    //	handleFileBasedDrops:pboard:withIndexPath:
    //
    //	The user is dragging file-system based objects (probably from Finder)
    // -------------------------------------------------------------------------------
    private func handleFileBasedDrops(pboard: NSPasteboard, withIndexPath indexPath: NSIndexPath) {
        guard let fileNames = pboard.propertyListForType(NSFilenamesPboardType) as? [String]
            where !fileNames.isEmpty else {return}
        
        for fileName in fileNames.lazy.reverse() {
            let node = ChildNode()
            
            let url = NSURL(fileURLWithPath: fileName)
            let name = NSFileManager.defaultManager().displayNameAtPath(url.path!)
            node.isLeaf = true
            
            node.nodeTitle = name
            node.urlString = url.path
            
            self.treeController.insertObject(node, atArrangedObjectIndexPath: indexPath)
        }
    }
    
    // -------------------------------------------------------------------------------
    //	handleURLBasedDrops:pboard:withIndexPath:
    //
    //	Handle dropping a raw URL.
    // -------------------------------------------------------------------------------
    private func handleURLBasedDrops(pboard: NSPasteboard, withIndexPath indexPath: NSIndexPath) {
        guard let url = NSURL(fromPasteboard: pboard) else {return}
        let node = ChildNode()
        
        if url.fileURL {
            // url is file-based, use it's display name
            let name = NSFileManager.defaultManager().displayNameAtPath(url.path!)
            node.nodeTitle = name
            node.urlString = url.path
        } else {
            // url is non-file based (probably from Safari)
            //
            // the url might not end with a valid component name, use the best possible title from the URL
            if url.pathComponents?.count == 1 {
                if node.isBookmark {
                    // use the url portion without the prefix
                    let prefixRange = url.absoluteString.rangeOfString(HTTP_PREFIX)!
                    let newRange = prefixRange.endIndex..<url.absoluteString.endIndex.predecessor()
                    node.nodeTitle = url.absoluteString.substringWithRange(newRange)
                } else {
                    // prefix unknown, just use the url as its title
                    node.nodeTitle = url.absoluteString
                }
            } else {
                // use the last portion of the URL as its title
                node.nodeTitle = url.lastPathComponent!
            }
            
            node.urlString = url.absoluteString
        }
        node.isLeaf = true
        
        self.treeController.insertObject(node, atArrangedObjectIndexPath: indexPath)
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
        if targetItem != nil {
            // drop down inside the tree node:
            // feth the index path to insert our dropped node
            indexPath = targetItem!.indexPath!!.indexPathByAddingIndex(index)
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
    
}