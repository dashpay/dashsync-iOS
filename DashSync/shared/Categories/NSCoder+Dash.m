//
//  NSCoder+Dash.m
//  DashSync
//
//  Created by Sam Westrich on 5/19/18.
//

#import "BigIntTypes.h"
#import "NSCoder+Dash.h"
#import "NSData+Dash.h"

@implementation NSCoder (Dash)

- (void)encodeUInt256:(UInt256)value forKey:(NSString *)string {
    [self encodeObject:[NSData dataWithUInt256:value] forKey:string];
}

- (UInt256)decodeUInt256ForKey:(NSString *)string {
    NSData *data = [self decodeObjectOfClass:[NSData class] forKey:string];
    if (!data.length) return UINT256_ZERO;
    return data.UInt256;
}

@end
