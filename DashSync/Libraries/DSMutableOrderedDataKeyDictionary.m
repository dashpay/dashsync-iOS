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

#import "DSMutableOrderedDataKeyDictionary.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"

@interface DSMutableOrderedDataKeyDictionary ()

@property (nonatomic, strong) NSMutableDictionary<NSData *, id> *dictionary;
@property (nonatomic, strong) NSMutableArray *array;
@property (nonatomic, strong) NSMutableDictionary *indexes;
@property (nonatomic, assign) BOOL isAscending;

@end

@implementation DSMutableOrderedDataKeyDictionary

- (id)init {
    self = [super init];
    if (self != nil) {
        _dictionary = [[NSMutableDictionary alloc] init];
        _array = [[NSMutableArray alloc] init];
        _indexes = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWithCapacity:(NSUInteger)capacity {
    self = [super init];
    if (self != nil) {
        _dictionary = [[NSMutableDictionary alloc] initWithCapacity:capacity];
        _array = [[NSMutableArray alloc] initWithCapacity:capacity];
        _indexes = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWithMutableDictionary:(NSMutableDictionary *)mutableDictionary keyAscending:(BOOL)isKeyAscending {
    _dictionary = mutableDictionary;
    _isAscending = isKeyAscending;
    _array = [[[mutableDictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSData *data1 = obj1;
        NSData *data2 = obj2;
        UInt256 value1 = [data1 UInt256];
        UInt256 value2 = [data2 UInt256];
        return (uint256_sup(value2, value1) ? (isKeyAscending ? NSOrderedAscending : NSOrderedDescending) : (uint256_eq(value1, value2) ? NSOrderedSame : (isKeyAscending ? NSOrderedDescending : NSOrderedAscending)));
    }] mutableCopy];
    return self;
}

- (id)copy {
    DSMutableOrderedDataKeyDictionary *copy = [[DSMutableOrderedDataKeyDictionary alloc] init];
    copy.dictionary = [_dictionary copy];
    copy.array = [_array copy];
    copy.isAscending = _isAscending;
    return copy;
}

- (NSUInteger)count {
    return [_dictionary count];
}

- (id)keyForObject:(id)anObject {
    for (NSData *key in _dictionary) {
        if (anObject == [_dictionary objectForKey:key]) {
            return key;
        }
    }
    return nil;
}

- (id)keyForObjectInArray:(id)anObject {
    for (NSData *key in _dictionary) {
        if ([[_dictionary objectForKey:key] containsObject:anObject]) {
            return key;
        }
    }
    return nil;
}


- (NSUInteger)indexOfObject:(id)anObject {
    return [_array indexOfObject:[self keyForObject:anObject]];
}

- (void)setOrderedByKeyObject:(id)anObject forKey:(id)aKey {
    if (![_dictionary objectForKey:aKey]) {

        NSInteger index = 0;
        if ([_array count]) {
            while ((index < [_array count]) && ([[_array objectAtIndex:index] longLongValue] < [aKey longLongValue])) {
                index++;
            }
        }
        [_array insertObject:aKey atIndex:index];
    }
    [_dictionary setObject:anObject forKey:aKey];
}

- (void)addObject:(id)anObject forKey:(id)aKey {
    if (![_dictionary objectForKey:aKey]) {
        [_array addObject:aKey];
    }
    [_dictionary setObject:anObject forKey:aKey];
}

- (void)removeObjectForKey:(id)aKey {
    [_dictionary removeObjectForKey:aKey];
    [_array removeObject:aKey];
}

- (void)removeObjectAtIndex:(NSUInteger)anIndex {
    NSData *aKey = [_array objectAtIndex:anIndex];
    [_dictionary removeObjectForKey:aKey];
    [_array removeObjectAtIndex:anIndex];
}

- (id)allObjects {
    return [_dictionary allValues];
}

- (id)objectForKey:(id)aKey {
    return [_dictionary objectForKey:aKey];
}

- (id)objectAtIndex:(NSUInteger)anIndex {
    return [_dictionary objectForKey:[self keyAtIndex:anIndex]];
}

- (NSEnumerator *)keyEnumerator {
    return [_array objectEnumerator];
}

- (NSEnumerator *)reverseKeyEnumerator {
    return [_array reverseObjectEnumerator];
}

- (void)insertObject:(id)anObject forKey:(id)aKey atIndex:(NSUInteger)anIndex {
    if ([_dictionary objectForKey:aKey]) {
        [self removeObjectForKey:aKey];
    }
    [_array insertObject:aKey atIndex:anIndex];
    [_dictionary setObject:anObject forKey:aKey];
}

- (id)keyAtIndex:(NSUInteger)anIndex {
    return [_array objectAtIndex:anIndex];
}

- (NSString *)descriptionOfObject:(NSObject *)object forLocale:(id)locale atLevel:(NSInteger)indentationLevel {
    NSString *objectString;
    if ([object isKindOfClass:[NSString class]]) {
        objectString = (NSString *)object;
    }
    else if ([object isKindOfClass:[NSArray class]]) {
        NSMutableString *indentationString = [NSMutableString string];
        NSUInteger i, count = indentationLevel;
        for (i = 0; i < count; i++) {
            [indentationString appendFormat:@"    "];
        }

        NSMutableString *description = [NSMutableString string];
        [description appendFormat:@"%@{\n", indentationString];
        for (NSObject *subObject in (NSArray *)object) {
            [description appendFormat:@"%@    %@;\n", indentationString, [self descriptionOfObject:subObject forLocale:locale atLevel:indentationLevel]];
        }
        [description appendFormat:@"%@}\n", indentationString];
        objectString = description;
    }
    else if ([object respondsToSelector:@selector(descriptionWithLocale:indent:)]) {
        objectString = [(NSDictionary *)object descriptionWithLocale:locale indent:indentationLevel];
    }
    else if ([object respondsToSelector:@selector(descriptionWithLocale:)]) {
        objectString = [(NSSet *)object descriptionWithLocale:locale];
    }
    else {
        objectString = [object description];
    }
    return objectString;
}

- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level {
    NSMutableString *indentationString = [NSMutableString string];
    NSUInteger i, count = level;
    for (i = 0; i < count; i++) {
        [indentationString appendFormat:@"    "];
    }

    NSMutableString *description = [NSMutableString string];
    [description appendFormat:@"%@{\n", indentationString];
    for (NSObject *key in _dictionary) {
        [description appendFormat:@"%@    %@ = %@;\n", indentationString, [self descriptionOfObject:key forLocale:locale atLevel:level], [self descriptionOfObject:[self objectForKey:key] forLocale:locale atLevel:level]];
    }
    [description appendFormat:@"%@}\n", indentationString];
    return description;
}

- (NSString *)description {
    return [self descriptionWithLocale:[NSLocale currentLocale] indent:0];
}

- (void)removeAllObjects {
    [_dictionary removeAllObjects];
    [_array removeAllObjects];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained[])buffer count:(NSUInteger)len {
    return [_array countByEnumeratingWithState:state objects:buffer count:len];
}

- (void)addIndex:(NSString *)index {
    if (!self.indexes[index]) {
        self.indexes[index] = [NSMutableDictionary dictionary];
        [self applyIndex:index];
    }
}

- (void)applyIndex:(NSString *)index {
    NSMutableDictionary *mutableDictionary = self.indexes[index];
    [mutableDictionary removeAllObjects];
    for (NSData *data in self) {
        id object = [self objectForKey:data];
        NSValue *value = [object valueForKey:index];
        self.indexes[index][value] = data;
    }
}

@end
