//
//  SecEnclaveCrypto.m
//  SecEnclaveCrypto
//
//  Created by Andrew Podkovyrin on 06.08.2021.
//

#import "SecEnclaveCrypto.h"

#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SecEnclaveCrypto

#pragma mark - Public

+ (BOOL)isAvailable {
    NSString *tmpName = [[NSUUID UUID] UUIDString];
    SecEnclaveCrypto *tmpCrypto = [[SecEnclaveCrypto alloc] init];

    NSError *createError = nil;
    SecKeyRef privateKey = [tmpCrypto createPrivateKeyWithName:tmpName error:&createError];
    if (privateKey == nil) {
        return NO;
    }

    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if (publicKey == nil) {
        CFRelease(privateKey);
        [tmpCrypto deletePrivateKeyWithName:tmpName];
        return NO;
    }

    BOOL canEncrypt = SecKeyIsAlgorithmSupported(publicKey, kSecKeyOperationTypeEncrypt, [self algorithm]);
    BOOL canDecrypt = SecKeyIsAlgorithmSupported(privateKey, kSecKeyOperationTypeDecrypt, [self algorithm]);

    CFRelease(publicKey);
    CFRelease(privateKey);
    [tmpCrypto deletePrivateKeyWithName:tmpName];

    return canEncrypt && canDecrypt;
}

- (BOOL)hasPrivateKeyName:(NSString *)name error:(NSError *_Nullable __autoreleasing *)error {
    NSError *checkError = nil;
    SecKeyRef privateKey = [self getPrivateKeyWithName:name error:&checkError];
    if (checkError.code == errSecItemNotFound) {
        return NO;
    }
    if (error && checkError) {
        *error = checkError;
        return NO;
    }
    return privateKey != nil;
}

- (nullable NSData *)encrypt:(NSData *)plainTextData
           withPublicKeyName:(NSString *)name
                       error:(NSError *_Nullable __autoreleasing *)error {
    NSError *getError = nil;
    SecKeyRef privateKey = [self getPrivateKeyWithName:name error:&getError];
    if (privateKey == nil) {
        privateKey = [self createPrivateKeyWithName:name error:error];
        if (privateKey == nil) {
            return nil;
        }
    }

    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    CFRelease(privateKey);
    if (publicKey == nil) {
        if (error) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:errSecPublicKeyInconsistent
                                     userInfo:nil];
        }
        return nil;
    }

    NSData *encrypted = [self encrypt:plainTextData withPublicKey:publicKey error:error];
    CFRelease(publicKey);
    return encrypted;
}

- (nullable NSData *)decrypt:(NSData *)cipherTextData
          withPrivateKeyName:(NSString *)name
                       error:(NSError *_Nullable __autoreleasing *)error {
    SecKeyRef privateKey = [self getPrivateKeyWithName:name error:error];
    if (privateKey == nil) {
        return nil;
    }

    NSData *decrypted = [self decrypt:cipherTextData withPrivateKey:privateKey error:error];
    CFRelease(privateKey);
    return decrypted;
}

- (void)deletePrivateKeyWithName:(NSString *)name {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassKey,
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrApplicationTag: [self tagDataFor:name],
    };

    __unused OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
}

#pragma mark - Private

- (NSData *)tagDataFor:(NSString *)name {
    return [name dataUsingEncoding:NSUTF8StringEncoding];
}

- (nullable SecKeyRef)getPrivateKeyWithName:(NSString *)name
                                      error:(NSError *_Nullable __autoreleasing *)error {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassKey,
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrApplicationTag: [self tagDataFor:name],
        (__bridge id)kSecReturnRef: @YES,
    };

    CFDataRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);

    if (status == errSecSuccess) {
        return (SecKeyRef)result;
    } else {
        if (error) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:status
                                     userInfo:nil];
        }
        return nil;
    }
}

- (NSInteger)getPrivateKeyCountWithName:(NSString *)name {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassKey,
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrApplicationTag: [self tagDataFor:name],
        (__bridge id)kSecReturnRef: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
    };

    CFArrayRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecSuccess) {
        NSInteger count = CFArrayGetCount(result);
        CFRelease(result);
        return count;
    } else {
        return 0;
    }
}

- (nullable NSData *)encrypt:(NSData *)plainTextData
               withPublicKey:(SecKeyRef)publicKey
                       error:(NSError *_Nullable __autoreleasing *)error {
    if (SecKeyIsAlgorithmSupported(publicKey, kSecKeyOperationTypeEncrypt, [self.class algorithm]) == NO) {
        if (error) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:errSecInvalidAlgorithm
                                     userInfo:nil];
        }
        return nil;
    }

    CFErrorRef cfError = nil;
    CFDataRef encrypted = SecKeyCreateEncryptedData(
        publicKey,
        [self.class algorithm],
        (CFDataRef)plainTextData,
        &cfError);
    NSData *result = CFBridgingRelease(encrypted);
    if (cfError && error) {
        *error = CFBridgingRelease(cfError);
        return nil;
    }
    return result;
}

- (nullable NSData *)decrypt:(NSData *)cipherTextData
              withPrivateKey:(SecKeyRef)privateKey
                       error:(NSError *_Nullable __autoreleasing *)error {
    if (SecKeyIsAlgorithmSupported(privateKey, kSecKeyOperationTypeDecrypt, [self.class algorithm]) == NO) {
        if (error) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:errSecInvalidAlgorithm
                                     userInfo:nil];
        }
        return nil;
    }

    CFErrorRef cfError = nil;
    CFDataRef decrypted = SecKeyCreateDecryptedData(
        privateKey,
        [self.class algorithm],
        (CFDataRef)cipherTextData,
        &cfError);
    NSData *result = CFBridgingRelease(decrypted);
    if (cfError && error) {
        *error = CFBridgingRelease(cfError);
        return nil;
    }
    return result;
}

- (nullable SecKeyRef)createPrivateKeyWithName:(NSString *)name
                                         error:(NSError *_Nullable __autoreleasing *)error {
    if ([self getPrivateKeyCountWithName:name] != 0) {
        return nil; // key already exists
    }

    CFErrorRef cfError = nil;
    SecAccessControlRef access = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAccessControlPrivateKeyUsage,
        &cfError);
    if (access == nil) {
        if (cfError && error) {
            *error = CFBridgingRelease(cfError);
        }
        return nil;
    }

    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithDictionary:@{
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrKeySizeInBits: @([self.class numberOfBitsInKey]),
        (__bridge id)kSecPrivateKeyAttrs: @{
            (__bridge id)kSecAttrIsPermanent: @YES,
            (__bridge id)kSecAttrApplicationTag: [self tagDataFor:name],
            (__bridge id)kSecAttrAccessControl: (__bridge id)access,
        },
    }];
    if ([self isSimulator] == NO) {
        query[(__bridge id)kSecAttrTokenID] = (__bridge id)kSecAttrTokenIDSecureEnclave;
    }

    SecKeyRef key = SecKeyCreateRandomKey((__bridge CFDictionaryRef)query, &cfError);
    CFRelease(access);
    if (key == nil) {
        if (cfError && error) {
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                         code:CFErrorGetCode(cfError)
                                     userInfo:nil];
        }
        return nil;
    }

    return key;
}

#pragma mark - Private Constants

+ (SecKeyAlgorithm)algorithm {
    // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/storing_keys_in_the_secure_enclave
    return kSecKeyAlgorithmECIESEncryptionCofactorVariableIVX963SHA256AESGCM;
}

+ (NSInteger)numberOfBitsInKey {
    return 256;
}

- (BOOL)isSimulator {
#if TARGET_OS_SIMULATOR
    return YES;
#else
    return NO;
#endif /* TARGET_OS_SIMULATOR */
}

@end

NS_ASSUME_NONNULL_END
