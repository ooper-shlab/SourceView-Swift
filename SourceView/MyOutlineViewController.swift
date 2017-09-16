//
//  MyOutlineViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/24.
//
//
/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 The master view controller containing the NSOutlineView and NSTreeController.
 */
import Cocoa
import WebKit

private let INITIAL_INFODICT		= "Outline"		// name of the dictionary file to populate our outline view

private let ICONVIEW_IDENTIFIER		= "IconViewController"   // storyboard identifier for the icon view
private let FILEVIEW_IDENTIFIER		= "FileViewController"   // storyboard identifier for the file view
private let WEBVIEW_IDENTIFIER		= "WebViewController"    // storyboard identifier for the web view

private let CHILDEDIT_IDENTIFIER	= "ChildEditWindowController"	// storyboard identifier the child edit window controller

private let SEPARATOR_VIEW = "Separator"

// keys in our disk-based dictionary representing our outline view's data
private let KEY_NAME				= "name"
private let KEY_URL				= "url"
private let KEY_SEPARATOR			= "separator"
private let KEY_GROUP				= "group"
private let  KEY_FOLDER				= "folder"
private let KEY_ENTRIES				= "entries"

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
    private(set) var nodeURL: URL?
    private(set) var nodeName: String?
    private(set) var selectItsParent: Bool
    
    
    //MARK: -
    
    // -------------------------------------------------------------------------------
    //  initWithURL:url:name:select
    // -------------------------------------------------------------------------------
    init(URL url: URL?, withName name: String?, selectItsParent select: Bool) {
        
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
        iconViewController = self.storyboard!.instantiateController(withIdentifier: ICONVIEW_IDENTIFIER) as! IconViewController
        self.iconViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // load the file view controller for later use
        fileViewController = self.storyboard!.instantiateController(withIdentifier: FILEVIEW_IDENTIFIER) as! FileViewController
        self.fileViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // load the web view controller for later use
        webViewController = self.storyboard!.instantiateController(withIdentifier: WEBVIEW_IDENTIFIER) as! WebViewController
        self.webViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // load the child edit view controller for later use
        childEditWindowController = self.storyboard!.instantiateController(withIdentifier: CHILDEDIT_IDENTIFIER) as! NSWindowController
        
        self.populateOutlineContents()
        
        // scroll to the top in case the outline contents is very long
        self.myOutlineView.enclosingScrollView?.verticalScroller?.floatValue = 0.0
        self.myOutlineView.enclosingScrollView?.contentView.scroll(to: NSMakePoint(0,0))
        
        // make our outline view appear with gradient selection, and behave like the Finder, iTunes, etc.
        self.myOutlineView.selectionHighlightStyle = .sourceList
        
        // drag and drop support
        self.myOutlineView.register(forDraggedTypes: [kNodesPBoardType,		// our internal drag type
            NSURLPboardType,			// single url from pasteboard
            NSFilenamesPboardType,		// from Safari or Finder
            NSFilesPromisePboardType])
        
        // notification to add a folder
        NotificationCenter.default.addObserver(self,
            selector: #selector(self.addFolder(_:)),
            name: Notification.Name(kAddFolderNotification),
            object: nil)
        // notification to remove a folder
        NotificationCenter.default.addObserver(self,
            selector: #selector(self.removeFolder(_:)),
            name: Notification.Name(kRemoveFolderNotification),
            object: nil)
        
        // notification to add a bookmark
        NotificationCenter.default.addObserver(self,
            selector: #selector(self.addBookmark(_:)),
            name: Notification.Name(kAddBookmarkNotification),
            object: nil)
        
        // notification to edit a bookmark
        NotificationCenter.default.addObserver(self,
            selector: #selector(self.editBookmark(_:)),
            name: Notification.Name(kEditBookmarkNotification),
            object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	dealloc
    // -------------------------------------------------------------------------------
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(kAddFolderNotification), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(kRemoveFolderNotification), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(kAddBookmarkNotification), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(kEditBookmarkNotification), object: nil)
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
            if let parentNode = firstSelectedNode.parent {
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
    private func performAddFolder(_ treeAddition: TreeAdditionObj) {
        // NSTreeController inserts objects using NSIndexPath, so we need to calculate this
        var indexPath: IndexPath
        
        // if there is no selection, we will add a new group to the end of the contents array
        if self.treeController.selectedObjects.isEmpty {
            // there's no selection so add the folder to the top-level and at the end
            indexPath = IndexPath(index: self.contents.count)
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
                indexPath.append((self.treeController.selectedObjects[0] as! BaseNode).children.count)
            }
        }
        
        let node = ChildNode()
        node.nodeTitle = treeAddition.nodeName ?? ""
        
        // the user is adding a child node, tell the controller directly
        self.treeController.insert(node, atArrangedObjectIndexPath: indexPath)
    }
    
    // -------------------------------------------------------------------------------
    //	performAddChild:treeAddition
    // -------------------------------------------------------------------------------
    private func performAddChild(_ treeAddition: TreeAdditionObj) {
        if !self.treeController.selectedObjects.isEmpty {
            // we have a selection
            if (self.treeController.selectedObjects[0] as! BaseNode).isLeaf {
                // trying to add a child to a selected leaf node, so select its parent for add
                self.selectParentFromSelection()
            }
        }
        
        // find the selection to insert our node
        var indexPath: IndexPath
        if !self.treeController.selectedObjects.isEmpty {
            // we have a selection, insert at the end of the selection
            indexPath = self.treeController.selectionIndexPath!
            indexPath.append((self.treeController.selectedObjects[0] as! BaseNode).children.count)
        } else {
            // no selection, just add the child to the end of the tree
            indexPath = IndexPath(index: self.contents.count)
        }
        
        // create a leaf node
        let node = ChildNode(leaf: ())
        node.url = treeAddition.nodeURL
        
        if let url = treeAddition.nodeURL {
            // the child to insert has a valid URL, use its display name as the node title
            if let name = treeAddition.nodeName {
                node.nodeTitle = name
            } else {
                node.nodeTitle = FileManager.default.displayName(atPath: url.absoluteString)
            }
        }
        
        // the user is adding a child node, tell the controller directly
        self.treeController.insert(node, atArrangedObjectIndexPath: indexPath)
        
        // adding a child automatically becomes selected by NSOutlineView, so keep its parent selected
        if treeAddition.selectItsParent {
            self.selectParentFromSelection()
        }
    }
    
    // -------------------------------------------------------------------------------
    //	addChild:url:withName:selectParent
    // -------------------------------------------------------------------------------
    private func addChild(_ url: URL?, withName nameStr: String?, selectParent select: Bool) {
        let treeObjInfo = TreeAdditionObj(URL: url,
            withName: nameStr,
            selectItsParent: select)
        self.performAddChild(treeObjInfo)
    }
    
    // -------------------------------------------------------------------------------
    //	addEntries:discloseParent:
    // -------------------------------------------------------------------------------
    private func addEntries(_ entries: [[String: Any]], discloseParent: Bool) {
        for entry in entries {
            let urlStr = entry[KEY_URL] as? String
            let url = urlStr.flatMap{URL(string: $0)}
            if entry[KEY_SEPARATOR] != nil {
                // its a separator mark, we treat is as a leaf
                self.addChild(nil, withName: nil, selectParent: true)
            } else if entry[KEY_FOLDER] != nil {
                // we treat file system folders as a leaf and show its contents in the NSCollectionView
                let folderName = entry[KEY_FOLDER] as! String
                self.addChild(url, withName: folderName, selectParent: true)
            } else if entry[KEY_URL] != nil {
                // its a leaf item with a URL
                let nameStr = entry[KEY_NAME] as! String
                self.addChild(url, withName: nameStr, selectParent: true)
            } else {
                // it's a generic container
                let folderName = entry[KEY_GROUP] as! String
                self.addFolderWithName(folderName)
                
                // add its children
                let newChildren = entry[KEY_ENTRIES] as! [[String: Any]]
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
    //	addBookmarksSection
    //
    //	Populate the tree controller from disk-based dictionary (Outline.dict)
    // -------------------------------------------------------------------------------
    private func addBookmarksSection() {
        // add the "Bookmarks" section
        self.addFolderWithName(BaseNode.bookmarksName)
        
        // add its content (contant determined our dictionary file)
        let initData = NSDictionary(contentsOf:
            Bundle.main.url(forResource: INITIAL_INFODICT, withExtension: "dict")!)!
        let entries = initData[KEY_ENTRIES] as! [[String: Any]]
        self.addEntries(entries, discloseParent: true)
        
        self.selectParentFromSelection()
    }
    
    // -------------------------------------------------------------------------------
    //	addPlacesSection
    // -------------------------------------------------------------------------------
    private func addPlacesSection() {
        // add the "Places" section
        self.addFolderWithName(BaseNode.placesName)
        
        // add its children (contents of the Home directory)
        self.addChild(URL(fileURLWithPath: NSHomeDirectory()), withName: "Home", selectParent: true)
        
        let appsURLs = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
        self.addChild(appsURLs[0], withName: nil, selectParent: true)
        
        self.selectParentFromSelection()
    }
    
    // -------------------------------------------------------------------------------
    //	populateOutlineContents
    // -------------------------------------------------------------------------------
    private func populateOutlineContents() {
        // hide the outline view - don't show it as we are building the content
        self.myOutlineView.isHidden = true
        
        self.addPlacesSection()		// add the "Places" outline section
        self.addBookmarksSection()			// add the "Bookmark" outline content
        
        // remove the current selection
        let selection = self.treeController.selectionIndexPaths
        self.treeController.removeSelectionIndexPaths(selection)
        
        self.myOutlineView.isHidden = false	// we are done populating the outline view content, show it again
    }
    
    
    //MARK: - Notifications
    
    // -------------------------------------------------------------------------------
    //	addFolder:folderName
    // -------------------------------------------------------------------------------
    private func addFolderWithName(_ folderName: String) {
        let treeObjInfo = TreeAdditionObj(URL: nil, withName: folderName, selectItsParent: false)
        self.performAddFolder(treeObjInfo)
    }
    
    // -------------------------------------------------------------------------------
    //  addFolder:notif
    //
    //  Notification sent from PrimaryViewController class, to add a folder.
    // -------------------------------------------------------------------------------
    @objc func addFolder(_ notif: Notification) {
        self.addFolderWithName(BaseNode.untitledName)
    }
    
    // -------------------------------------------------------------------------------
    //  removeFolder:notif
    //
    //  Notification sent from PrimaryViewController class, to remove a folder.
    // -------------------------------------------------------------------------------
    @objc func removeFolder(_ notif: Notification) {
        self.treeController.remove(self)
    }
    
    // -------------------------------------------------------------------------------
    //  addBookmark:notif
    //
    //  Notification sent from PrimaryViewController class, to add a bookmark
    // -------------------------------------------------------------------------------
    @objc func addBookmark(_ notif: Notification) {
        let childEditViewController = self.childEditWindowController.contentViewController as! ChildEditViewController
        childEditViewController.savedValues = [kName_Key: BaseNode.untitledName as AnyObject, kURL_Key: HTTP_PREFIX as AnyObject]
        
        self.view.window?.beginSheet(self.childEditWindowController.window!) {returnCode in
            if returnCode == NSModalResponseOK {
                let name: String
                if let itemStr = childEditViewController.savedValues[kName_Key] as! String?, !itemStr.isEmpty {
                    name = itemStr
                } else {
                    name = BaseNode.untitledName
                }
                self.addChild(childEditViewController.savedValues[kURL_Key] as! URL?,
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
    @objc func editBookmark(_ notif: Notification) {
        let childEditViewController = self.childEditWindowController.contentViewController as! ChildEditViewController
        
        // get the selected item's name and url
        let selection = self.treeController.selectedObjects
        let node = selection[0] as! ChildNode
        
        if node.url == nil || !node.isBookmark {
            // it's a folder or a file-system based object, just allow editing the cell title
            let selectedRow = self.myOutlineView.selectedRow
            self.myOutlineView.editColumn(0, row: selectedRow, with: NSApp.currentEvent, select: true)
        } else {
            childEditViewController.savedValues = [kName_Key : node.nodeTitle as AnyObject, kURL_Key : node.url!]
            self.view.window?.beginSheet(self.childEditWindowController.window!) {returnCode in
                if returnCode == NSModalResponseOK {
                    // create a child node
                    let childNode = ChildNode(leaf: ())
                    childNode.url = childEditViewController.savedValues[kURL_Key] as! URL?
                    if let newNodeStr = childEditViewController.savedValues[kName_Key] as! String?, !newNodeStr.isEmpty {
                            childNode.nodeTitle = newNodeStr
                    } else {
                        childNode.nodeTitle = BaseNode.untitledName
                    }
                    
                    // remove the current selection and replace it with the newly edited child
                    let indexPath = self.treeController.selectionIndexPath!
                    self.treeController.remove(self)
                    self.treeController.insert(childNode, atArrangedObjectIndexPath: indexPath)
                }
            }
        }
    }
    
    
    //MARK: - Managing Views
    
    // -------------------------------------------------------------------------------
    //  viewControllerForSelection:selection
    // -------------------------------------------------------------------------------
    // Used to instruct which view controller to use as the detail when the outline view item is selected
    func viewControllerForSelection(_ selection: [NSTreeNode]?) -> NSViewController? {
        var returnViewController: NSViewController? = nil
        
        if let selection = selection, selection.count == 1 {
            let node = selection[0].representedObject as! BaseNode
            if let url = node.url {
                if node.isBookmark {
                    // it's a bookmark,
                    // return a view controller with a web view, retarget with "urlStr"
                    let webView = self.webViewController.view as! WebView
                    webView.mainFrameURL = url.absoluteString	// re-target to the new url

                    returnViewController = self.webViewController
                } else {
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
                // it's a non-file system grouping of shortcuts
                self.iconViewController.baseNode = node
                returnViewController = self.iconViewController
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
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        // don't allow special group nodes (Places and Bookmarks) to be selected
        let node = (item as! NSTreeNode).representedObject as! BaseNode
        return !node.isSpecialGroup && !node.isSeparator
    }
    
    // -------------------------------------------------------------------------------
    //	viewForTableColumn:tableColumn:item
    // -------------------------------------------------------------------------------
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var result = outlineView.make(withIdentifier: tableColumn?.identifier ?? "", owner: self)
        
        if let node = (item as! NSTreeNode).representedObject as? BaseNode {
            if self.outlineView(outlineView, isGroupItem: item) {    // is it a special group (not a folder)?
                // Group items are sections of our outline that can be hidden/shown (i.e. PLACES/BOOKMARKS).
                let identifier = outlineView.tableColumns[0].identifier
                result = outlineView.make(withIdentifier: identifier, owner: self) as! NSTableCellView?
                let value = node.nodeTitle.uppercased()
                (result as! NSTableCellView).textField!.stringValue = value
            } else if node.isSeparator {
                // Separators have no title or icon, just use the custom view to draw it.
                result = outlineView.make(withIdentifier: "Separator", owner: self)
            } else {
                (result as! NSTableCellView).textField!.stringValue = node.nodeTitle
                (result as! NSTableCellView).imageView!.image = node.nodeIcon
                
                if node.isLeaf {
                    (result as! NSTableCellView).textField!.isEditable = true // Just for fun, make leaf title's editable.
                    //### Translator's extra
                    (result as! NSTableCellView).textField!.target = self
                    (result as! NSTableCellView).textField!.action = #selector(self.didEditTextField(_:))
                } else {
                    //### actually needs to reset some properties for reuse...
                    //### keeping 'do nothing' as in the original sample code.
                    //(result as! NSTableCellView).textField!.isEditable = false
                }
            }
        }
        
        return result
    }
    
    // -------------------------------------------------------------------------------
    //	textShouldEndEditing:fieldEditor
    // -------------------------------------------------------------------------------
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        // don't allow empty node names
        return !(fieldEditor.string?.isEmpty ?? true)
    }
    
    // ----------------------------------------------------------------------------------------
    //  outlineView:isGroupItem:item
    //
    //  Determine if the item should be a special grouping (not a folder but a group with Hide/Show buttons)
    // ----------------------------------------------------------------------------------------
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        let node = (item as! NSTreeNode).representedObject as! BaseNode
        return node.isSpecialGroup
    }
    
    
    //MARK: - NSOutlineView drag and drop
    
    // ----------------------------------------------------------------------------------------
    // outlineView:writeItems:toPasteboard
    // ----------------------------------------------------------------------------------------
    func outlineView(_ ov: NSOutlineView, writeItems items: [Any], to pboard: NSPasteboard) -> Bool {
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
    func outlineView(_ ov: NSOutlineView,
        validateDrop info: NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int) -> NSDragOperation
    {
        var result = NSDragOperation()
        
        if item == nil {
            // no item to drop on
            result = .generic
        } else {
            let node = (item as! NSTreeNode).representedObject as! BaseNode
            if node.isSpecialGroup {
                // don't allow dragging into special grouped sections (i.e. Places and Bookmarks)
                result = NSDragOperation()
            } else {
                if index == -1 {
                    // don't allow dropping on a child
                    result = NSDragOperation()
                } else {
                    // drop location is a container
                    result = .move
                    
                    let dropLocation = (item as! NSTreeNode).representedObject as! BaseNode  // item we are dropping on
                    let draggedItem = self.dragNodesArray![0].representedObject as! BaseNode
                    
                    // don't allow an item to drop onto itself, or within it's content
                    if dropLocation === draggedItem ||
                        dropLocation.isDescendantOfNodes([draggedItem])
                    {
                        result = NSDragOperation()
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
    private func handleWebURLDrops(_ pboard: NSPasteboard, withIndexPath indexPath: IndexPath) {
        let pbArray = pboard.propertyList(forType: "WebURLsWithTitlesPboardType") as! [[String]]
        let urlArray = pbArray[0]
        let nameArray = pbArray[1]
        
        for i in (0..<urlArray.count).reversed() {
            let node = ChildNode()
            
            node.isLeaf = true
            node.nodeTitle = nameArray[i]
            node.url = URL(string: urlArray[i])!
            
            self.treeController.insert(node, atArrangedObjectIndexPath: indexPath)
        }
    }
    
    // -------------------------------------------------------------------------------
    //	handleInternalDrops:pboard:withIndexPath:
    //
    //	The user is doing an intra-app drag within the outline view.
    // -------------------------------------------------------------------------------
    private func handleInternalDrops(_ pboard: NSPasteboard, withIndexPath indexPath: IndexPath) {
        // user is doing an intra app drag within the outline view:
        //
        let newNodes = self.dragNodesArray!
        
        // move the items to their new place
        self.treeController.move(self.dragNodesArray!, to: indexPath)
        
        // keep the moved nodes selected
        var indexPathList: [IndexPath] = []
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
    private func handleFileBasedDrops(_ pboard: NSPasteboard, withIndexPath indexPath: IndexPath) {
        guard let fileNames = pboard.propertyList(forType: NSFilenamesPboardType) as? [String], !fileNames.isEmpty else {return}
        
        for fileName in fileNames.lazy.reversed() {
            let node = ChildNode()
            
            let url = URL(fileURLWithPath: fileName)
            let name = FileManager.default.displayName(atPath: url.path)
            node.isLeaf = true
            
            node.nodeTitle = name
            node.url = url
            
            self.treeController.insert(node, atArrangedObjectIndexPath: indexPath)
        }
    }
    
    // -------------------------------------------------------------------------------
    //	handleURLBasedDrops:pboard:withIndexPath:
    //
    //	Handle dropping a raw URL.
    // -------------------------------------------------------------------------------
    private func handleURLBasedDrops(_ pboard: NSPasteboard, withIndexPath indexPath: IndexPath) {
        guard let url = NSURL(from: pboard) as URL? else {return}
        let node = ChildNode()
        
        if url.isFileURL {
            // url is file-based, use it's display name
            let name = FileManager.default.displayName(atPath: url.path)
            node.nodeTitle = name
            node.url = url
        } else {
            // url is non-file based (probably from Safari)
            //
            // the url might not end with a valid component name, use the best possible title from the URL
            if url.pathComponents.count == 1 {
                if node.isBookmark {
                    // use the url portion without the prefix
                    let prefixRange = url.absoluteString.range(of: HTTP_PREFIX)!
                    let newRange = prefixRange.upperBound..<url.absoluteString.characters.index(before: url.absoluteString.endIndex)
                    node.nodeTitle = url.absoluteString.substring(with: newRange)
                } else {
                    // prefix unknown, just use the url as its title
                    node.nodeTitle = url.absoluteString
                }
            } else {
                // use the last portion of the URL as its title
                node.nodeTitle = url.lastPathComponent
            }
            
            node.url = url
        }
        node.isLeaf = true
        
        self.treeController.insert(node, atArrangedObjectIndexPath: indexPath)
    }
    
    // -------------------------------------------------------------------------------
    //	outlineView:acceptDrop:item:childIndex
    //
    //	This method is called when the mouse is released over an outline view that previously decided to allow a drop
    //	via the validateDrop method. The data source should incorporate the data from the dragging pasteboard at this time.
    //	'index' is the location to insert the data as a child of 'item', and are the values previously set in the validateDrop: method.
    //
    // -------------------------------------------------------------------------------
    func outlineView(_ ov: NSOutlineView, acceptDrop info: NSDraggingInfo, item targetItem: Any?, childIndex index: Int) -> Bool {
        // note that "targetItem" is a NSTreeNode proxy
        //
        var result = false
        
        // find the index path to insert our dropped object(s)
        let indexPath: IndexPath
        if targetItem != nil {
            // drop down inside the tree node:
            // feth the index path to insert our dropped node
            indexPath = (targetItem! as AnyObject).indexPath!!.appending(index)
        } else {
            // drop at the top root level
            if index == -1 {	// drop area might be ambiguous (not at a particular location)
                indexPath = IndexPath(index: self.contents.count) // drop at the end of the top level
            } else {
                indexPath = IndexPath(index: index) // drop at a particular place at the top level
            }
        }
        
        let pboard = info.draggingPasteboard()	// get the pasteboard
        
        // check the dragging type -
        if pboard.availableType(from: [kNodesPBoardType]) != nil {
            // user is doing an intra-app drag within the outline view
            self.handleInternalDrops(pboard, withIndexPath: indexPath)
            result = true
        } else if pboard.availableType(from: ["WebURLsWithTitlesPboardType"]) != nil {
            // the user is dragging URLs from Safari
            self.handleWebURLDrops(pboard, withIndexPath: indexPath)
            result = true
        } else if pboard.availableType(from: [NSFilenamesPboardType]) != nil {
            // the user is dragging file-system based objects (probably from Finder)
            self.handleFileBasedDrops(pboard, withIndexPath: indexPath)
            result = true
        } else if pboard.availableType(from: [NSURLPboardType]) != nil {
            // handle dropping a raw URL
            self.handleURLBasedDrops(pboard, withIndexPath: indexPath)
            result = true
        }
        
        return result
    }
    
    //MARK: - ### Translator's extra
    @objc func didEditTextField(_ sender: NSTextField) {
        if let selectedItem = myOutlineView.item(atRow: myOutlineView.selectedRow) as? NSTreeNode {
            (selectedItem.representedObject as! BaseNode).nodeTitle = sender.stringValue
        }
    }
}
