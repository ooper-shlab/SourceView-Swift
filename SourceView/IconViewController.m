/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller object to host the icon collection view.
 */

#import "IconViewController.h"
#import "IconViewBox.h"
#import "BaseNode.h"

// notification for indicating file system content has been received
NSString *kReceivedContentNotification = @"ReceivedContentNotification";

@interface IconViewController ()

@property (readwrite, strong) NSMutableArray *icons;

@end


#pragma mark -

@implementation IconViewController

@synthesize baseNode = _baseNode;

// -------------------------------------------------------------------------------
//	awakeFromNib
// -------------------------------------------------------------------------------
- (void)awakeFromNib
{
	// Listen for changes in the url for this view.
	[self addObserver:self
           forKeyPath:@"url"
              options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
              context:nil];
}

// -------------------------------------------------------------------------------
//	dealloc
// -------------------------------------------------------------------------------
- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"url"];
}

// -------------------------------------------------------------------------------
//	setBaseNode:baseNode
// -------------------------------------------------------------------------------
- (void)setBaseNode:(BaseNode *)baseNode
{
    // Our base node has changed, notify ourselves to update our data source.
    _baseNode = baseNode;
    [self gatherContents:baseNode];
}

// -------------------------------------------------------------------------------
//	baseNode
// -------------------------------------------------------------------------------
- (BaseNode *)baseNode
{
    return _baseNode;
}

// -------------------------------------------------------------------------------
//	updateIcons:iconArray
//
//	The incoming object is the NSArray of file system objects to display.
//-------------------------------------------------------------------------------
- (void)updateIcons:(id)iconArray
{
    self.icons = iconArray;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kReceivedContentNotification object:nil];
}

// -------------------------------------------------------------------------------
//	gatherContents:inObject
//
//	Gathering the contents and their icons could be expensive.
//	This method is being called on a separate thread to avoid blocking the UI.
// -------------------------------------------------------------------------------
- (void)gatherContents:(id)inObject
{
	@autoreleasepool {
	
        NSMutableArray *contentArray = [[NSMutableArray alloc] init];
        
        if ([inObject isKindOfClass:[BaseNode class]])
        {
            // We are populating our collection view with a set of internet shortcuts from our baseNode.
            //
            NSArray *shortcuts = self.baseNode.children;
            for (BaseNode *node in shortcuts)
            {
                // the node's icon was set to a smaller size before, for this collection view we need to make it bigger
                NSImage *shortcutIcon = [node.nodeIcon copy];
                shortcutIcon.size = NSMakeSize(kIconLargeImageSize, kIconLargeImageSize);
                
                [contentArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                            shortcutIcon, KEY_ICON,
                                            node.nodeTitle, KEY_NAME,
                                         nil]];
            }
        }
        else
        {
            // We are populating our collection view with a file system directory URL.
            //
            NSURL *urlToDirectory = inObject;
            NSArray *fileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:urlToDirectory
                                                              includingPropertiesForKeys:@[]
                                                                                 options:0
                                                                                   error:nil];
            if (fileURLs != nil)
            {
                for (NSURL *element in fileURLs)
                {
                    NSImage *elementIcon = [[NSWorkspace sharedWorkspace] iconForFile:element.path];

                    // only allow visible objects
                    NSNumber *hiddenFlag = nil;
                    if ([element getResourceValue:&hiddenFlag forKey:NSURLIsHiddenKey error:nil])
                    {
                        if (!hiddenFlag.boolValue)
                        {
                            NSString *elementNameStr = nil;
                            if ([element getResourceValue:&elementNameStr forKey:NSURLLocalizedNameKey error:nil])
                            {
                                // file system object is visible so add to our array
                                [contentArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                            elementIcon, KEY_ICON,
                                                            elementNameStr, KEY_NAME,
                                                         nil]];
                            }
                        }
                    }
                }
            }
        }
        
        // call back on the main thread to update the icons in our view
        [self performSelectorOnMainThread:@selector(updateIcons:) withObject:contentArray waitUntilDone:YES];
	}
}


#pragma mark - KVO

// -------------------------------------------------------------------------------
//	observeValueForKeyPath:ofObject:change:context
//
//	Listen for changes in the file url.
//	Given a url, obtain its contents and add only the invisible items to the collection.
// -------------------------------------------------------------------------------
- (void)observeValueForKeyPath:(NSString *)keyPath
								ofObject:(id)object 
								change:(NSDictionary *)change 
								context:(void *)context
{
    // build our directory contents on a separate thread,
    // some portions are from disk which could get expensive depending on the size
    //
    [NSThread detachNewThreadSelector:	@selector(gatherContents:)
                                        toTarget:self // we are the target
                                        withObject:self.url];
}

@end
