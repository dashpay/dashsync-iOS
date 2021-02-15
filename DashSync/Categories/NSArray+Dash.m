//
//  NSArray+Dash.m
//  DashSync
//
//  Created by Sam Westrich on 11/21/19.
//

#import "NSArray+Dash.h"
#import "NSMutableData+Dash.h"

@implementation NSArray (Dash)

- (UInt256)hashDataComponents {
    NSMutableData *concatenatedData = [NSMutableData data];
    for (NSData *data in self) {
        [concatenatedData appendData:data];
    }
    return [concatenatedData SHA256];
}

- (UInt256)hashDataComponentsWithSelector:(SEL)hashFunction {
    NSMutableData *concatenatedData = [NSMutableData data];
    for (NSData *data in self) {
        [concatenatedData appendData:data];
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                                 [NSMutableData instanceMethodSignatureForSelector:hashFunction]];
    [invocation setSelector:hashFunction];
    [invocation setTarget:concatenatedData];
    [invocation invoke];
    UInt256 returnValue = UINT256_ZERO;
    [invocation getReturnValue:&returnValue];
    return returnValue;
}

- (NSArray *)transformToArrayOfHexStrings {
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSData *data in self) {
        NSAssert([data isKindOfClass:[NSData class]], @"all elements must be of type NSData");
        [mArray addObject:[data hexString]];
    }
    return [mArray copy];
}

@end
