/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller containing the lower UI controls and the embedded child view controller (split view controller).
 */

#import "PrimaryViewController.h"
#import "IconViewController.h"
#import "BaseNode.h"

// notification to instruct MyOutlineViewController to add a folder
NSString *kAddFolderNotification = @"AddFolderNotification";

// notification to instruct MyOutlineViewController to remove a folder
NSString *kRemoveFolderNotification = @"RemoveFolderNotification";

// notification to instruct MyOutlineViewController to add a bookmark
NSString *kAddBookmarkNotification = @"AddBookmarkNotification";

// notification to instruct MyOutlineViewController to edit a bookmark
NSString *kEditBookmarkNotification = @"EditBookmarkNotification";

@interface PrimaryViewController ()

@property (nonatomic, weak)	IBOutlet NSProgressIndicator *progIndicator;
@property (nonatomic, weak)	IBOutlet NSButton *removeButton;
@property (nonatomic, weak)	IBOutlet NSPopUpButton *actionButton;
@property (nonatomic, weak)	IBOutlet NSTextField *urlField;
@property (nonatomic, strong) IBOutlet NSMenuItem *editBookmarkMenuItem;

@end

#pragma mark -

@implementation PrimaryViewController


// -------------------------------------------------------------------------------
//	viewDidLoad
// -------------------------------------------------------------------------------
- (void)viewDidLoad
{
    // Note: we keep the left split view item from growing as the window grows by setting its holding priority to 200,
    // and the right to 199. The view with the lowest priority will be the first to take on additional width if the
    // split view grows or shrinks.
    //
    [super viewDidLoad];
    
    // insert an empty menu item at the beginning of the drown down button's menu and add its image
    NSImage *actionImage = [NSImage imageNamed:NSImageNameActionTemplate];
    actionImage.size = NSMakeSize(10,10);
    
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [self.actionButton.menu insertItem:menuItem atIndex:0];
    menuItem.image = actionImage;
    
    [self.actionButton.menu setAutoenablesItems:NO];
    
    // start off by disabling the Edit... menu item until we are notified of a selection
    self.editBookmarkMenuItem.enabled = NO;
    
    // truncate to the middle if the url is too long to fit
    self.urlField.cell.lineBreakMode = NSLineBreakByTruncatingMiddle;
}

// -------------------------------------------------------------------------------
//	viewWillAppear
// -------------------------------------------------------------------------------
- (void)viewWillAppear
{
    [super viewWillAppear];
    
    // listen for selection changes from the NSOutlineView inside MyOutlineViewController
    // note: we start observing after our outline view is populated so we don't receive unnecessary notifications at startup
    //
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(selectionDidChange:)
                                                 name:NSOutlineViewSelectionDidChangeNotification
                                               object:nil];
    
    // notification so we know when the icon view controller is done populating its content
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentReceived:)
                                                 name:kReceivedContentNotification
                                               object:nil];
}

// -------------------------------------------------------------------------------
//	dealloc
// -------------------------------------------------------------------------------
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSOutlineViewSelectionDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReceivedContentNotification object:nil];
}


#pragma mark - NSNotifications

// -------------------------------------------------------------------------------
//  contentReceived:notif
//
//  Notification sent from IconViewController class,
//  indicating the file system content has been received
// -------------------------------------------------------------------------------
- (void)contentReceived:(NSNotification *)notif
{
    self.progIndicator.hidden = YES;
    [self.progIndicator stopAnimation:self];
}

// -------------------------------------------------------------------------------
//  Listens for changes outline view row selection
// -------------------------------------------------------------------------------
- (void)selectionDidChange:(NSNotification *)notification
{
    // examine the current selection and adjust the UI
    //
    NSOutlineView *outlineView = notification.object;
    NSInteger selectedRow = outlineView.selectedRow;
    if (selectedRow == -1)
    {
        // there is no current selection - no item to display
        self.removeButton.enabled = NO;
        self.urlField.stringValue = @"";
        self.editBookmarkMenuItem.enabled = NO;
    }
    else
    {
        // single selection
        self.removeButton.enabled = YES;
        
        // report the URL to our NSTextField
        BaseNode *item = [[outlineView itemAtRow:selectedRow] representedObject];
        
        if ([item isBookmark])
        {
            self.urlField.stringValue = (item.url != nil) ? item.url.absoluteString : @"";
        }
        else
        {
            
            self.urlField.stringValue = (item.url != nil) ? item.url.path : @"";
        }
        
        // enable the Edit... menu item if the selected node is a bookmark
        self.editBookmarkMenuItem.enabled = ![item.url isFileURL];
        
        if (item.isDirectory)
        {
            // we are populating the detail view controler with contents of a folder on disk
            // (may take a while)
            self.progIndicator.hidden = NO;
        }
    }
}


#pragma mark - Folders

// -------------------------------------------------------------------------------
//	addFolderAction:sender:
// -------------------------------------------------------------------------------
- (IBAction)addFolderAction:(id)sender
{
    // post notification to MyOutlineViewController to add a new folder
    [[NSNotificationCenter defaultCenter] postNotificationName:kAddFolderNotification object:nil];
}

// -------------------------------------------------------------------------------
//	removeFolderAction:sender:
// -------------------------------------------------------------------------------
- (IBAction)removeFolderAction:(id)sender
{
    // post notification to MyOutlineViewController to remove the selected folder
    [[NSNotificationCenter defaultCenter] postNotificationName:kRemoveFolderNotification object:nil];
}


#pragma mark - Bookmarks

// -------------------------------------------------------------------------------
//	addBookmarkAction:sender
// -------------------------------------------------------------------------------
- (IBAction)addBookmarkAction:(id)sender
{
    // post notification to MyOutlineViewController to add a new bookmark
    [[NSNotificationCenter defaultCenter] postNotificationName:kAddBookmarkNotification object:nil];
}

// -------------------------------------------------------------------------------
//	editChildAction:sender
// -------------------------------------------------------------------------------
- (IBAction)editBookmarkAction:(id)sender
{
    // post notification to MyOutlineViewController to edit a selected bookmark
    [[NSNotificationCenter defaultCenter] postNotificationName:kEditBookmarkNotification object:nil];
}

@end
