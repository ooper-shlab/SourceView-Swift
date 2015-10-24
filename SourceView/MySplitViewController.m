/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller managing our split view interface
 */

#import "MySplitViewController.h"
#import "MyOutlineViewController.h"

@interface MySplitViewController ()

@property (nonatomic, strong) NSArray *verticalConstraints;
@property (nonatomic, strong) NSArray *horizontalConstraints;

@end


#pragma mark -

@implementation MySplitViewController

// -------------------------------------------------------------------------------
//	viewDidAppear
// -------------------------------------------------------------------------------
- (void)viewDidAppear
{
    [super viewDidAppear];
    
    // Note: we keep the left split view item from growing as the window grows by setting its holding priority to 200, and the right to 199.
    // The view with the lowest priority will be the first to take on additional width if the split view grows or shrinks.
    //
    
    // listen for selection changes from the NSOutlineView inside MyOutlineViewController
    // note: we start observing after our outline view is populated so we don't receive unnecessary notifications at startup
    //
    [self.outlineViewController.treeController addObserver:self
                                                  forKeyPath:@"selectedObjects"
                                                     options:NSKeyValueObservingOptionNew
                                                     context:nil];
}

- (void)dealloc
{
    // done listening for tree controller's selection
    [self.outlineViewController.treeController removeObserver:self forKeyPath:@"selectedObjects"];
}


#pragma mark - Detail View Controller Management

// -------------------------------------------------------------------------------
//	outlineViewController
// -------------------------------------------------------------------------------
- (MyOutlineViewController *)outlineViewController
{
    NSSplitViewItem *leftSplitViewItem = self.splitViewItems[0];
    return (MyOutlineViewController *)leftSplitViewItem.viewController;
}

// -------------------------------------------------------------------------------
//	detailViewController
// -------------------------------------------------------------------------------
- (NSViewController *)detailViewController
{
    NSSplitViewItem *rightSplitViewItem = self.splitViewItems[1];
    return (NSViewController *)rightSplitViewItem.viewController;
}

// -------------------------------------------------------------------------------
//	hasChildViewController
// -------------------------------------------------------------------------------
- (BOOL)hasChildViewController
{
    return self.detailViewController.childViewControllers.count > 0;
}

// -------------------------------------------------------------------------------
//	embedChildViewController:childViewController
// -------------------------------------------------------------------------------
- (void)embedChildViewController:(NSViewController *)childViewController
{
    // to embed a new child view controller we have to add it and its view, then setup auto layout contraints
    //
    NSViewController *currentDetailVC = [self detailViewController];
    [currentDetailVC addChildViewController:childViewController];
    [currentDetailVC.view addSubview:childViewController.view];
    
    NSDictionary *views = @{@"targetView": childViewController.view};
    _horizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[targetView]|"
                                                                     options:0
                                                                     metrics:0
                                                                       views:views];
    _verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[targetView]|"
                                                                   options:0
                                                                   metrics:0
                                                                     views:views];
    
    [NSLayoutConstraint activateConstraints:self.horizontalConstraints];
    [NSLayoutConstraint activateConstraints:self.verticalConstraints];
}

// -------------------------------------------------------------------------------
//	observeValueForKeyPath:ofObject:change:context
// -------------------------------------------------------------------------------
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"selectedObjects"])
    {
        NSViewController *currentDetailVC = [self detailViewController];
        
        NSTreeController *treeController = (NSTreeController *)object;
        
        // let the outline view controller handle the selection (helps us decide which detail view to use)
        NSViewController *vcForDetail = [[self outlineViewController] viewControllerForSelection:treeController.selectedNodes];
        if (vcForDetail != nil)
        {
            if ([self hasChildViewController] && currentDetailVC.childViewControllers[0] != vcForDetail)
            {
                // the incoming child view controller is different from the one we currently have,
                // remove the old one and add the new one
                //
                [currentDetailVC removeChildViewControllerAtIndex:0];
                [self.detailViewController.view.subviews[0] removeFromSuperview];
                
                [self embedChildViewController:vcForDetail];
            }
            else
            {
                if (![self hasChildViewController])
                {
                    // we don't have a child view controller so embed the new one
                    [self embedChildViewController:vcForDetail];
                }
            }
        }
        else
        {
            // we don't have a child view controller to embed (no selection), so remove current child view controller
            if ([self hasChildViewController])
            {
                [currentDetailVC removeChildViewControllerAtIndex:0];
                [self.detailViewController.view.subviews[0] removeFromSuperview];
            }
        }
    }
}

@end
