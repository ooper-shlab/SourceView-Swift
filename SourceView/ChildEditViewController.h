/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller object for the edit bookmark sheet.
 */

// keys to use to obtain the name and url values from the returned NSDictionary
#define kName_Key @"name"
#define kURL_Key @"url"

@interface ChildEditViewController : NSViewController

@property (nonatomic, strong) NSDictionary *savedValues;

@end
