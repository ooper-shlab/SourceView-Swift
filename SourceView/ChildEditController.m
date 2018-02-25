/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Controller object for the edit sheet panel.
 */

#import "ChildEditController.h"
#import "MyWindowController.h"

@interface ChildEditController ()
{
	BOOL cancelled;
	NSDictionary *savedFields;
	
	IBOutlet NSButton *doneButton;
    IBOutlet NSTextField *nameField;
    IBOutlet NSTextField *urlField;
}
@end

#pragma mark -

@implementation ChildEditController

// -------------------------------------------------------------------------------
//	windowNibName
// -------------------------------------------------------------------------------
- (NSString *)windowNibName
{
	return @"ChildEdit";
}

// -------------------------------------------------------------------------------
//	edit:startingValues:from
// -------------------------------------------------------------------------------
- (NSDictionary *)edit:(NSDictionary *)startingValues from:(MyWindowController *)sender
{
	cancelled = NO;

    if (startingValues != nil)
    {
        // we are editing current entry, use its values as the default
        savedFields = startingValues;
        
        nameField.stringValue = startingValues[@"name"];
        urlField.stringValue = startingValues[@"url"];
    }
    else
    {
        // we are adding a new entry,
        // make sure the form fields are empty due to the fact that this controller is recycled
        // each time the user opens the sheet -
        //
        nameField.stringValue = @"";
        urlField.stringValue = @"";
    }
    
    [nameField becomeFirstResponder];
    
    NSWindow *window = [self window];
    [NSApp beginSheet:window modalForWindow:[sender window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
    
    // done button enabled only if both edit fields have text
    doneButton.enabled = (nameField.stringValue.length > 0 && urlField.stringValue.length > 0);

	[NSApp runModalForWindow:window];
	// sheet is up here...

	[NSApp endSheet:window];
	[window orderOut:self];

	return savedFields;
}

// -------------------------------------------------------------------------------
//	done:sender
// -------------------------------------------------------------------------------
- (IBAction)done:(id)sender
{
    NSString *urlStr;
    if (![[urlField stringValue] hasPrefix:@"http://"])
    {
        urlStr = [NSString stringWithFormat:@"http://%@", [urlField stringValue]];
    }
    else
    {
        urlStr = [urlField stringValue];
    }
    savedFields = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                   [nameField stringValue], @"name",
                   urlStr, @"url",
                   nil];

	[NSApp stopModal];
}

// -------------------------------------------------------------------------------
//	cancel:sender
// -------------------------------------------------------------------------------
- (IBAction)cancel:(id)sender
{
	[NSApp stopModal];
	cancelled = YES;
}

// -------------------------------------------------------------------------------
//	wasCancelled:
// -------------------------------------------------------------------------------
- (BOOL)wasCancelled
{
	return cancelled;
}

// -------------------------------------------------------------------------------
//	controlTextDidChange:obj
//
//  for this to be called, we need to be a delegate to both NSTextFields
// -------------------------------------------------------------------------------
- (void)controlTextDidChange:(NSNotification *)obj
{
    doneButton.enabled = (nameField.stringValue.length > 0 && urlField.stringValue.length > 0);
}

@end