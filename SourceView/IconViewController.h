/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller object to host the icon collection view.
 */

// notification for indicating file system content has been received
extern NSString *kReceivedContentNotification;

@interface IconViewController : NSViewController

@property (readwrite, strong) NSURL *url;
	
@end
