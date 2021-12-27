//
//  NSArray+Dash.h
//  DashSync
//
//  Created by Sam Westrich on 11/21/19.
//

#import "BigIntTypes.h"
#import "NSData+Dash.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (Dash)

- (UInt256)hashDataComponents;
- (NSArray *)transformToArrayOfHexStrings;
- (UInt256)hashDataComponentsWithSelector:(SEL)hashFunction;
- (NSMutableArray *)secureMutableCopy;

- (NSArray *)map:(id (^)(id obj))block;

@end

NS_ASSUME_NONNULL_END
