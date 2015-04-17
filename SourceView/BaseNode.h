/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Generic multi-use node object used with NSOutlineView and NSTreeController.
 */

#import <Cocoa/Cocoa.h>

@interface BaseNode : NSObject <NSCoding, NSCopying>

@property (strong) NSString *nodeTitle;
@property (strong) NSImage *nodeIcon;
@property (strong) NSMutableArray *children;
@property (strong) NSString *urlString;
@property (assign) BOOL isLeaf;

- (instancetype)initLeaf;

@property (NS_NONATOMIC_IOSONLY, getter=isDraggable, readonly) BOOL draggable;

- (NSComparisonResult)compare:(BaseNode *)aNode;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *mutableKeys;

- (NSDictionary *)dictionaryRepresentation;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

- (id)parentFromArray:(NSArray *)array;
- (void)removeObjectFromChildren:(id)obj;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *descendants;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *allChildLeafs;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *groupChildren;
- (BOOL)isDescendantOfOrOneOfNodes:(NSArray *)nodes;
- (BOOL)isDescendantOfNodes:(NSArray *)nodes;
- (NSIndexPath *)indexPathInArray:(NSArray *)array;

@end
