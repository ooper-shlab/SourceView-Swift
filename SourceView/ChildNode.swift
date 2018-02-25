//
//  ChildNode.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/5.
//
//
/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Generic child node object used with NSOutlineView and NSTreeController.
 */

import Cocoa

@objc(ChildNode)
class ChildNode: BaseNode {
    
    // -------------------------------------------------------------------------------
    //	init
    // -------------------------------------------------------------------------------
    required init() {
        super.init()
        self.nodeTitle = ""
    }
    
    // -------------------------------------------------------------------------------
    //	description
    // -------------------------------------------------------------------------------
    override class func description() -> String {
        return "ChildNode"
    }
    
    // -------------------------------------------------------------------------------
    //	mutableKeys
    //
    //	Maintain support for archiving and copying.
    // -------------------------------------------------------------------------------
    override var mutableKeys: [String] {
        return super.mutableKeys + ["description"]
    }
    
}
