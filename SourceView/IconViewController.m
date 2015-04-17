/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Controller object for our icon collection view.
 */

#import "IconViewController.h"

// key values for the icon view dictionary
NSString *KEY_NAME = @"name";
NSString *KEY_ICON = @"icon";

// notification for indicating file system content has been received
NSString *kReceivedContentNotification = @"ReceivedContentNotification";

@interface IconViewBox : NSBox
@end
@implementation IconViewBox
- (NSView *)hitTest:(NSPoint)aPoint
{
	// don't allow any mouse clicks for subviews in this NSBox
	return nil;
}
@end


#pragma mark -

@interface IconViewController ()

@property (readwrite, strong) IBOutlet NSArrayController *iconArrayController;
@property (readwrite, strong) NSMutableArray *icons;

@end


@implementation IconViewController

// -------------------------------------------------------------------------------
//	awakeFromNib
// -------------------------------------------------------------------------------
- (void)awakeFromNib
{
	// listen for changes in the url for this view
	[self addObserver:	self
						forKeyPath:@"url"
						options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) 
						context:NULL];
}

// -------------------------------------------------------------------------------
//	dealloc
// -------------------------------------------------------------------------------
- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"url"];
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
        
        NSArray *fileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.url
                                                          includingPropertiesForKeys:@[]
                                                                             options:0
                                                                        error:nil];
        if (fileURLs)
        {
            for (NSURL *element in fileURLs)
            {
                NSString *elementNameStr = nil;
                NSImage *elementIcon = [[NSWorkspace sharedWorkspace] iconForFile:[element path]];

                // only allow visible objects
                NSNumber *hiddenFlag = nil;
                if ([element getResourceValue:&hiddenFlag forKey:NSURLIsHiddenKey error:nil])
                {
                    if (![hiddenFlag boolValue])
                    {
                        if ([element getResourceValue:&elementNameStr forKey:NSURLNameKey error:nil])
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
        
        // call back on the main thread to update the icons in our view
        [self performSelectorOnMainThread:@selector(updateIcons:) withObject:contentArray waitUntilDone:YES];
	}
}

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
										toTarget:self		// we are the target
										withObject:self.url];
}

@end
