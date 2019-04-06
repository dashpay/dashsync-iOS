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
@property (nonatomic,readonly) NSString * secretKeyString;

- (NSString *)addressForChain:(DSChain*)chain;
+ (NSString *)addressWithPublicKeyData:(NSData*)data forChain:(DSChain*)chain;
- (NSString * _Nullable)privateKeyStringForChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
