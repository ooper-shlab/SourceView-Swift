/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Controller object for our file view.
 */

#import <Cocoa/Cocoa.h>

@interface FileViewController : NSViewController

@property (readwrite, strong) NSURL *url;

@end
