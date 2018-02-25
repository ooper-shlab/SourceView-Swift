//
//  WebViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/24.
//
//
/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller hosting the web view.
 */

import Cocoa
import WebKit

@objc(WebViewController)
class WebViewController: NSViewController, WebResourceLoadDelegate {
    
    func webView(_ sender: WebView!, resource identifier: Any!, didFailLoadingWithError error: Error!, from dataSource: WebDataSource!) {
        if let error = error as NSError? {
            // An error occurred, provide an error message to the user.
            let page = error.userInfo[NSURLErrorFailingURLStringErrorKey] as! String
            let errorContent = "<!DOCTYPE html><html><body><head></head><center><br><br><font color=red>Error: unable to load page:<br>'\(page)'</font></center></body></html>"
            
            sender.mainFrame.loadHTMLString(errorContent, baseURL: Bundle.main.bundleURL)
        }
    }
    
}
