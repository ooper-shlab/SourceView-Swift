/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Interface for MyWindowController class, the main controller class for this sample.
 */

#import <WebKit/WebKit.h>

#import "MyWindowController.h"

#import "IconViewController.h"
//#import "FileViewController.h"
//#import "ChildEditController.h"
//#import "ChildNode.h"
//#import "ImageAndTextCell.h"
//#import "SeparatorCell.h"
#import "SourceView-Swift.h"

#define COLUMNID_NAME			@"NameColumn"	// the single column name in our outline view
#define INITIAL_INFODICT		@"Outline"		// name of the dictionary file to populate our outline view

#define ICONVIEW_NIB_NAME		@"IconView"		// nib name for the icon view
#define FILEVIEW_NIB_NAME		@"FileView"		// nib name for the file view
#define CHILDEDIT_NAME			@"ChildEdit"	// nib name for the child edit window controller

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

#define kMinOutlineViewSplit	120.0f

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

@interface MyWindowController ()
{
	IBOutlet NSOutlineView		*myOutlineView;
	IBOutlet NSTreeController	*treeController;
	IBOutlet NSView				*placeHolderView;
	IBOutlet NSSplitView		*splitView;
	IBOutlet WebView			*webView;
	IBOutlet NSProgressIndicator *progIndicator;
	IBOutlet NSButton			*addFolderButton;
	IBOutlet NSButton			*removeButton;
	IBOutlet NSPopUpButton		*actionButton;
	IBOutlet NSTextField		*urlField;
		
	// cached images for generic folder and url document
	NSImage						*folderImage;
	NSImage						*urlImage;
	
	NSView						*currentView;
	IconViewController			*iconViewController;
	FileViewController			*fileViewController;
	ChildEditController         *childEditController;
			
	BOOL						retargetWebView;
	
	SeparatorCell				*separatorCell;	// the cell used to draw a separator line in the outline view
}

@property (strong) NSArray *dragNodesArray; // used to keep track of dragged nodes
@property (strong) NSMutableArray *contents; // used to keep track of dragged nodes

@end


#pragma mark -

@implementation MyWindowController

// -------------------------------------------------------------------------------
//	initWithWindow:window
// -------------------------------------------------------------------------------
- (instancetype)initWithWindow:(NSWindow *)window
{
	self = [super initWithWindow:window];
	if (self != nil)
	{
		_contents = [[NSMutableArray alloc] init];
		
		// cache the reused icon images
		folderImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
		[folderImage setSize:NSMakeSize(kIconImageSize, kIconImageSize)];
		
		urlImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericURLIcon)];
		[urlImage setSize:NSMakeSize(kIconImageSize, kIconImageSize)];
	}
	
	return self;
}

// -------------------------------------------------------------------------------
//	dealloc
// -------------------------------------------------------------------------------
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReceivedContentNotification object:nil];
}

// -------------------------------------------------------------------------------
//	awakeFromNib
// -------------------------------------------------------------------------------
- (void)awakeFromNib
{
	// load the icon view controller for later use
	iconViewController = [[IconViewController alloc] initWithNibName:ICONVIEW_NIB_NAME bundle:nil];
	
	// load the file view controller for later use
	fileViewController = [[FileViewController alloc] initWithNibName:FILEVIEW_NIB_NAME bundle:nil];
	
	// load the child edit view controller for later use
	childEditController = [[ChildEditController alloc] initWithWindowNibName:CHILDEDIT_NAME];
	
	[[self window] setAutorecalculatesContentBorderThickness:YES forEdge:NSMinYEdge];
	[[self window] setContentBorderThickness:30 forEdge:NSMinYEdge];
	
	// apply our custom ImageAndTextCell for rendering the first column's cells
	NSTableColumn *tableColumn = [myOutlineView tableColumnWithIdentifier:COLUMNID_NAME];
	ImageAndTextCell *imageAndTextCell = [[ImageAndTextCell alloc] initTextCell:@""];
	[imageAndTextCell setEditable:YES];
	[tableColumn setDataCell:imageAndTextCell];
   
	separatorCell = [[SeparatorCell alloc] init];
    [separatorCell setEditable:NO];
	
    // add our content
	[self populateOutlineContents];
    
	// add images to our add/remove buttons
	NSImage *addImage = [NSImage imageNamed:NSImageNameAddTemplate];
	[addFolderButton setImage:addImage];
	NSImage *removeImage = [NSImage imageNamed:NSImageNameRemoveTemplate];
	[removeButton setImage:removeImage];
	
	// insert an empty menu item at the beginning of the drown down button's menu and add its image
	NSImage *actionImage = [NSImage imageNamed:NSImageNameActionTemplate];
	[actionImage setSize:NSMakeSize(10,10)];
	
	NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
	[[actionButton menu] insertItem:menuItem atIndex:0];
	[menuItem setImage:actionImage];
	
	// truncate to the middle if the url is too long to fit
	[[urlField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
	
	// scroll to the top in case the outline contents is very long
	[[[myOutlineView enclosingScrollView] verticalScroller] setFloatValue:0.0];
	[[[myOutlineView enclosingScrollView] contentView] scrollToPoint:NSMakePoint(0,0)];
	
	// make our outline view appear with gradient selection, and behave like the Finder, iTunes, etc.
	[myOutlineView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
	
	// drag and drop support
	[myOutlineView registerForDraggedTypes:@[kNodesPBoardType,			// our internal drag type
											NSURLPboardType,			// single url from pasteboard
											NSFilenamesPboardType,		// from Safari or Finder
											NSFilesPromisePboardType]];
											
	[webView setUIDelegate:self];	// be the webView's delegate to capture NSResponder calls
    [webView setFrameLoadDelegate:self];    // so we can receive any possible errors
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentReceived:)
                                                 name:kReceivedContentNotification
                                               object:nil];
}


#pragma mark - Actions

// -------------------------------------------------------------------------------
//	selectParentFromSelection
//
//	Take the currently selected node and select its parent.
// -------------------------------------------------------------------------------
- (void)selectParentFromSelection
{
	if ([[treeController selectedNodes] count] > 0)
	{
		NSTreeNode *firstSelectedNode = [treeController selectedNodes][0];
		NSTreeNode *parentNode = [firstSelectedNode parentNode];
		if (parentNode)
		{
			// select the parent
			NSIndexPath *parentIndex = [parentNode indexPath];
			[treeController setSelectionIndexPath:parentIndex];
		}
		else
		{
			// no parent exists (we are at the top of tree), so make no selection in our outline
			NSArray *selectionIndexPaths = [treeController selectionIndexPaths];
			[treeController removeSelectionIndexPaths:selectionIndexPaths];
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
	if ([[treeController selectedObjects] count] == 0)
	{
		// there's no selection so add the folder to the top-level and at the end
		indexPath = [NSIndexPath indexPathWithIndex:self.contents.count];
	}
	else
	{
		// get the index of the currently selected node, then add the number its children to the path -
		// this will give us an index which will allow us to add a node to the end of the currently selected node's children array.
		//
		indexPath = [treeController selectionIndexPath];
		if ([[treeController selectedObjects][0] isLeaf])
		{
			// user is trying to add a folder on a selected child,
			// so deselect child and select its parent for addition
			[self selectParentFromSelection];
		}
		else
		{
			indexPath = [indexPath indexPathByAddingIndex:[[[treeController selectedObjects][0] children] count]];
		}
	}
	
	ChildNode *node = [[ChildNode alloc] init];
    node.nodeTitle = [treeAddition nodeName];
	
	// the user is adding a child node, tell the controller directly
	[treeController insertObject:node atArrangedObjectIndexPath:indexPath];
	
}

// -------------------------------------------------------------------------------
//	addFolder:folderName
// -------------------------------------------------------------------------------
- (void)addFolder:(NSString *)folderName
{
    TreeAdditionObj *treeObjInfo = [[TreeAdditionObj alloc] initWithURL:nil withName:folderName selectItsParent:NO];
    [self performAddFolder:treeObjInfo];
}

// -------------------------------------------------------------------------------
//	addFolderAction:sender:
// -------------------------------------------------------------------------------
- (IBAction)addFolderAction:(id)sender
{
	[self addFolder:UNTITLED_NAME];
}

// -------------------------------------------------------------------------------
//	performAddChild:treeAddition
// -------------------------------------------------------------------------------
- (void)performAddChild:(TreeAdditionObj *)treeAddition
{
	if ([[treeController selectedObjects] count] > 0)
	{
		// we have a selection
		if ([[treeController selectedObjects][0] isLeaf])
		{
			// trying to add a child to a selected leaf node, so select its parent for add
			[self selectParentFromSelection];
		}
	}
	
	// find the selection to insert our node
	NSIndexPath *indexPath;
	if ([[treeController selectedObjects] count] > 0)
	{
		// we have a selection, insert at the end of the selection
		indexPath = [treeController selectionIndexPath];
		indexPath = [indexPath indexPathByAddingIndex:[[[treeController selectedObjects][0] children] count]];
	}
	else
	{
		// no selection, just add the child to the end of the tree
		indexPath = [NSIndexPath indexPathWithIndex:self.contents.count];
	}
	
	// create a leaf node
	ChildNode *node = [[ChildNode alloc] initLeaf];
	node.urlString = [treeAddition nodeURL];
    
	if ([treeAddition nodeURL])
	{
		if ([[treeAddition nodeURL] length] > 0)
		{
			// the child to insert has a valid URL, use its display name as the node title
			if ([treeAddition nodeName])
                node.nodeTitle = [treeAddition nodeName];
			else
                node.nodeTitle = [[NSFileManager defaultManager] displayNameAtPath:[node urlString]];
		}
		else
		{
			// the child to insert will be an empty URL
            node.nodeTitle = UNTITLED_NAME;
            node.urlString = HTTP_PREFIX;
		}
	}
	
	// the user is adding a child node, tell the controller directly
	[treeController insertObject:node atArrangedObjectIndexPath:indexPath];

	// adding a child automatically becomes selected by NSOutlineView, so keep its parent selected
	if ([treeAddition selectItsParent])
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
//	addBookmarkAction:sender
// -------------------------------------------------------------------------------
- (IBAction)addBookmarkAction:(id)sender
{
	// ask our edit sheet for information on the new child to be added
	NSDictionary *newValues = [childEditController edit:nil from:self];
    
	if (![childEditController wasCancelled] && newValues)
	{
		NSString *itemStr = newValues[@"name"];
        [self addChild:newValues[@"url"]
			withName:([itemStr length] > 0) ? newValues[@"name"] : UNTITLED_NAME
                selectParent:NO];	// add empty untitled child
	}
}

// -------------------------------------------------------------------------------
//	editChildAction:sender
// -------------------------------------------------------------------------------
- (IBAction)editBookmarkAction:(id)sender
{
	NSIndexPath *indexPath = [treeController selectionIndexPath];
	
	// get the selected item's name and url
	NSInteger selectedRow = [myOutlineView selectedRow];
	BaseNode *node = [[myOutlineView itemAtRow:selectedRow] representedObject];
	NSDictionary *editInfo = @{@"name": [node nodeTitle],
								@"url": [node urlString]};
	
	// only open the edit alert sheet for URL leafs (not folders or file system objects)
	//
	if (([[node urlString] length] == 0) || (![[node urlString] hasPrefix:HTTP_PREFIX]))
	{
		// it's a folder or a file-system based object, just allow editing the cell title
		[myOutlineView editColumn:0 row:selectedRow withEvent:[NSApp currentEvent] select:YES];
	}
	else
	{
		// ask our sheet to edit these two values
		NSDictionary *newValues = [childEditController edit:editInfo from:self];
		if (![childEditController wasCancelled] && newValues)
		{
			// create a child node
			ChildNode *childNode = [[ChildNode alloc] initLeaf];
			childNode.urlString = newValues[@"url"];
            
            NSString *nodeStr = newValues[@"name"];
			childNode.nodeTitle = ([nodeStr length] > 0) ? newValues[@"name"] : UNTITLED_NAME;
			// remove the current selection and replace it with the newly edited child
			[treeController remove:self];
			[treeController insertObject:childNode atArrangedObjectIndexPath:indexPath];
		}
	}
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
				[self addFolder:folderName];
				
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
        if ([[treeController selectedNodes] count] > 0)
        {
            NSTreeNode *lastSelectedNode = [treeController selectedNodes][0];
            [myOutlineView collapseItem:lastSelectedNode];
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
	[self addFolder:BOOKMARKS_NAME];

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
	[self addFolder:PLACES_NAME];
	
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
    [myOutlineView setHidden:YES];
    
    [self addPlacesSection];		// add the "Places" outline section
    [self populateOutline];			// add the "Bookmark" outline content
    
    // remove the current selection
    NSArray *selection = [treeController selectionIndexPaths];
    [treeController removeSelectionIndexPaths:selection];
    
    [myOutlineView setHidden:NO];	// we are done populating the outline view content, show it again
}


#pragma mark - WebView

// -------------------------------------------------------------------------------
//	webView:makeFirstResponder
//
//	We want to keep the outline view in focus as the user clicks various URLs.
//
//	So this workaround applies to an unwanted side affect to some web pages that might have
//	JavaScript code thatt focus their text fields as we target the web view with a particular URL.
//
// -------------------------------------------------------------------------------
- (void)webView:(WebView *)sender makeFirstResponder:(NSResponder *)responder
{
	if (retargetWebView)
	{
		// we are targeting the webview ourselves as a result of the user clicking
		// a url in our outlineview: don't do anything, but reset our target check flag
		//
		retargetWebView = NO;
	}
	else
	{
		// continue the responder chain
		[[self window] makeFirstResponder:sender];
	}
}

// -------------------------------------------------------------------------------
//	didFailProvisionalLoadWithError
// -------------------------------------------------------------------------------
- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    // the URL failed to load in our web view, remove the detail view
    [self removeSubview];
    currentView = nil;
}


#pragma mark - Menu management

// -------------------------------------------------------------------------------
//  validateMenuItem:item
// -------------------------------------------------------------------------------
- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    BOOL enabled = NO;
    
    // is it our "Edit..." menu item in our action button?
    if ([item action] == @selector(editBookmarkAction:))
    {
        if ([[treeController selectedNodes] count] > 0)
        {
            // only allow for editing http url items or items with out a URL
            // (this avoids accidentally renaming real file system items)
            //
            NSTreeNode *firstSelectedNode = [treeController selectedNodes][0];
            BaseNode *node = [firstSelectedNode representedObject];
            if (!node.urlString || [[node urlString] hasPrefix:HTTP_PREFIX])
                enabled = YES;
        }
    }
    
    return enabled;
}


#pragma mark - Node checks

// -------------------------------------------------------------------------------
//	isSeparator:node
// -------------------------------------------------------------------------------
- (BOOL)isSeparator:(BaseNode *)node
{
    return ([node nodeIcon] == nil && [[node nodeTitle] length] == 0);
}

// -------------------------------------------------------------------------------
//	isSpecialGroup:groupNode
// -------------------------------------------------------------------------------
- (BOOL)isSpecialGroup:(BaseNode *)groupNode
{ 
	return ([groupNode nodeIcon] == nil &&
			([[groupNode nodeTitle] isEqualToString:BOOKMARKS_NAME] || [[groupNode nodeTitle] isEqualToString:PLACES_NAME]));
}


#pragma mark - Managing Views

// -------------------------------------------------------------------------------
//  contentReceived:notif
//
//  Notification sent from IconViewController class,
//  indicating the file system content has been received
// -------------------------------------------------------------------------------
- (void)contentReceived:(NSNotification *)notif
{
    [progIndicator setHidden:YES];
    [progIndicator stopAnimation:self];
}

// -------------------------------------------------------------------------------
//	removeSubview
// -------------------------------------------------------------------------------
- (void)removeSubview
{
	// empty selection
	NSArray *subViews = [placeHolderView subviews];
	if ([subViews count] > 0)
	{
		[subViews[0] removeFromSuperview];
	}
	
	[placeHolderView displayIfNeeded];	// we want the removed views to disappear right away
}

// -------------------------------------------------------------------------------
//	changeItemView
// ------------------------------------------------------------------------------
- (void)changeItemView
{
	NSArray	*selection = [treeController selectedNodes];	
	if ([selection count] > 0)
    {
        BaseNode *node = [selection[0] representedObject];
        NSString *urlStr = [node urlString];
        if (urlStr)
        {
            if ([urlStr hasPrefix:HTTP_PREFIX])
            {
                // 1) the url is a web-based url
                //
                if (currentView != webView)
                {
                    // change to web view
                    [self removeSubview];
                    currentView = nil;
                    [placeHolderView addSubview:webView];
                    currentView = webView;
                }
                
                // this will tell our WebUIDelegate not to retarget first responder since some web pages force
                // forus to their text fields - we want to keep our outline view in focus.
                retargetWebView = YES;	
                
                [webView setMainFrameURL:urlStr];	// re-target to the new url
            }
            else
            {
                // 2) the url is file-system based (folder or file)
                //
                if (currentView != [fileViewController view] || currentView != [iconViewController view])
                {
                    NSURL *targetURL = [NSURL fileURLWithPath:urlStr];
                    
                    NSURL *url = [NSURL fileURLWithPath:[node urlString]];
                    
                    // detect if the url is a directory
                    NSNumber *isDirectory = nil;
                    
                    [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
                    if ([isDirectory boolValue])
                    {
                        // avoid a flicker effect by not removing the icon view if it is already embedded
                        if (!(currentView == [iconViewController view]))
                        {
                            // remove the old subview
                            [self removeSubview];
                            currentView = nil;
                        }
                        
                        // change to icon view to display folder contents
                        [placeHolderView addSubview:[iconViewController view]];
                        currentView = [iconViewController view];
                        
                        // its a directory - show its contents using NSCollectionView
                        iconViewController.url = targetURL;
                        
                        // add a spinning progress gear in case populating the icon view takes too long
                        [progIndicator setHidden:NO];
                        [progIndicator startAnimation:self];
                        
                        // note: we will be notifed back to stop our progress indicator
                        // as soon as iconViewController is done fetching its content.
                    }
                    else
                    {
                        // 3) its a file, just show the item info
                        //
                        // remove the old subview
                        [self removeSubview];
                        currentView = nil;
                        
                        // change to file view
                        [placeHolderView addSubview:[fileViewController view]];
                        currentView = [fileViewController view];
                        
                        // update the file's info
                        fileViewController.url = targetURL;
                    }
                }
            }
            
            NSRect newBounds;
            newBounds.origin.x = 0;
            newBounds.origin.y = 0;
            newBounds.size.width = [[currentView superview] frame].size.width;
            newBounds.size.height = [[currentView superview] frame].size.height;
            [currentView setFrame:[[currentView superview] frame]];
            
            // make sure our added subview is placed and resizes correctly
            [currentView setFrameOrigin:NSMakePoint(0,0)];
            [currentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        }
        else
        {
            // there's no url associated with this node
            // so a container was selected - no view to display
            [self removeSubview];
            currentView = nil;
        }
    }
}


#pragma mark - NSOutlineViewDelegate

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
	// don't allow special group nodes (Places and Bookmarks) to be selected
	BaseNode *node = [item representedObject];
	return (![self isSpecialGroup:node] && ![self isSeparator:node]);
}

// -------------------------------------------------------------------------------
//	dataCellForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSCell *returnCell = [tableColumn dataCell];
	
	if ([[tableColumn identifier] isEqualToString:COLUMNID_NAME])
	{
		// we are being asked for the cell for the single and only column
		BaseNode *node = [item representedObject];
		if ([self isSeparator:node])
            returnCell = separatorCell;
	}
	
	return returnCell;
}

// -------------------------------------------------------------------------------
//	textShouldEndEditing:fieldEditor
// -------------------------------------------------------------------------------
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	if ([[fieldEditor string] length] == 0)
	{
		// don't allow empty node names
		return NO;
	}
	else
	{
		return YES;
	}
}

// -------------------------------------------------------------------------------
//	shouldEditTableColumn:tableColumn:item
//
//	Decide to allow the edit of the given outline view "item".
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	BOOL result = YES;
	
	item = [item representedObject];
	if ([self isSpecialGroup:item])
	{
		result = NO; // don't allow special group nodes to be renamed
	}
	else
	{
		if ([[item urlString] isAbsolutePath])
			result = NO;	// don't allow file system objects to be renamed
	}
	
	return result;
}

// -------------------------------------------------------------------------------
//	outlineView:willDisplayCell:forTableColumn:item
// -------------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{	 
    if ([[tableColumn identifier] isEqualToString:COLUMNID_NAME])
	{
		// we are displaying the single and only column
		if ([cell isKindOfClass:[ImageAndTextCell class]])
		{
			item = [item representedObject];
			if (item != nil)
			{
				if ([item isLeaf])
				{
					// does it have a URL string?
					NSString *urlStr = [item urlString];
					if (urlStr)
					{
						if ([item isLeaf])
						{
							NSImage *iconImage;
							if ([[item urlString] hasPrefix:HTTP_PREFIX])
								iconImage = urlImage;
							else
								iconImage = [[NSWorkspace sharedWorkspace] iconForFile:urlStr];
							[item setNodeIcon:iconImage];
						}
						else
						{
							NSImage* iconImage = [[NSWorkspace sharedWorkspace] iconForFile:urlStr];
							[item setNodeIcon:iconImage];
						}
					}
					else
					{
						// it's a separator, don't bother with the icon
					}
				}
				else
				{
					// check if it's a special folder (PLACES or BOOKMARKS), we don't want it to have an icon
					if ([self isSpecialGroup:item])
					{
						[item setNodeIcon:nil];
					}
					else
					{
						// it's a folder, use the folderImage as its icon
						[item setNodeIcon:folderImage];
					}
				}
			}
			
			// set the cell's image
            [[item nodeIcon] setSize:NSMakeSize(kIconImageSize, kIconImageSize)];
            ImageAndTextCell *myCell = (ImageAndTextCell *)cell;
            myCell.myImage = [item nodeIcon];
		}
	}
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	// ask the tree controller for the current selection
	NSArray *selection = [treeController selectedObjects];
	if (selection.count > 1)
	{
		// multiple selection - clear the right side view
		[self removeSubview];
		currentView = nil;
	}
	else
	{
		if (selection.count == 1)
		{
			// single selection
			[self changeItemView];
		}
		else
		{
			// there is no current selection - no view to display
			[self removeSubview];
			currentView = nil;
		}
	}
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

	for (NSInteger i = ([urlArray count] - 1); i >=0; i--)
	{
		ChildNode *node = [[ChildNode alloc] init];
		
        node.isLeaf = YES;

        node.nodeTitle = nameArray[i];
        
        node.urlString = urlArray[i];
		[treeController insertObject:node atArrangedObjectIndexPath:indexPath];
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
	for (idx = ([newNodes count] - 1); idx >= 0; idx--)
	{
		[treeController moveNode:newNodes[idx] toIndexPath:indexPath];
	}
	
	// keep the moved nodes selected
	NSMutableArray *indexPathList = [NSMutableArray array];
    for (NSUInteger i = 0; i < [newNodes count]; i++)
	{
		[indexPathList addObject:[newNodes[i] indexPath]];
	}
	[treeController setSelectionIndexPaths: indexPathList];
}

// -------------------------------------------------------------------------------
//	handleFileBasedDrops:pboard:withIndexPath:
//
//	The user is dragging file-system based objects (probably from Finder)
// -------------------------------------------------------------------------------
- (void)handleFileBasedDrops:(NSPasteboard *)pboard withIndexPath:(NSIndexPath *)indexPath
{
	NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
	if ([fileNames count] > 0)
	{
		NSInteger i;
		NSInteger count = [fileNames count];
		
		for (i = (count - 1); i >=0; i--)
		{
			ChildNode *node = [[ChildNode alloc] init];

			NSURL *url = [NSURL fileURLWithPath:fileNames[i]];
            NSString *name = [[NSFileManager defaultManager] displayNameAtPath:[url path]];
            node.isLeaf = YES;

            node.nodeTitle = name;
            node.urlString = [url path];
            
			[treeController insertObject:node atArrangedObjectIndexPath:indexPath];
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
	if (url)
	{
		ChildNode *node = [[ChildNode alloc] init];

		if ([url isFileURL])
		{
			// url is file-based, use it's display name
			NSString *name = [[NSFileManager defaultManager] displayNameAtPath:[url path]];
            node.nodeTitle = name;
            node.urlString = [url path];
		}
		else
		{
			// url is non-file based (probably from Safari)
			//
			// the url might not end with a valid component name, use the best possible title from the URL
			if ([[[url path] pathComponents] count] == 1)
			{
				if ([[url absoluteString] hasPrefix:HTTP_PREFIX])
				{
					// use the url portion without the prefix
					NSRange prefixRange = [[url absoluteString] rangeOfString:HTTP_PREFIX];
					NSRange newRange = NSMakeRange(prefixRange.length, [[url absoluteString] length]- prefixRange.length - 1);
                    node.nodeTitle = [[url absoluteString] substringWithRange:newRange];
				}
				else
				{
					// prefix unknown, just use the url as its title
                    node.nodeTitle = [url absoluteString];
				}
			}
			else
			{
				// use the last portion of the URL as its title
                node.nodeTitle = [[url path] lastPathComponent];
			}
				
            node.urlString = [url absoluteString];
		}
        node.isLeaf = YES;
		
		[treeController insertObject:node atArrangedObjectIndexPath:indexPath];
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
	if (targetItem)
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


#pragma mark - NSSplitViewDelegate

// -------------------------------------------------------------------------------
//	splitView:constrainMinCoordinate:
//
//	What you really have to do to set the minimum size of both subviews to kMinOutlineViewSplit points.
// -------------------------------------------------------------------------------
- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedCoordinate ofSubviewAt:(int)index
{
	return proposedCoordinate + kMinOutlineViewSplit;
}

// -------------------------------------------------------------------------------
//	splitView:constrainMaxCoordinate:
// -------------------------------------------------------------------------------
- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedCoordinate ofSubviewAt:(int)index
{
	return proposedCoordinate - kMinOutlineViewSplit;
}

// -------------------------------------------------------------------------------
//	splitView:resizeSubviewsWithOldSize:
//
//	Keep the left split pane from resizing as the user moves the divider line.
// -------------------------------------------------------------------------------
- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSRect newFrame = [sender frame]; // get the new size of the whole splitView
	NSView *left = [sender subviews][0];
	NSRect leftFrame = [left frame];
	NSView *right = [sender subviews][1];
	NSRect rightFrame = [right frame];
 
	CGFloat dividerThickness = [sender dividerThickness];
	  
	leftFrame.size.height = newFrame.size.height;

	rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dividerThickness;
	rightFrame.size.height = newFrame.size.height;
	rightFrame.origin.x = leftFrame.size.width + dividerThickness;

	[left setFrame:leftFrame];
	[right setFrame:rightFrame];
}

@end
