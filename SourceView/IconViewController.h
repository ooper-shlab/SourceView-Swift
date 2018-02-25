/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller object to host the icon collection view.
 */

// notification for indicating file system content has been received
extern NSString *kReceivedContentNotification;

@class BaseNode;

@interface IconViewController : NSViewController

// This view controller can be populated two ways:
//    file system url, or from a BaseNode of internet shortcuts
//
@property (readwrite, strong) NSURL *url;
@property (readwrite, strong) BaseNode *baseNode;

@end
