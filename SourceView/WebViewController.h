/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller hosting the web view.
 */

@import WebKit;

@interface WebViewController : NSViewController

@property (assign) BOOL retargetWebView;

@property (nonatomic, weak) IBOutlet WebView *webView;

@end
