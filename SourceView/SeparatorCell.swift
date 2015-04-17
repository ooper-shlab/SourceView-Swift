//
//  SeparatorCell.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/5.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Subclass of NSActionCell which displays a separator line.
 */

import Cocoa

@objc(SeparatorCell)
class SeparatorCell: NSTextFieldCell {
    
    // -------------------------------------------------------------------------------
    //	copyWithZone:zone
    // -------------------------------------------------------------------------------
    override func copyWithZone(zone: NSZone) -> AnyObject {
        let cell = super.copyWithZone(zone) as! SeparatorCell
        return cell
    }
    
    // -------------------------------------------------------------------------------
    //	drawWithFrame:cellFrame:controlView:
    // -------------------------------------------------------------------------------
    override func drawWithFrame(cellFrame: NSRect, inView controlView: NSView) {
        // draw the separator
        let lineWidth = cellFrame.size.width
        let lineX: CGFloat = 0
        var lineY = (cellFrame.size.height - 2) / 2
        lineY += 0.5
        
        NSColor(deviceRed: 0.349, green: 0.6, blue: 0.898, alpha: 0.6).set()
        NSRectFill(NSMakeRect(cellFrame.origin.x + lineX, cellFrame.origin.y + lineY, lineWidth, 1))
        
        NSColor(deviceRed: 0.976, green: 1.0, blue: 1.0, alpha: 1.0).set()
        NSRectFill(NSMakeRect(cellFrame.origin.x + lineX, cellFrame.origin.y + lineY + 1, lineWidth, 1))
    }
    
    // -------------------------------------------------------------------------------
    //	selectWithFrame:inView:editor:delegate:event:start:length
    // -------------------------------------------------------------------------------
    func selectWithFrame(aRect: NSRect, inView controlView: NSView, editor textObj: NSText, delegate anObject: AnyObject, start selStart: Int, lenght selLength: Int) {
    }
    
}