//
//  NSIndexPath+Dash.m
//  AFNetworking
//
//  Created by Sam Westrich on 11/3/18.
//

#import "NSIndexPath+Dash.h"

@implementation NSIndexPath (Dash)

-(NSIndexPath*)indexPathByRemovingFirstIndex {
    NSUInteger indexes[[self length]];
    [self getIndexes:indexes range:NSMakeRange(1, [self length] - 1)];
    return nil;
}

@end
