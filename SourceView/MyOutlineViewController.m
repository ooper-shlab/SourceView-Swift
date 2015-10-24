/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The master view controller containing the NSOutlineView and NSTreeController
 */

#import "MyOutlineViewController.h"
#import "ChildNode.h"

#import "IconViewController.h"
#import "ChildEditViewController.h"
#import "FileViewController.h"
#import "WebViewController.h"

#import "SeparatorView.h"
#import "PrimaryViewController.h"

#define INITIAL_INFODICT		@"Outline"		// name of the dictionary file to populate our outline view

#define ICONVIEW_IDENTIFIER		@"IconViewController"   // storyboard identifier for the icon view
#define FILEVIEW_IDENTIFIER		@"FileViewController"   // storyboard identifier for the file view
#define WEBVIEW_IDENTIFIER		@"WebViewController"    // storyboard identifier for the web view

#define CHILDEDIT_IDENTIFIER	@"ChildEditWindowController"	// storyboard identifier the child edit window controller

#define UNTITLED_NAME			@"Untitled"		// default name for added folders and leafs

#define HTTP_PREFIX				@"http://"

// default folder titles
#define PLACES_NAME				@"PLACES"
#define BOOKMARKS_NAME			@"BOOKMARKS"

// keys in our disk-based dictionary representing our outline view's data
#define KEY_NAME				@"name"
#define KEY_URL					@"url"
#define KEY_SEPARATOR			@"separator"
#define KEY_GROUP				@"group"
#define KEY_FOLDER				@"folder"
#define KEY_ENTRIES				@"entries"

#define kIconImageSize          16.0

#define kNodesPBoardType		@"myNodesPBoardType"	// drag and drop pasteboard type


#pragma mark -

// -------------------------------------------------------------------------------
//	TreeAdditionObj
//
//	This object is used for passing data between the main and secondary thread
//	which populates the outline view.
// -------------------------------------------------------------------------------
@interface TreeAdditionObj : NSObject

@property (unsafe_unretained, readonly) NSIndexPath *indexPath;
@property (unsafe_unretained, readonly) NSString *nodeURL;
@property (unsafe_unretained, readonly) NSString *nodeName;
@property (readonly) BOOL selectItsParent;

@end


#pragma mark -

@implementation TreeAdditionObj

// -------------------------------------------------------------------------------
//  initWithURL:url:name:select
// -------------------------------------------------------------------------------
- (instancetype)initWithURL:(NSString *)url withName:(NSString *)name selectItsParent:(BOOL)select
{
	self = [super init];
	
	_nodeName = name;
	_nodeURL = url;
	_selectItsParent = select;
	
	return self;
}

@end


#pragma mark -

@interface MyOutlineViewController ()

@property (nonatomic, weak)	IBOutlet NSOutlineView *myOutlineView;
@property (nonatomic, weak)	IBOutlet NSView	*placeHolderView;

// cached images for generic folder and url document
@property (nonatomic, strong) NSImage *folderImage;
@property (nonatomic, strong) NSImage *urlImage;

@property (nonatomic, strong) NSArray *dragNodesArray; // used to keep track of dragged nodes
@property (nonatomic, strong) NSMutableArray *contents; // used to keep track of dragged nodes

@property (nonatomic, strong) IconViewController *iconViewController;
@property (nonatomic, strong) FileViewController *fileViewController;
@property (nonatomic, strong) WebViewController *webViewController;

@property (nonatomic, strong) NSWindowController *childEditWindowController;

@end


#pragma mark -

@implementation MyOutlineViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _contents = [[NSMutableArray alloc] init];
    
    // load the icon view controller for later use
    _iconViewController = [self.storyboard instantiateControllerWithIdentifier:ICONVIEW_IDENTIFIER];
    self.iconViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    // load the file view controller for later use
    _fileViewController = [self.storyboard instantiateControllerWithIdentifier:FILEVIEW_IDENTIFIER];
    self.fileViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    // load the web view controller for later use
    _webViewController = [self.storyboard instantiateControllerWithIdentifier:WEBVIEW_IDENTIFIER];
    self.webViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    // load the child edit view controller for later use
    _childEditWindowController = [self.storyboard instantiateControllerWithIdentifier:CHILDEDIT_IDENTIFIER];
    
    // cache the reused icon images
    _folderImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
    (self.folderImage).size = NSMakeSize(kIconImageSize, kIconImageSize);
    
    _urlImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericURLIcon)];
    (self.urlImage).size = NSMakeSize(kIconImageSize, kIconImageSize);
    
    [self populateOutlineContents];

    // scroll to the top in case the outline contents is very long
    (self.myOutlineView).enclosingScrollView.verticalScroller.floatValue = 0.0;
    [(self.myOutlineView).enclosingScrollView.contentView scrollToPoint:NSMakePoint(0,0)];
    
    // make our outline view appear with gradient selection, and behave like the Finder, iTunes, etc.
    (self.myOutlineView).selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
    
    // drag and drop support
    [self.myOutlineView registerForDraggedTypes:@[kNodesPBoardType,			// our internal drag type
                                             NSURLPboardType,			// single url from pasteboard
                                             NSFilenamesPboardType,		// from Safari or Finder
                                             NSFilesPromisePboardType]];

    // notification to add a folder
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(addFolder:)
                                                 name:kAddFolderNotification
                                               object:nil];
    // notification to remove a folder
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(removeFolder:)
                                                 name:kRemoveFolderNotification
                                               object:nil];
    
    // notification to add a bookmark
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(addBookmark:)
                                                 name:kAddBookmarkNotification
                                               object:nil];
    
    // notification to edit a bookmark
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(editBookmark:)
                                                 name:kEditBookmarkNotification
                                               object:nil];
}

// -------------------------------------------------------------------------------
//	dealloc
// -------------------------------------------------------------------------------
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kAddFolderNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRemoveFolderNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kAddBookmarkNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kEditBookmarkNotification object:nil];
}


#pragma mark - Actions

// -------------------------------------------------------------------------------
//	selectParentFromSelection
//
//	Take the currently selected node and select its parent.
// -------------------------------------------------------------------------------
- (void)selectParentFromSelection
{
	if (self.treeController.selectedNodes.count > 0)
	{
		NSTreeNode *firstSelectedNode = (self.treeController).selectedNodes[0];
		NSTreeNode *parentNode = firstSelectedNode.parentNode;
		if (parentNode)
		{
			// select the parent
			NSIndexPath *parentIndex = parentNode.indexPath;
			[self.treeController setSelectionIndexPath:parentIndex];
		}
		else
		{
			// no parent exists (we are at the top of tree), so make no selection in our outline
			NSArray *selectionIndexPaths = self.treeController.selectionIndexPaths;
			[self.treeController removeSelectionIndexPaths:selectionIndexPaths];
		}
	}
}

// -------------------------------------------------------------------------------
//	performAddFolder:treeAddition
// -------------------------------------------------------------------------------
- (void)performAddFolder:(TreeAdditionObj *)treeAddition
{
	// NSTreeController inserts objects using NSIndexPath, so we need to calculate this
	NSIndexPath *indexPath = nil;
	
	// if there is no selection, we will add a new group to the end of the contents array
	if (self.treeController.selectedObjects.count == 0)
	{
		// there's no selection so add the folder to the top-level and at the end
		indexPath = [NSIndexPath indexPathWithIndex:self.contents.count];
	}
	else
	{
		// get the index of the currently selected node, then add the number its children to the path -
		// this will give us an index which will allow us to add a node to the end of the currently selected node's children array.
		//
		indexPath = self.treeController.selectionIndexPath;
		if ([(self.treeController).selectedObjects[0] isLeaf])
		{
			// user is trying to add a folder on a selected child,
			// so deselect child and select its parent for addition
			[self selectParentFromSelection];
		}
		else
		{
			indexPath = [indexPath indexPathByAddingIndex:[(self.treeController).selectedObjects[0] children].count];
		}
	}
	
	ChildNode *node = [[ChildNode alloc] init];
    node.nodeTitle = treeAddition.nodeName;
	
	// the user is adding a child node, tell the controller directly
	[self.treeController insertObject:node atArrangedObjectIndexPath:indexPath];
}

// -------------------------------------------------------------------------------
//	performAddChild:treeAddition
// -------------------------------------------------------------------------------
- (void)performAddChild:(TreeAdditionObj *)treeAddition
{
	if (self.treeController.selectedObjects.count > 0)
	{
		// we have a selection
		if ([(self.treeController).selectedObjects[0] isLeaf])
		{
			// trying to add a child to a selected leaf node, so select its parent for add
			[self selectParentFromSelection];
		}
	}
	
	// find the selection to insert our node
	NSIndexPath *indexPath;
	if (self.treeController.selectedObjects.count > 0)
	{
		// we have a selection, insert at the end of the selection
		indexPath = (self.treeController).selectionIndexPath;
		indexPath = [indexPath indexPathByAddingIndex:[(self.treeController).selectedObjects[0] children].count];
	}
	else
	{
		// no selection, just add the child to the end of the tree
		indexPath = [NSIndexPath indexPathWithIndex:self.contents.count];
	}
	
	// create a leaf node
	ChildNode *node = [[ChildNode alloc] initLeaf];
	node.urlString = treeAddition.nodeURL;
    
	if (treeAddition.nodeURL)
	{
		if (treeAddition.nodeURL.length > 0)
		{
			// the child to insert has a valid URL, use its display name as the node title
			if (treeAddition.nodeName)
                node.nodeTitle = treeAddition.nodeName;
			else
                node.nodeTitle = [[NSFileManager defaultManager] displayNameAtPath:node.urlString];
		}
		else
		{
			// the child to insert will be an empty URL
            node.nodeTitle = UNTITLED_NAME;
            node.urlString = HTTP_PREFIX;
		}
	}
	
	// the user is adding a child node, tell the controller directly
	[self.treeController insertObject:node atArrangedObjectIndexPath:indexPath];

	// adding a child automatically becomes selected by NSOutlineView, so keep its parent selected
	if (treeAddition.selectItsParent)
    {
		[self selectParentFromSelection];
    }
}

// -------------------------------------------------------------------------------
//	addChild:url:withName:selectParent
// -------------------------------------------------------------------------------
- (void)addChild:(NSString *)url withName:(NSString *)nameStr selectParent:(BOOL)select
{
	TreeAdditionObj *treeObjInfo = [[TreeAdditionObj alloc] initWithURL:url
                                                               withName:nameStr
                                                        selectItsParent:select];
    [self performAddChild:treeObjInfo];
}

// -------------------------------------------------------------------------------
//	addEntries:discloseParent:
// -------------------------------------------------------------------------------
- (void)addEntries:(NSDictionary *)entries discloseParent:(BOOL)discloseParent
{
	for (id entry in entries)
    {
		if ([entry isKindOfClass:[NSDictionary class]])
		{
			NSString *urlStr = entry[KEY_URL];
			
			if (entry[KEY_SEPARATOR])
			{
				// its a separator mark, we treat is as a leaf
				[self addChild:nil withName:nil selectParent:YES];
			}
			else if (entry[KEY_FOLDER])
			{
				// we treat file system folders as a leaf and show its contents in the NSCollectionView
				NSString *folderName = entry[KEY_FOLDER];
				[self addChild:urlStr withName:folderName selectParent:YES];
			}
			else if (entry[KEY_URL])
			{
				// its a leaf item with a URL
				NSString *nameStr = entry[KEY_NAME];
				[self addChild:urlStr withName:nameStr selectParent:YES];
			}
			else
			{
				// it's a generic container
				NSString *folderName = entry[KEY_GROUP];
				[self addFolderWithName:folderName];
				
				// add its children
				NSDictionary *newChildren = entry[KEY_ENTRIES];
				[self addEntries:newChildren discloseParent:NO];
				
				[self selectParentFromSelection];
			}
		}
	}
	
	if (!discloseParent)
    {
        // inserting children automatically expands its parent, we want to close it
        if ((self.treeController).selectedNodes.count > 0)
        {
            NSTreeNode *lastSelectedNode = (self.treeController).selectedNodes[0];
            [self.myOutlineView collapseItem:lastSelectedNode];
        }
    }
}

// -------------------------------------------------------------------------------
//	populateOutline
//
//	Populate the tree controller from disk-based dictionary (Outline.dict)
// -------------------------------------------------------------------------------
- (void)populateOutline
{
    // add the "Bookmarks" section
	[self addFolderWithName:BOOKMARKS_NAME];

    NSDictionary *initData = [NSDictionary dictionaryWithContentsOfFile:
								[[NSBundle mainBundle] pathForResource:INITIAL_INFODICT ofType:@"dict"]];
	NSDictionary *entries = initData[KEY_ENTRIES];
	[self addEntries:entries discloseParent:YES];
    
    [self selectParentFromSelection];
}

// -------------------------------------------------------------------------------
//	addPlacesSection
// -------------------------------------------------------------------------------
- (void)addPlacesSection
{
	// add the "Places" section
    [self addFolderWithName:PLACES_NAME];
	
	// add its children
	[self addChild:NSHomeDirectory() withName:@"Home" selectParent:YES];
    
    NSArray *appsDirectory = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES);
	[self addChild:appsDirectory[0] withName:nil selectParent:YES];

	[self selectParentFromSelection];
}

// -------------------------------------------------------------------------------
//	populateOutlineContents
// -------------------------------------------------------------------------------
- (void)populateOutlineContents
{
    // hide the outline view - don't show it as we are building the content
    [self.myOutlineView setHidden:YES];
    
    [self addPlacesSection];		// add the "Places" outline section
    [self populateOutline];			// add the "Bookmark" outline content
    
    // remove the current selection
    NSArray *selection = (self.treeController).selectionIndexPaths;
    [self.treeController removeSelectionIndexPaths:selection];
    
    [self.myOutlineView setHidden:NO];	// we are done populating the outline view content, show it again
}

// -------------------------------------------------------------------------------
//	textFieldAction:sender
// -------------------------------------------------------------------------------
- (IBAction)textFieldAction:(id)sender
{
    // user was done editing an item, assign the new text value to it's represented object
    NSTextField *textField = (NSTextField *)sender;
    NSInteger selectedRow = (self.myOutlineView).selectedRow;
    BaseNode *node = [[self.myOutlineView itemAtRow:selectedRow] representedObject];
    node.nodeTitle = textField.stringValue;
}


#pragma mark - Node checks

// -------------------------------------------------------------------------------
//	isSeparator:node
// -------------------------------------------------------------------------------
- (BOOL)isSeparator:(BaseNode *)node
{
    return (node.nodeIcon == nil && node.nodeTitle.length == 0);
}

// -------------------------------------------------------------------------------
//	isSpecialGroup:groupNode
// -------------------------------------------------------------------------------
- (BOOL)isSpecialGroup:(BaseNode *)groupNode
{
	return (groupNode.nodeIcon == nil &&
			([groupNode.nodeTitle isEqualToString:BOOKMARKS_NAME] || [groupNode.nodeTitle isEqualToString:PLACES_NAME]));
}


#pragma mark - Notifications

// -------------------------------------------------------------------------------
//	addFolder:folderName
// -------------------------------------------------------------------------------
- (void)addFolderWithName:(NSString *)folderName
{
    TreeAdditionObj *treeObjInfo = [[TreeAdditionObj alloc] initWithURL:nil withName:folderName selectItsParent:NO];
    [self performAddFolder:treeObjInfo];
}

// -------------------------------------------------------------------------------
//  addFolder:notif
//
//  Notification sent from PrimaryViewController class, to add a folder.
// -------------------------------------------------------------------------------
- (void)addFolder:(NSNotification *)notif
{
    [self addFolderWithName:UNTITLED_NAME];
}

// -------------------------------------------------------------------------------
//  removeFolder:notif
//
//  Notification sent from PrimaryViewController class, to add a folder.
// -------------------------------------------------------------------------------
- (void)removeFolder:(NSNotification *)notif
{
    [self.treeController remove:self];
}

// -------------------------------------------------------------------------------
//  addBookmark:notif
//
//  Notification sent from PrimaryViewController class, to add a bookmark
// -------------------------------------------------------------------------------
- (void)addBookmark:(NSNotification *)notif
{
    [self.view.window beginSheet:self.childEditWindowController.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSModalResponseOK)
        {
            ChildEditViewController *childEditViewController = (ChildEditViewController *)self.childEditWindowController.contentViewController;
            
            NSString *itemStr = childEditViewController.savedValues[kName_Key];
            [self addChild:childEditViewController.savedValues[kURL_Key]
                  withName:(itemStr.length > 0) ? childEditViewController.savedValues[kName_Key] : UNTITLED_NAME
              selectParent:NO];	// add empty untitled child
        }
    }];
}

// -------------------------------------------------------------------------------
//  editBookmark:notif
//
//  Notification sent from PrimaryViewController class, to edit a bookmark
// -------------------------------------------------------------------------------
- (void)editBookmark:(NSNotification *)notif
{
    ChildEditViewController *childEditViewController = (ChildEditViewController *)self.childEditWindowController.contentViewController;
    
    // get the selected item's name and url
    NSArray *selection = (self.treeController).selectedObjects;
    ChildNode *node = selection[0];
  
    if (node.urlString.length == 0 || !node.isBookmark)
    {
        // it's a folder or a file-system based object, just allow editing the cell title
        NSInteger selectedRow = (self.myOutlineView).selectedRow;
        [self.myOutlineView editColumn:0 row:selectedRow withEvent:NSApp.currentEvent select:YES];
    }
    else
    {
        childEditViewController.savedValues = @{kName_Key:node.nodeTitle, kURL_Key:node.urlString};
        [self.view.window beginSheet:self.childEditWindowController.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSModalResponseOK)
            {
                // create a child node
                ChildNode *childNode = [[ChildNode alloc] initLeaf];
                childNode.urlString = childEditViewController.savedValues[kURL_Key];
                NSString *newNodeStr = childEditViewController.savedValues[kName_Key];
                childNode.nodeTitle = (newNodeStr.length > 0) ? newNodeStr : UNTITLED_NAME;
                
                // remove the current selection and replace it with the newly edited child
                NSIndexPath *indexPath = (self.treeController).selectionIndexPath;
                [self.treeController remove:self];
                [self.treeController insertObject:childNode atArrangedObjectIndexPath:indexPath];
            }
        }];
    }
}


#pragma mark - Managing Views

// -------------------------------------------------------------------------------
//  viewControllerForSelection:selection
// -------------------------------------------------------------------------------
- (NSViewController *)viewControllerForSelection:(NSArray *)selection
{
    NSViewController *returnViewController = nil;
    
    if (selection != nil && selection.count == 1)
    {
        BaseNode *node = [selection[0] representedObject];
        NSString *urlStr = node.urlString;
        if (urlStr != nil)
        {
            if (node.isBookmark)
            {
                // it's a bookmark,
                // return a view controller with a web view, retarget with "urlStr"
                WebView *webView = (WebView *)self.webViewController.view;
                webView.mainFrameURL = urlStr;	// re-target to the new url
                returnViewController = self.webViewController;
                
                self.webViewController.retargetWebView = YES;
            }
            else
            {
                NSURL *url = [NSURL fileURLWithPath:node.urlString];
                
                // detect if the url is a directory
                if (node.isDirectory)
                {
                    // it's a folder
                    self.iconViewController.url = url;
                    returnViewController = self.iconViewController;
                }
                else
                {
                    // it's a file
                    self.fileViewController.url = url;
                    returnViewController = self.fileViewController;
                }
            }
        }
        else
        {
            // no view controller (it's a group)
        }
    }
    else
    {
        // no view controller (no selection)
    }
    
    return returnViewController;
}


#pragma mark - NSOutlineViewDelegate

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	// don't allow special group nodes (Places and Bookmarks) to be selected
	BaseNode *node = [item representedObject];
	return (![self isSpecialGroup:node] && ![self isSeparator:node]);
}

// -------------------------------------------------------------------------------
//	viewForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableCellView *result = [outlineView makeViewWithIdentifier:tableColumn.identifier owner:self];

    BaseNode *node = [item representedObject];
    if (node != nil)
    {
        if ([self outlineView:outlineView isGroupItem:item])
        {
            NSString *identifier = (outlineView.tableColumns[0]).identifier;
            result = [outlineView makeViewWithIdentifier:identifier owner:self];
            NSString *value = (node.nodeTitle).uppercaseString;
            result.textField.stringValue = value;
        }
        else if ([self isSeparator:node])
        {
            // separators have no title or icon, just use the custom view to draw it
            result = [outlineView makeViewWithIdentifier:@"Separator" owner:self];
        }
        else
        {
            result.textField.stringValue = node.nodeTitle;
            
            if (node.isLeaf)
            {
                // does it have a URL string?
                NSString *urlStr = node.urlString;
                if (urlStr)
                {
                    if (node.isLeaf)
                    {
                        NSImage *iconImage;
                        if (node.isBookmark)
                            iconImage = self.urlImage;
                        else
                            iconImage = [[NSWorkspace sharedWorkspace] iconForFile:urlStr];
                        node.nodeIcon = iconImage;
                        
                        [result.textField setEditable:YES];
                    }
                    else
                    {
                        NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFile:urlStr];
                        node.nodeIcon = iconImage;
                    }
                }
                else
                {
                    // it's a separator, don't bother with the icon
                }
            }
            else
            {
                // it's a folder, use the folderImage as its icon
                node.nodeIcon = self.folderImage;
            }
            
            // set the cell's image
            node.nodeIcon.size = NSMakeSize(kIconImageSize, kIconImageSize);
            result.imageView.image = node.nodeIcon;
        }
    }
    
    return result;
}

// -------------------------------------------------------------------------------
//	textShouldEndEditing:fieldEditor
// -------------------------------------------------------------------------------
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    // don't allow empty node names
    return (fieldEditor.string.length == 0 ? NO : YES);
}

// ----------------------------------------------------------------------------------------
// outlineView:isGroupItem:item
// ----------------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
    return ([self isSpecialGroup:[item representedObject]] ? YES : NO);
}


#pragma mark - NSOutlineView drag and drop

// ----------------------------------------------------------------------------------------
// outlineView:writeItems:toPasteboard
// ----------------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)ov writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	[pboard declareTypes:@[kNodesPBoardType] owner:self];
	
	// keep track of this nodes for drag feedback in "validateDrop"
	self.dragNodesArray = items;
	
	return YES;
}

// -------------------------------------------------------------------------------
//	outlineView:validateDrop:proposedItem:proposedChildrenIndex:
//
//	This method is used by NSOutlineView to determine a valid drop target.
// -------------------------------------------------------------------------------
- (NSDragOperation)outlineView:(NSOutlineView *)ov
						validateDrop:(id <NSDraggingInfo>)info
						proposedItem:(id)item
						proposedChildIndex:(NSInteger)index
{
	NSDragOperation result = NSDragOperationNone;
	
	if (item == nil)
	{
		// no item to drop on
		result = NSDragOperationGeneric;
	}
	else
	{
		if ([self isSpecialGroup:[item representedObject]])
		{
			// don't allow dragging into special grouped sections (i.e. Places and Bookmarks)
			result = NSDragOperationNone;
		}
		else
		{	
			if (index == -1)
			{
				// don't allow dropping on a child
				result = NSDragOperationNone;
			}
			else
			{
				// drop location is a container
				result = NSDragOperationMove;
                
                BaseNode *dropLocation = [item representedObject];  // item we are dropping on
                BaseNode *draggedItem = [self.dragNodesArray[0] representedObject];

                // don't allow an item to drop onto itself, or within it's content
                if (dropLocation == draggedItem ||
                    [dropLocation isDescendantOfNodes:@[draggedItem]])
                {
                    result = NSDragOperationNone;
                }
			}
		}
	}
	
	return result;
}

// -------------------------------------------------------------------------------
//	handleWebURLDrops:pboard:withIndexPath:
//
//	The user is dragging URLs from Safari.
// -------------------------------------------------------------------------------
- (void)handleWebURLDrops:(NSPasteboard *)pboard withIndexPath:(NSIndexPath *)indexPath
{
	NSArray *pbArray = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"];
	NSArray *urlArray = pbArray[0];
	NSArray *nameArray = pbArray[1];

	for (NSInteger i = (urlArray.count - 1); i >=0; i--)
	{
		ChildNode *node = [[ChildNode alloc] init];
		
        node.isLeaf = YES;

        node.nodeTitle = nameArray[i];
        
        node.urlString = urlArray[i];
		[self.treeController insertObject:node atArrangedObjectIndexPath:indexPath];
	}
}

// -------------------------------------------------------------------------------
//	handleInternalDrops:pboard:withIndexPath:
//
//	The user is doing an intra-app drag within the outline view.
// -------------------------------------------------------------------------------
- (void)handleInternalDrops:(NSPasteboard *)pboard withIndexPath:(NSIndexPath *)indexPath
{
	// user is doing an intra app drag within the outline view:
	//
	NSArray* newNodes = self.dragNodesArray;

	// move the items to their new place (we do this backwards, otherwise they will end up in reverse order)
	NSInteger idx;
	for (idx = (newNodes.count - 1); idx >= 0; idx--)
	{
		[self.treeController moveNode:newNodes[idx] toIndexPath:indexPath];
	}
	
	// keep the moved nodes selected
	NSMutableArray *indexPathList = [NSMutableArray array];
    for (NSUInteger i = 0; i < newNodes.count; i++)
	{
		[indexPathList addObject:[newNodes[i] indexPath]];
	}
	[self.treeController setSelectionIndexPaths: indexPathList];
}

// -------------------------------------------------------------------------------
//	handleFileBasedDrops:pboard:withIndexPath:
//
//	The user is dragging file-system based objects (probably from Finder)
// -------------------------------------------------------------------------------
- (void)handleFileBasedDrops:(NSPasteboard *)pboard withIndexPath:(NSIndexPath *)indexPath
{
	NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
	if (fileNames.count > 0)
	{
		NSInteger i;
		NSInteger count = fileNames.count;
		
		for (i = (count - 1); i >=0; i--)
		{
			ChildNode *node = [[ChildNode alloc] init];

			NSURL *url = [NSURL fileURLWithPath:fileNames[i]];
            NSString *name = [[NSFileManager defaultManager] displayNameAtPath:url.path];
            node.isLeaf = YES;

            node.nodeTitle = name;
            node.urlString = url.path;
            
			[self.treeController insertObject:node atArrangedObjectIndexPath:indexPath];
		}
	}
}

// -------------------------------------------------------------------------------
//	handleURLBasedDrops:pboard:withIndexPath:
//
//	Handle dropping a raw URL.
// -------------------------------------------------------------------------------
- (void)handleURLBasedDrops:(NSPasteboard *)pboard withIndexPath:(NSIndexPath *)indexPath
{
	NSURL *url = [NSURL URLFromPasteboard:pboard];
	if (url != nil)
	{
		ChildNode *node = [[ChildNode alloc] init];

		if (url.isFileURL)
		{
			// url is file-based, use it's display name
			NSString *name = [[NSFileManager defaultManager] displayNameAtPath:url.path];
            node.nodeTitle = name;
            node.urlString = url.path;
		}
		else
		{
			// url is non-file based (probably from Safari)
			//
			// the url might not end with a valid component name, use the best possible title from the URL
			if (url.path.pathComponents.count == 1)
			{
				if (node.isBookmark)
				{
					// use the url portion without the prefix
					NSRange prefixRange = [url.absoluteString rangeOfString:HTTP_PREFIX];
					NSRange newRange = NSMakeRange(prefixRange.length, url.absoluteString.length- prefixRange.length - 1);
                    node.nodeTitle = [url.absoluteString substringWithRange:newRange];
				}
				else
				{
					// prefix unknown, just use the url as its title
                    node.nodeTitle = url.absoluteString;
				}
			}
			else
			{
				// use the last portion of the URL as its title
                node.nodeTitle = url.path.lastPathComponent;
			}
				
            node.urlString = url.absoluteString;
		}
        node.isLeaf = YES;
		
		[self.treeController insertObject:node atArrangedObjectIndexPath:indexPath];
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
- (BOOL)outlineView:(NSOutlineView*)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)targetItem childIndex:(NSInteger)index
{
	// note that "targetItem" is a NSTreeNode proxy
	//
	BOOL result = NO;
	
	// find the index path to insert our dropped object(s)
	NSIndexPath *indexPath;
	if (targetItem != nil)
	{
		// drop down inside the tree node:
		// feth the index path to insert our dropped node
		indexPath = [[targetItem indexPath] indexPathByAddingIndex:index];
	}
	else
	{
		// drop at the top root level
		if (index == -1)	// drop area might be ambibuous (not at a particular location)
			indexPath = [NSIndexPath indexPathWithIndex:self.contents.count]; // drop at the end of the top level
		else
			indexPath = [NSIndexPath indexPathWithIndex:index]; // drop at a particular place at the top level
	}

	NSPasteboard *pboard = [info draggingPasteboard];	// get the pasteboard
	
	// check the dragging type -
	if ([pboard availableTypeFromArray:@[kNodesPBoardType]])
	{
		// user is doing an intra-app drag within the outline view
		[self handleInternalDrops:pboard withIndexPath:indexPath];
		result = YES;
	}
	else if ([pboard availableTypeFromArray:@[@"WebURLsWithTitlesPboardType"]])
	{
		// the user is dragging URLs from Safari
		[self handleWebURLDrops:pboard withIndexPath:indexPath];		
		result = YES;
	}
	else if ([pboard availableTypeFromArray:@[NSFilenamesPboardType]])
	{
		// the user is dragging file-system based objects (probably from Finder)
		[self handleFileBasedDrops:pboard withIndexPath:indexPath];
		result = YES;
	}
	else if ([pboard availableTypeFromArray:@[NSURLPboardType]])
	{
		// handle dropping a raw URL
		[self handleURLBasedDrops:pboard withIndexPath:indexPath];
		result = YES;
	}
	
	return result;
}

@end
