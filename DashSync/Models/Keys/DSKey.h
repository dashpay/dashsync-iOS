//
//  DSKey.h
//  DashSync
//
//  Created by Sam Westrich on 2/14/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain;

@interface DSKey : NSObject

@property (nullable, nonatomic, readonly) NSData *publicKeyData;
@property (nonatomic, readonly) UInt160 hash160;

- (NSString *)addressForChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
