//
//  ImageAndTextCell.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/5.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Subclass of NSTextFieldCell which can display text and an image simultaneously.
 */

import Cocoa

@objc(ImageAndTextCell)
class ImageAndTextCell: NSTextFieldCell {
    var myImage: NSImage?
    
    private let kImageOriginXOffset: CGFloat = 3
    private let kImageOriginYOffset: CGFloat = 1
    
    private let kTextOriginXOffset: CGFloat = 2
    private let kTextOriginYOffset: CGFloat = 2
    private let kTextHeightAdjust: CGFloat = 4
    
    
    // -------------------------------------------------------------------------------
    //	initTextCell:aString
    // -------------------------------------------------------------------------------
    @objc(initTextCell:)
    override init(textCell aString: String) {
        super.init(textCell: aString)
        // we want a smaller font
        self.font = NSFont.systemFontOfSize(NSFont.smallSystemFontSize())
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // -------------------------------------------------------------------------------
    //	copyWithZone:zone
    // -------------------------------------------------------------------------------
    override func copyWithZone(zone: NSZone) -> AnyObject {
        //###copyWithZone() does not work well with Swift ARC
        let _myImage = self.myImage
        self.myImage = nil
        let cell = super.copyWithZone(zone) as! ImageAndTextCell
        cell.myImage = _myImage
        return cell
    }
    
    // -------------------------------------------------------------------------------
    //	titleRectForBounds:cellRect
    //
    //	Returns the proper bound for the cell's title while being edited
    // -------------------------------------------------------------------------------
    override func titleRectForBounds(var cellRect: NSRect) -> NSRect {
        // the cell has an image: draw the normal item cell
        var imageFrame: NSRect = NSRect()
        
        let imageSize = self.myImage?.size ?? NSSize()
        NSDivideRect(cellRect, &imageFrame, &cellRect, 3 + imageSize.width, NSRectEdge.MinX)
        
        imageFrame.origin.x += kImageOriginXOffset
        imageFrame.origin.y -= kImageOriginYOffset
        imageFrame.size = imageSize
        
        imageFrame.origin.y += ceil((cellRect.size.height - imageFrame.size.height) / 2)
        
        var newFrame = cellRect
        newFrame.origin.x += kTextOriginXOffset
        newFrame.origin.y += kTextOriginYOffset
        newFrame.size.height -= kTextHeightAdjust
        
        return newFrame
    }
    
    // -------------------------------------------------------------------------------
    //	editWithFrame:inView:editor:delegate:event
    // -------------------------------------------------------------------------------
    override func editWithFrame(aRect: NSRect, inView controlView: NSView, editor textObj: NSText, delegate anObject: AnyObject?, event theEvent: NSEvent) {
        let textFrame = self.titleRectForBounds(aRect)
        super.editWithFrame(textFrame, inView: controlView, editor: textObj, delegate: anObject, event: theEvent)
    }
    
    // -------------------------------------------------------------------------------
    //	selectWithFrame:inView:editor:delegate:event:start:length
    // -------------------------------------------------------------------------------
    override func selectWithFrame(aRect: NSRect, inView controlView: NSView, editor textObj: NSText, delegate anObject: AnyObject?, start selStart: Int, length selLength: Int) {
        let textFrame = self.titleRectForBounds(aRect)
        super.selectWithFrame(textFrame, inView: controlView, editor: textObj, delegate: anObject, start: selStart, length: selLength)
    }
    
    // -------------------------------------------------------------------------------
    //	drawWithFrame:cellFrame:controlView
    // -------------------------------------------------------------------------------
    override func drawWithFrame(cellFrame: NSRect, inView controlView: NSView) {
        var newCellFrame = cellFrame
        
        if self.myImage != nil {
            var imageFrame: NSRect = NSRect()
            
            let imageSize = self.myImage!.size
            NSDivideRect(newCellFrame, &imageFrame, &newCellFrame, imageSize.width, NSRectEdge.MinX)
            if self.drawsBackground {
                self.backgroundColor?.set()
                NSRectFill(imageFrame)
            }
            
            imageFrame.origin.y += 2
            imageFrame.size = imageSize
            
            self.myImage!.drawInRect(imageFrame,
                fromRect: NSZeroRect,
                operation: .CompositeSourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: nil)
        }
        
        super.drawWithFrame(newCellFrame, inView: controlView)
    }
    
    // -------------------------------------------------------------------------------
    //	cellSize
    // -------------------------------------------------------------------------------
    override var cellSize: NSSize {
        var _cellSize = super.cellSize
        _cellSize.width += (self.myImage?.size.width ?? 0) + 3
        return _cellSize
    }
    
}