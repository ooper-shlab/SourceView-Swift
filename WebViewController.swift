//
//  WebViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/24.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller hosting the web view.
 */

import Cocoa
import WebKit

@objc(WebViewController)
class WebViewController: NSViewController {
    
    var retargetWebView: Bool = false
    
    @IBOutlet weak var webView: WebView!
    
    // -------------------------------------------------------------------------------
    //	webView:makeFirstResponder
    //
    //	We want to keep the outline view in focus as the user clicks various URLs.
    //
    //	So this workaround applies to an unwanted side affect to some web pages that might have
    //	JavaScript code thatt focus their text fields as we target the web view with a particular URL.
    //
    // -------------------------------------------------------------------------------
    func webView(sender: WebView, makeFirstResponder responder: NSResponder) {
        if self.retargetWebView {
            // we are targeting the webview ourselves as a result of the user clicking
            // a url in our outlineview: don't do anything, but reset our target check flag
            //
            retargetWebView = false
        } else {
            // continue the responder chain
            self.view.window?.makeFirstResponder(sender)
        }
    }
    
}