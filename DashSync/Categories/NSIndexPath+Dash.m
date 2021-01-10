//
//  NSIndexPath+Dash.m
//  AFNetworking
//
//  Created by Sam Westrich on 11/3/18.
//

#import "DSDerivationPath.h"
#import "NSIndexPath+Dash.h"

@implementation NSIndexPath (Dash)

- (NSIndexPath *)hardenAllItems {
    NSUInteger indexes[[self length]];
    [self getIndexes:indexes];
    for (int i = 0; i < [self length]; i++) {
        indexes[i] |= BIP32_HARD;
    }
    return [NSIndexPath indexPathWithIndexes:indexes length:self.length];
}

- (NSIndexPath *)softenAllItems {
    NSUInteger indexes[[self length]];
    [self getIndexes:indexes];
    for (int i = 0; i < [self length]; i++) {
        indexes[i] &= ~BIP32_HARD;
    }
    return [NSIndexPath indexPathWithIndexes:indexes length:self.length];
}

- (NSIndexPath *)indexPathByRemovingFirstIndex {
    if (self.length == 1) return [[NSIndexPath alloc] init];
    NSUInteger indexes[[self length]];
    [self getIndexes:indexes range:NSMakeRange(1, [self length] - 1)];
    return [NSIndexPath indexPathWithIndexes:indexes length:self.length - 1];
}

- (NSString *)indexPathString;
{
    if (!self.length) return @"";
    NSMutableString *indexString = [NSMutableString stringWithFormat:@"%lu", [self indexAtPosition:0]];
    for (int i = 1; i < [self length]; i++) {
        [indexString appendString:[NSString stringWithFormat:@".%lu", [self indexAtPosition:i]]];
    }
    return indexString;
}

@end
