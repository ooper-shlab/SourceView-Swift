/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Generic multi-use node object used with NSOutlineView and NSTreeController.
 */

@interface BaseNode : NSObject <NSCoding, NSCopying>

#define kIconSmallImageSize  16.
#define kIconLargeImageSize  32.

// default grouping titles
+ (NSString *)placesName;
+ (NSString *)bookmarksName;
+ (NSString *)untitledName;    // node with not title set

@property (strong) NSString *nodeTitle;
@property (nonatomic, strong) NSImage *nodeIcon;
@property (strong) NSMutableArray *children;
@property (strong) NSURL *url;
@property (assign) BOOL isLeaf;
@property (assign) BOOL isBookmark;
@property (assign) BOOL isDirectory;

@property (readonly) BOOL isSpecialGroup;
@property (readonly) BOOL isSeparator;

- (instancetype)initLeaf;

@property (NS_NONATOMIC_IOSONLY, getter=isDraggable, readonly) BOOL draggable;

- (NSComparisonResult)compare:(BaseNode *)aNode;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *mutableKeys;

- (NSDictionary *)dictionaryRepresentation;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

- (void)removeObjectFromChildren:(id)obj;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *descendants;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *allChildLeafs;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *groupChildren;
- (BOOL)isDescendantOfOrOneOfNodes:(NSArray *)nodes;
- (BOOL)isDescendantOfNodes:(NSArray *)nodes;

@end
