/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The master view controller containing the NSOutlineView and NSTreeController
 */

@interface MyOutlineViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSTreeController *treeController;

- (NSViewController *)viewControllerForSelection:(NSArray *)selection;

@end
