/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller object to host the UI for file information
 */

#import "FileViewController.h"

@interface FileViewController ()

@property (nonatomic, strong) IBOutlet NSImageView *fileIcon;
@property (nonatomic, strong) IBOutlet NSTextField *fileName;
@property (nonatomic, strong) IBOutlet NSTextField *fileSize;
@property (nonatomic, strong) IBOutlet NSTextField *modDate;
@property (nonatomic, strong) IBOutlet NSTextField *creationDate;
@property (nonatomic, strong) IBOutlet NSTextField *fileKindString;

@end

#pragma mark -

@implementation FileViewController

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
//	observeValueForKeyPath:ofObject:change:context
//
//	Listen for changes in the file url.
// -------------------------------------------------------------------------------
- (void)observeValueForKeyPath:	(NSString *)keyPath
								ofObject:(id)object 
								change:(NSDictionary *)change 
								context:(void *)context
{
	// name
	(self.fileName).stringValue = [[NSFileManager defaultManager] displayNameAtPath:(self.url).path];
	
	// icon
	NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFile:(self.url).path];
	iconImage.size = NSMakeSize(64,64);
	(self.fileIcon).image = iconImage;
	
	NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:(self.url).path error:nil];
	if (attr)
	{
		// file size
		NSNumber *theFileSize = attr[NSFileSize];
        (self.fileSize).stringValue = [NSString stringWithFormat:@"%@ KB on disk", theFileSize.stringValue];
		
		// creation date
		NSDate *fileCreationDate = attr[NSFileCreationDate];
        (self.creationDate).stringValue = fileCreationDate.description;
				
		// mod date
		NSDate *fileModDate = attr[NSFileModificationDate];
        (self.modDate).stringValue = fileModDate.description;	
	}

	// kind string
	CFStringRef kindStr = nil;
	LSCopyKindStringForURL((__bridge CFURLRef)self.url, &kindStr);
	if (kindStr !=  nil)
	{
		(self.fileKindString).stringValue = (__bridge NSString *)kindStr;
		CFRelease(kindStr);
	}
}

@end
