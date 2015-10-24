/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Generic child node object used with NSOutlineView and NSTreeController.
 */

#import "ChildNode.h"

@implementation ChildNode

// -------------------------------------------------------------------------------
//	init
// -------------------------------------------------------------------------------
- (instancetype)init
{
	self = [super init];
	if (self != nil)
    {
		self.nodeTitle = @"";
	}
	return self;
}

// -------------------------------------------------------------------------------
//	mutableKeys
//
//	Maintain support for archiving and copying.
// -------------------------------------------------------------------------------
- (NSArray *)mutableKeys
{
    return [super.mutableKeys arrayByAddingObjectsFromArray:@[@"description"]];
}

@end
