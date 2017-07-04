# SourceView

## Description

"SourceView" demonstrates how to use NSOutlineView backed by NSTreeController and various other Cocoa classes to produce a Finder-like source view.  It also uses NSSplitViewController and a storyboard to organize the various NSViewControllers.

Among the features demonstrated are -

- Source outline view using view-based NSOutlineView
- Loading dictionary data from disk using [NSDictionary dictionaryWithContentsOfFile…] to populate the outline view,
- Outline view uses selection highlight style: NSTableViewSelectionHighlightStyleSourceList, which gives is a gradient-style selection.
- Icon view of directories using NSCollectionView,
- Viewing URLs using WebView,
- Outline view drag and drop support for URLs and file system-based objects (from Safari, Finder, etc),
- Factoring or organizing its various NSViews into NSViewControllers.
- Factoring or organizing its various Windows into NSWindowControllers.
- Obtaining file system icons using NSWorkspace,
- NSSplitView controlled by NSSplitViewController sub-pane size management during divider resize,
- Using template images in our buttons such as NSImageNameAddTemplate and NSImageNameRemoveTemplate

## Build Requirements

macOS 10.12 SDK or later

## Runtime Requirements

OS X 10.10 or later

## Using the Sample

The Bookmarks section is determined the external Outline.dict file, read in as a NSDictionary and populated into the NSOutlineView.
You can experiment on your own with adding and removing items in this file.


Copyright (C) 2007-2017, Apple Inc. All rights reserved.
