/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The sample's application delegate object (NSApplicationDelegate).
 */

#import "AppDelegate.h"
#import "MyWindowController.h"

@interface AppDelegate ()
@property (strong) MyWindowController *myWindowController;
@end


#pragma mark -

@implementation AppDelegate

// -------------------------------------------------------------------------------
//	applicationShouldTerminateAfterLastWindowClosed:sender
//
//	NSApplication delegate method placed here so the sample conveniently quits
//	after we close the window.
// -------------------------------------------------------------------------------
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
	return YES;
}

// -------------------------------------------------------------------------------
//	applicationDidFinishLaunching:notification
// -------------------------------------------------------------------------------
- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
	// load the app's main window from an external nib for display
	_myWindowController = [[MyWindowController alloc] initWithWindowNibName:@"MainWindow"];
	[self.myWindowController showWindow:self];
}

@end
