//
//  DSMutableOrderedDataKeyDictionary.h
//  DSMutableOrderedDataKeyDictionary
//
//  Created by Samuel Westrich on 19/12/08.
//  Copyright 2014 Samuel Westrich. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
//

#import <Foundation/Foundation.h>

@interface DSMutableOrderedDataKeyDictionary : NSObject <NSFastEnumeration>

- (id)initWithCapacity:(NSUInteger)capacity;
- (NSUInteger)count;
- (id)allObjects;
- (id)objectForKey:(id)aKey;
- (id)objectAtIndex:(NSUInteger)anIndex;
- (id)initWithMutableDictionary:(NSMutableDictionary<NSData*,id>*)mutableDictionary keyAscending:(BOOL)isKeyAscending;
- (void)setOrderedByKeyObject:(id)anObject forKey:(id)aKey;
- (void)addObject:(id)anObject forKey:(id)aKey;
- (void)removeObjectForKey:(id)aKey;
- (void)removeObjectAtIndex:(NSUInteger)anIndex;
- (void)addIndex:(NSString*)index;
- (id)keyForObject:(id)anObject;
- (id)keyForObjectInArray:(id)anObject;
- (NSUInteger)indexOfObject:(id)anObject;
- (id)keyAtIndex:(NSUInteger)anIndex;
- (NSEnumerator *)reverseKeyEnumerator;
- (void)removeAllObjects;

@end
