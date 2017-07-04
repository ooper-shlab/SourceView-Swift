/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller hosting the web view.
 */

#import "WebViewController.h"

@interface WebViewController () <WebResourceLoadDelegate>

@end

@implementation WebViewController

- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource
{
    if (error != nil)
    {
        // An error occurred, provide an error message to the user.
        NSString *page = error.userInfo[NSURLErrorFailingURLStringErrorKey];
        NSString *errorContent = [NSString stringWithFormat:@"<!DOCTYPE html><html><body><head></head><center><br><br><font color=red>Error: unable to load page:<br>'%@'</font></center></body></html>", page];
 
        [((WebView *)sender).mainFrame loadHTMLString:errorContent baseURL:[NSBundle mainBundle].bundleURL];
    }
}

@end
