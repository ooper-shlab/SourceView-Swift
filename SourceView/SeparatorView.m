/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Custom view to draw a separator.
 */

#import "SeparatorView.h"

@implementation SeparatorView

- (void)drawRect:(NSRect)dirtyRect
{
    // draw the separator
    CGFloat lineWidth = dirtyRect.size.width - 2;
    CGFloat lineX = 0;
    CGFloat lineY = (dirtyRect.size.height - 2) / 2;
    lineY += 0.5;
    
    [[NSColor colorWithDeviceRed:.349 green:.6 blue:.898 alpha:0.6] set];
    NSRectFill(NSMakeRect(dirtyRect.origin.x + lineX, dirtyRect.origin.y + lineY, lineWidth, 1));
    
    [[NSColor colorWithDeviceRed:0.976 green:1.0 blue:1.0 alpha:1.0] set];
    NSRectFill(NSMakeRect(dirtyRect.origin.x + lineX, dirtyRect.origin.y + lineY + 1, lineWidth, 1));
}

@end
