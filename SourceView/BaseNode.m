/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Generic multi-use node object used with NSOutlineView and NSTreeController.
 */

#import "BaseNode.h"

@implementation BaseNode

// -------------------------------------------------------------------------------
//	init
// -------------------------------------------------------------------------------
- (instancetype)init
{
	self = [super init];
    if (self != nil)
	{
        self.nodeTitle = @"BaseNode Untitled";
        
		self.children = [NSMutableArray array];
		[self setLeaf:NO];	// is container by default
	}
	return self;
}

// -------------------------------------------------------------------------------
//	initLeaf
// -------------------------------------------------------------------------------
- (instancetype)initLeaf
{
	self = [self init];
    if (self != nil)
	{
		[self setLeaf:YES];
	}
	return self;
}

// -------------------------------------------------------------------------------
//	setLeaf:flag
// -------------------------------------------------------------------------------
- (void)setLeaf:(BOOL)flag
{
	_isLeaf = flag;
	if (_isLeaf)
    {
		self.children = [NSMutableArray arrayWithObject:self];
    }
	else
    {
		self.children = [NSMutableArray array];
    }
}

// -------------------------------------------------------------------------------
//	isBookmark
// -------------------------------------------------------------------------------
- (BOOL)isBookmark
{
    return [self.urlString hasPrefix:@"http://"];
}

// -------------------------------------------------------------------------------
//	setIsBookmark:isBookmark
// -------------------------------------------------------------------------------
- (void)setIsBookmark:(BOOL)isBookmark
{
    self.isBookmark = isBookmark;
}

// -------------------------------------------------------------------------------
//	isDirectory
// -------------------------------------------------------------------------------
- (BOOL)isDirectory
{
    BOOL isDirectory = NO;
    
    if (self.urlString != nil)
    {
        NSNumber *isURLDirectory = nil;
        NSURL *url = [NSURL fileURLWithPath:self.urlString];
    
        [url getResourceValue:&isURLDirectory forKey:NSURLIsDirectoryKey error:nil];
    
        isDirectory = isURLDirectory.boolValue;
    }
    
    return isDirectory;
}

// -------------------------------------------------------------------------------
//	setIsBookmark:isBookmark
// -------------------------------------------------------------------------------
- (void)setIsDirectory:(BOOL)isDirectory
{
    self.isDirectory = isDirectory;
}

// -------------------------------------------------------------------------------
//	compare:aNode
// -------------------------------------------------------------------------------
- (NSComparisonResult)compare:(BaseNode *)aNode
{
	return [self.nodeTitle.lowercaseString compare:aNode.nodeTitle.lowercaseString];
}


#pragma mark - Drag and Drop

// -------------------------------------------------------------------------------
//	removeObjectFromChildren:obj
//
//	Recursive method which searches children and children of all sub-nodes
//	to remove the given object.
// -------------------------------------------------------------------------------
- (void)removeObjectFromChildren:(id)obj
{
	// remove object from children or the children of any sub-nodes
    for (id node in self.children)
	{
		if (node == obj)
		{
			[self.children removeObjectIdenticalTo:obj];
			return;
		}
		
		if (![node isLeaf])
        {
			[node removeObjectFromChildren:obj];
        }
	}
}

// -------------------------------------------------------------------------------
//	descendants
//
//	Generates an array of all descendants.
// -------------------------------------------------------------------------------
- (NSArray *)descendants
{
    NSMutableArray *descendants = [NSMutableArray array];
	id node = nil;
	for (node in self.children)
	{
		[descendants addObject:node];
		
		if (![node isLeaf])
        {
			[descendants addObjectsFromArray:[node descendants]];	// Recursive - will go down the chain to get all
        }
	}
	return descendants;
}

// -------------------------------------------------------------------------------
//	allChildLeafs:
//
//	Generates an array of all leafs in children and children of all sub-nodes.
//	Useful for generating a list of leaf-only nodes.
// -------------------------------------------------------------------------------
- (NSArray *)allChildLeafs
{
    NSMutableArray *childLeafs = [NSMutableArray array];
	id node = nil;
	
	for (node in self.children)
	{
		if ([node isLeaf])
        {
			[childLeafs addObject:node];
        }
		else
        {
			[childLeafs addObjectsFromArray:[node allChildLeafs]];	// Recursive - will go down the chain to get all
        }
	}
	return childLeafs;
}

// -------------------------------------------------------------------------------
//	groupChildren
//
//	Returns only the children that are group nodes.
// -------------------------------------------------------------------------------
- (NSArray *)groupChildren
{
    NSMutableArray *groupChildren = [NSMutableArray array];
	BaseNode *child;
	
	for (child in self.children)
	{
		if (!child.isLeaf)
        {
			[groupChildren addObject:child];
        }
	}
	return groupChildren;
}

// -------------------------------------------------------------------------------
//	isDescendantOfOrOneOfNodes:nodes
//
//	Returns YES if self is contained anywhere inside the children or children of
//	sub-nodes of the nodes contained inside the given array.
// -------------------------------------------------------------------------------
- (BOOL)isDescendantOfOrOneOfNodes:(NSArray *)nodes
{
    // returns YES if we are contained anywhere inside the array passed in, including inside sub-nodes
 	id node = nil;
    for (node in nodes)
	{
		if (node == self)
			return YES;		// we found ourselves
		
		// check all the sub-nodes
		if (![node isLeaf])
		{
			if ([self isDescendantOfOrOneOfNodes:[node children]])
				return YES;
		}
    }
	
    return NO;
}

// -------------------------------------------------------------------------------
//	isDescendantOfNodes:nodes
//
//	Returns YES if any node in the array passed in is an ancestor of ours.
// -------------------------------------------------------------------------------
- (BOOL)isDescendantOfNodes:(NSArray *)nodes
{
	id node = nil;
    for (node in nodes)
	{
		// check all the sub-nodes
		if (![node isLeaf])
		{
			if ([self isDescendantOfOrOneOfNodes:[node children]])
				return YES;
		}
    }
    
	return NO;
}


#pragma mark - Archiving And Copying Support

// -------------------------------------------------------------------------------
//	mutableKeys:
//
//	Override this method to maintain support for archiving and copying.
// -------------------------------------------------------------------------------
- (NSArray *)mutableKeys
{
	return @[   @"nodeTitle",
                @"isLeaf",		// isLeaf MUST come before children for initWithDictionary: to work
                @"children", 
                @"nodeIcon",
                @"urlString",
                @"isBookmark"];
}

// -------------------------------------------------------------------------------
//	initWithDictionary:dictionary
// -------------------------------------------------------------------------------
- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
	self = [self init];
    if (self != nil)
    {
        NSString *key;
        for (key in self.mutableKeys)
        {
            if ([key isEqualToString:@"children"])
            {
                if ([dictionary[@"isLeaf"] boolValue])
                    self.children = [NSMutableArray arrayWithObject:self];
                else
                {
                    NSArray *dictChildren = dictionary[key];
                    NSMutableArray *newChildren = [NSMutableArray array];
                    
                    for (id node in dictChildren)
                    {
                        id newNode = [[[self class] alloc] initWithDictionary:node];
                        [newChildren addObject:newNode];
                    }
                    self.children = newChildren;
                }
            }
            else
            {
                [self setValue:dictionary[key] forKey:key];
            }
        }
    }
	return self;
}

// -------------------------------------------------------------------------------
//	dictionaryRepresentation
// -------------------------------------------------------------------------------
- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	for (NSString *key in self.mutableKeys)
    {
		// convert all children to dictionaries
		if ([key isEqualToString:@"children"])
		{
			if (!self.isLeaf)
			{
				NSMutableArray *dictChildren = [NSMutableArray array];
				for (id node in self.children)
				{
					[dictChildren addObject:[node dictionaryRepresentation]];
				}
				
				dictionary[key] = dictChildren;
			}
		}
		else if ([self valueForKey:key])
		{
			dictionary[key] = [self valueForKey:key];
		}
	}
	return dictionary;
}

// -------------------------------------------------------------------------------
//	initWithCoder:coder
// -------------------------------------------------------------------------------
- (instancetype)initWithCoder:(NSCoder *)coder
{		
	self = [self init];
	if (self != nil)
    {
        for (NSString *key in self.mutableKeys)
            [self setValue:[coder decodeObjectForKey:key] forKey:key];
	}
	return self;
}

// -------------------------------------------------------------------------------
//	encodeWithCoder:coder
// -------------------------------------------------------------------------------
- (void)encodeWithCoder:(NSCoder *)coder
{
    for (NSString *key in self.mutableKeys)
    {
		[coder encodeObject:[self valueForKey:key] forKey:key];
    }
}

// -------------------------------------------------------------------------------
//	copyWithZone:zone
// -------------------------------------------------------------------------------
- (id)copyWithZone:(NSZone *)zone
{
	id newNode = [[[self class] allocWithZone:zone] init];
	
	for (NSString *key in self.mutableKeys)
    {
		[newNode setValue:[self valueForKey:key] forKey:key];
    }
	
	return newNode;
}

// -------------------------------------------------------------------------------
//	setNilValueForKey:key
//
//	Override this for any non-object values
// -------------------------------------------------------------------------------
- (void)setNilValueForKey:(NSString *)key
{
	if ([key isEqualToString:@"isLeaf"])
    {
		self.isLeaf = NO;
    }
	else
    {
		[super setNilValueForKey:key];
    }
}

@end
