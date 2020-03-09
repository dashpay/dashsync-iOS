//
//  DSKey.h
//  DashSync
//
//  Created by Sam Westrich on 2/14/19.
//

#import "BigIntTypes.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSKeyType) {
    DSKeyType_Unknown = 0,
    DSKeyType_ECDSA = 1,
    DSKeyType_BLS = 2,
};

@class DSChain;

@interface DSKey : NSObject

@property (nullable, nonatomic, readonly) NSData *publicKeyData;
@property (nullable, nonatomic, readonly) NSData *secretKeyData;
@property (nonatomic, readonly) UInt160 hash160;
@property (nonatomic, readonly) NSString *secretKeyString;
@property (nonatomic, readonly) DSKeyType keyType;

- (BOOL)verify:(UInt256)messageDigest signatureData:(NSData *)signature;
- (NSString *)addressForChain:(DSChain *)chain;
+ (NSString *)randomAddressForChain:(DSChain *)chain;
+ (NSString *)addressWithPublicKeyData:(NSData *)data forChain:(DSChain *)chain;
- (NSString *_Nullable)privateKeyStringForChain:(DSChain *)chain;
+ (DSKey *)keyForPublicKeyData:(NSData *)data forKeyType:(DSKeyType)keyType onChain:(DSChain *)chain;
+ (DSKey *)keyForSecretKeyData:(NSData *)data forKeyType:(DSKeyType)keyType onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
