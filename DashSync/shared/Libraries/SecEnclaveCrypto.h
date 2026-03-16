//
//  SecEnclaveCrypto.h
//  SecEnclaveCrypto
//
//  Created by Andrew Podkovyrin on 06.08.2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SecEnclaveCrypto : NSObject

+ (BOOL)isAvailable;

- (BOOL)hasPrivateKeyName:(NSString *)name
                    error:(NSError *_Nullable __autoreleasing *)error;

- (nullable NSData *)encrypt:(NSData *)plainTextData
           withPublicKeyName:(NSString *)name
                       error:(NSError *_Nullable __autoreleasing *)error;

- (nullable NSData *)decrypt:(NSData *)cipherTextData
          withPrivateKeyName:(NSString *)name
                       error:(NSError *_Nullable __autoreleasing *)error;

- (void)deletePrivateKeyWithName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
