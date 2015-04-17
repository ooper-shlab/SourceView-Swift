/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Subclass of NSTextFieldCell which can display text and an image simultaneously.
 */

#import <Cocoa/Cocoa.h>

@interface ImageAndTextCell : NSTextFieldCell
@property (readwrite, strong) NSImage *myImage;
@end
