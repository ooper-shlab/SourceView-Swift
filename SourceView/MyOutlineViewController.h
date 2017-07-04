/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The master view controller containing the NSOutlineView and NSTreeController.
 */

@interface MyOutlineViewController : NSViewController

@property (nonatomic, strong) IBOutlet NSTreeController *treeController;

// Used to instruct which view controller to use as the detail when the outline view item is selected.
- (NSViewController *)viewControllerForSelection:(NSArray *)selection;

@end
