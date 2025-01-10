//
//  DSTransition.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransition.h"
#import "BigIntTypes.h"
#import "DSIdentity.h"
#import "DSIdentityRegistrationTransition.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSKeyManager.h"
#import "DSTransition+Protected.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import <TinyCborObjc/NSData+DSCborDecoding.h>

@interface DSTransition ()

@property (nonatomic, strong) DSIdentityRegistrationTransition *identityRegistrationTransaction;

@end

@implementation DSTransition

@synthesize chain = _chain;

- (instancetype)initOnChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    _version = TS_VERSION;
    _chain = chain;
    self.saved = FALSE;
    self.createdTimestamp = [NSDate timeIntervalSince1970];
    return self;
}

- (instancetype)initWithData:(NSData *)data onChain:(DSChain *)chain {
    if (!(self = [self initOnChain:chain])) return nil;
    NSError *error = nil;
    _keyValueDictionary = [data ds_decodeCborError:&error];
    if (error || !_keyValueDictionary) return nil;
    [self applyKeyValueDictionary:_keyValueDictionary];
    return self;
}

- (instancetype)initWithTransitionVersion:(uint16_t)version identityUniqueId:(UInt256)identityUniqueId onChain:(DSChain *_Nonnull)chain {
    NSParameterAssert(chain);

    if (!(self = [self initOnChain:chain])) return nil;
    self.type = DSTransitionType_Documents;
    self.version = version;
    self.identityUniqueId = identityUniqueId;
    return self;
}

- (BOOL)checkTransitionSignature:(DOpaqueKey *)key {
    return [DSKeyManager verifyMessageDigest:key digest:[self serializedBaseDataHash].UInt256 signature:self.signatureData];
}

- (BOOL)checkTransitionSignedByIdentity:(DSIdentity *)identity {
    return [identity verifySignature:self.signatureData
                              ofType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor()
                    forMessageDigest:[self serializedBaseDataHash].UInt256];
}

- (void)signWithKey:(DMaybeOpaqueKey *)privateKey
            atIndex:(uint32_t)index
       fromIdentity:(DSIdentity *)identity {
    NSParameterAssert(privateKey);
    if ([self isKindOfClass:[DSIdentityRegistrationTransition class]]) {
        NSAssert(index == UINT32_MAX, @"index must not exist");
    } else {
        NSAssert(index != UINT32_MAX, @"index must exist");
    }
    //ATTENTION If this ever changes from ECDSA, change the max signature size defined above
//    DSLogPrivate(@"Private Key is %@", [privateKey serializedPrivateKeyForChain:self.chain]);
//    DSLogPrivate(@"Signing %@ with key %@", [self serializedBaseDataHash].hexString, privateKey.publicKeyData.hexString);
//    dash_spv_crypto_keys_key_OpaqueKey_kind(privateKey);
//    self.signatureType = (KeyKind) privateKey->tag;
    self.signatureData = [DSKeyManager signMesasageDigest:privateKey->ok digest:[self serializedBaseDataHash].UInt256];
    self.signaturePublicKeyId = index;
    self.transitionHash = self.data.SHA256;
}

// size in bytes if signed, or estimated size assuming compact pubkey sigs
- (size_t)size {
    if (uint256_is_not_zero(_transitionHash)) return self.data.length;
    return [self serialized].length; //todo figure this out (probably wrong)
}

- (NSData *)toData {
    return [self serialized];
}

@synthesize keyValueDictionary = _keyValueDictionary;

- (DSMutableStringValueDictionary *)baseKeyValueDictionary {
    DSMutableStringValueDictionary *json = [[DSMutableStringValueDictionary alloc] init];
    //json[@"protocolVersion"] = @(self.chain.platformProtocolVersion);
    json[@"type"] = @(self.type);
    return json;
}

- (DSMutableStringValueDictionary *)keyValueDictionary {
    if (_keyValueDictionary == nil) {
        DSMutableStringValueDictionary *json = [self baseKeyValueDictionary];
        json[@"signature"] = self.signatureData;
        if (self.signaturePublicKeyId != UINT32_MAX) {
            json[@"signaturePublicKeyId"] = @(self.signaturePublicKeyId);
        }
        _keyValueDictionary = json;
    }
    return _keyValueDictionary;
}

- (void)applyKeyValueDictionary:(DSMutableStringValueDictionary *)keyValueDictionary {
    _keyValueDictionary = keyValueDictionary;
    self.signatureData = keyValueDictionary[@"signature"];
    self.signaturePublicKeyId = [keyValueDictionary[@"signaturePublicKeyId"] unsignedIntValue];
}

@end
