/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller object for the edit bookmark sheet.
 */

#import "ChildEditViewController.h"

@interface ChildEditViewController ()

@property (nonatomic, weak) IBOutlet NSButton *doneButton;
@property (nonatomic, weak) IBOutlet NSTextField *nameField;
@property (nonatomic, weak) IBOutlet NSTextField *urlField;

@end


#pragma mark -

@implementation ChildEditViewController

// -------------------------------------------------------------------------------
//	viewWillAppear
// -------------------------------------------------------------------------------
- (void)viewWillAppear
{
    [super viewWillAppear];
 
    self.nameField.stringValue = self.savedValues[kName_Key];
    self.urlField.stringValue = self.savedValues[kURL_Key];
    self.doneButton.enabled = [self doneAllowed];
}

// -------------------------------------------------------------------------------
//	doneAllowed
// -------------------------------------------------------------------------------
- (BOOL)doneAllowed
{
    return (self.nameField.stringValue.length > 0 && self.urlField.stringValue.length > 0);
}

// -------------------------------------------------------------------------------
//	done:sender
// -------------------------------------------------------------------------------
- (IBAction)done:(id)sender
{
    // add the http prefix if the user forgot to
    NSString *urlStr;
    if (![self.urlField.stringValue hasPrefix:HTTP_PREFIX])
    {
        urlStr = [NSString stringWithFormat:@"%@%@", HTTP_PREFIX, self.urlField.stringValue];
    }
    else
    {
        urlStr = self.urlField.stringValue;
    }
    _savedValues = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        self.nameField.stringValue, kName_Key,
                        [NSURL URLWithString:urlStr], kURL_Key,
                   nil];
    [self clearValues];
    
    [self.view.window.sheetParent endSheet:self.view.window returnCode:NSModalResponseOK];
}

// -------------------------------------------------------------------------------
//	clearValues
// -------------------------------------------------------------------------------
- (void)clearValues
{
    self.nameField.stringValue = self.urlField.stringValue = @"";
}

// -------------------------------------------------------------------------------
//	cancel:sender
// -------------------------------------------------------------------------------
- (IBAction)cancel:(id)sender
{
    [self clearValues];
    [self.view.window.sheetParent endSheet:self.view.window returnCode:NSModalResponseCancel];
}

// -------------------------------------------------------------------------------
//	controlTextDidChange:obj
//
//  For this to be called, we need to be a delegate to both NSTextFields
// -------------------------------------------------------------------------------
- (void)controlTextDidChange:(NSNotification *)obj
{
    self.doneButton.enabled = [self doneAllowed];
}

@end