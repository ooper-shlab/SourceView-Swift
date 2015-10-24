//
//  AppDelegate.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/17.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 The sample's application delegate object (NSApplicationDelegate)
 */

import Cocoa

@NSApplicationMain
@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // -------------------------------------------------------------------------------
    //	applicationShouldTerminateAfterLastWindowClosed:sender
    //
    //	NSApplication delegate method placed here so the sample conveniently quits
    //	after we close the window.
    // -------------------------------------------------------------------------------
    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        return true
    }
    
}