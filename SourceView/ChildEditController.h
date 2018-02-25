/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Controller object for the edit sheet panel.
 */

#import <Cocoa/Cocoa.h>

@class MyWindowController;

@interface ChildEditController : NSWindowController

- (NSDictionary *)edit:(NSDictionary *)startingValues from:(MyWindowController *)sender;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL wasCancelled;

@end
