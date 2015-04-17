/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Subclass of NSActionCell which displays a separator line.
 */

#import "SeparatorCell.h"

@implementation SeparatorCell

// -------------------------------------------------------------------------------
//	copyWithZone:zone
// -------------------------------------------------------------------------------
- (id)copyWithZone:(NSZone *)zone
{
    SeparatorCell *cell = (SeparatorCell*)[super copyWithZone:zone];
    return cell;
}

// -------------------------------------------------------------------------------
//	drawWithFrame:cellFrame:controlView:
// -------------------------------------------------------------------------------
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// draw the separator
	CGFloat lineWidth = cellFrame.size.width;
	CGFloat lineX = 0;
	CGFloat lineY = (cellFrame.size.height - 2) / 2;
	lineY += 0.5;

	[[NSColor colorWithDeviceRed:.349 green:.6 blue:.898 alpha:0.6] set];
	NSRectFill(NSMakeRect(cellFrame.origin.x + lineX, cellFrame.origin.y + lineY, lineWidth, 1));
	
	[[NSColor colorWithDeviceRed:0.976 green:1.0 blue:1.0 alpha:1.0] set];
	NSRectFill(NSMakeRect(cellFrame.origin.x + lineX, cellFrame.origin.y + lineY + 1, lineWidth, 1));
}

// -------------------------------------------------------------------------------
//	selectWithFrame:inView:editor:delegate:event:start:length
// -------------------------------------------------------------------------------
- (void)selectWithFrame:(NSRect)aRect inView:(NSView*)controlView editor:(NSText*)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
}

@end

