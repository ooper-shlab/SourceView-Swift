//
//  SeparatorView.swift
//  SourceView
//
//  Created by 開発 on 2015/10/24.
//
//
/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Custom view to draw a separator.
 */
import Cocoa

@objc(SeparatorView)
class SeparatorView: NSView {
    
    override func draw(_ dirtyRect: NSRect) {
        // draw the separator
        let lineWidth = dirtyRect.size.width - 2
        let lineX: CGFloat = 0
        var lineY = (dirtyRect.size.height - 2) / 2
        lineY += 0.5
        
        NSColor(deviceRed: 0.349, green: 0.6, blue: 0.898, alpha:0.6).set()
        NSRectFill(NSMakeRect(dirtyRect.origin.x + lineX, dirtyRect.origin.y + lineY, lineWidth, 1))
        
        NSColor(deviceRed: 0.976, green: 1.0, blue: 1.0, alpha: 1.0).set()
        NSRectFill(NSMakeRect(dirtyRect.origin.x + lineX, dirtyRect.origin.y + lineY + 1, lineWidth, 1))
    }
    
}
