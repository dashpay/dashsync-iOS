//
//  DSTransition.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransition+Protected.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSBLSKey.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentity.h"
#import "DSTransition.h"
#import "NSDate+Utils.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"
#import <TinyCborObjc/NSData+DSCborDecoding.h>

@interface DSTransition()

@property (nonatomic, strong) DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction;

@property (nonatomic, strong) DSChain * chain;

@end

@implementation DSTransition

- (instancetype)initOnChain:(DSChain*)chain
{
    if (! (self = [super init])) return nil;
    
    _version = TS_VERSION;
    self.chain = chain;
    self.saved = FALSE;
    self.createdTimestamp = [NSDate timeIntervalSince1970];
    return self;
}

-(instancetype)initWithData:(NSData*)data onChain:(DSChain*)chain {
    if (! (self = [self initOnChain:chain])) return nil;
    NSError * error = nil;
    _keyValueDictionary = [data ds_decodeCborError:&error];
    if (error || !_keyValueDictionary) {
        return nil;
    }
    [self applyKeyValueDictionary:_keyValueDictionary];
    return self;
}

-(instancetype)initWithTransitionVersion:(uint16_t)version blockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId onChain:(DSChain * _Nonnull)chain {
    NSParameterAssert(chain);
    
    if (!(self = [self initOnChain:chain])) return nil;
    self.type = DSTransitionType_Documents;
    self.version = version;
    self.blockchainIdentityUniqueId = blockchainIdentityUniqueId;
    return self;
}

-(BOOL)checkTransitionSignatureForECDSAKey:(DSECDSAKey*)transitionRecoveredPublicKey {
    return [transitionRecoveredPublicKey verify:[self serializedBaseDataHash].UInt256 signatureData:self.signatureData];
    //return uint160_eq([transitionRecoveredPublicKey hash160], self.blockchainIdentityRegistrationTransaction.pubkeyHash);
}

-(BOOL)checkTransitionSignatureForBLSKey:(DSBLSKey*)blockchainIdentityPublicKey {
    return [blockchainIdentityPublicKey verify:[self serializedBaseDataHash].UInt256 signature:self.signatureData.UInt768];
}

-(BOOL)checkTransitionSignature:(DSKey*)key {
    if ([key isMemberOfClass:[DSECDSAKey class]]) {
        return [self checkTransitionSignatureForECDSAKey:(DSECDSAKey*)key];
    } else if ([key isMemberOfClass:[DSBLSKey class]]) {
        return [self checkTransitionSignatureForBLSKey:(DSBLSKey*)key];
    }
    NSAssert(FALSE, @"unimplemented key type");
    return FALSE;
}

-(BOOL)checkTransitionSignedByBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    return [blockchainIdentity verifySignature:self.signatureData ofType:DSKeyType_ECDSA forMessageDigest:[self serializedBaseDataHash].UInt256];
}

-(void)signWithKey:(DSKey*)privateKey atIndex:(uint32_t)index fromIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    NSParameterAssert(privateKey);
    if ([self isKindOfClass:[DSBlockchainIdentityRegistrationTransition class]]) {
        NSAssert(index == UINT32_MAX, @"index must not exist");
    } else {
        NSAssert(index != UINT32_MAX, @"index must exist");
    }
    //ATTENTION If this ever changes from ECDSA, change the max signature size defined above
    DSLogPrivate(@"Private Key is %@",[privateKey serializedPrivateKeyForChain:self.chain]);
    DSLogPrivate(@"Signing %@ with key %@",[self serializedBaseDataHash].hexString,privateKey.publicKeyData.hexString);
    if ([privateKey isMemberOfClass:[DSBLSKey class]]) {
        self.signatureType = DSKeyType_BLS;
        self.signatureData = uint768_data([((DSBLSKey*)privateKey) signDigest:[self serializedBaseDataHash].UInt256]);
    } else if ([privateKey isMemberOfClass:[DSECDSAKey class]]) {
        self.signatureType = DSKeyType_ECDSA;
        self.signatureData = [((DSECDSAKey*)privateKey) compactSign:[self serializedBaseDataHash].UInt256];
    }
    self.signaturePublicKeyId = index;
    self.transitionHash = self.data.SHA256_2;
}

// size in bytes if signed, or estimated size assuming compact pubkey sigs
- (size_t)size
{
    if (! uint256_is_zero(_transitionHash)) return self.data.length;
    return [self serialized].length; //todo figure this out (probably wrong)
}

- (NSData *)toData
{
    return [self serialized];
}

@synthesize keyValueDictionary = _keyValueDictionary;

- (DSMutableStringValueDictionary *)baseKeyValueDictionary {
    DSMutableStringValueDictionary *json = [[DSMutableStringValueDictionary alloc] init];
    json[@"protocolVersion"] = @(0);
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

-(void)applyKeyValueDictionary:(DSMutableStringValueDictionary *)keyValueDictionary {
    _keyValueDictionary = keyValueDictionary;
    self.signatureData = keyValueDictionary[@"signature"];
    self.signaturePublicKeyId = [keyValueDictionary[@"signaturePublicKeyId"] unsignedIntValue];
}

@end
