//
//  DSBlockchainIdentityRegistrationTransition.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSBlockchainIdentityRegistrationTransition.h"
#import "BigIntTypes.h"
#import "DSCreditFundingTransaction.h"
#import "DSInstantSendTransactionLock.h"
#import "DSKeyManager.h"
#import "DSTransaction+Protected.h"
#import "DSTransactionFactory.h"
#import "DSTransition+Protected.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSBlockchainIdentityRegistrationTransition ()

@property (nonatomic, strong) NSDictionary<NSNumber *, NSValue *> *publicKeys;
@property (nonatomic, strong) DSCreditFundingTransaction *creditFundingTransaction;

@end

@implementation DSBlockchainIdentityRegistrationTransition

- (instancetype)initOnChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransitionType_IdentityRegistration;
    return self;
}

- (instancetype)initWithVersion:(uint16_t)version registeringPublicKeys:(NSDictionary<NSNumber *, NSValue *> *)publicKeys usingCreditFundingTransaction:(DSCreditFundingTransaction *)creditFundingTransaction onChain:(DSChain *)chain {
    NSParameterAssert(chain);
    NSParameterAssert(publicKeys);
    NSAssert(publicKeys.count, @"There must be at least one key when registering a user");

    if (!(self = [self initOnChain:chain])) return nil;
    self.version = version;
    self.creditFundingTransaction = creditFundingTransaction;
    self.blockchainIdentityUniqueId = [dsutxo_data(creditFundingTransaction.lockedOutpoint) SHA256_2];
    self.publicKeys = publicKeys;
    return self;
}

- (NSMutableArray *)platformKeyDictionaries {
    NSMutableArray *platformKeys = [NSMutableArray array];
    for (NSNumber *indexIdentifier in self.publicKeys) {
        OpaqueKey *key = self.publicKeys[indexIdentifier].pointerValue;
        DSMutableStringValueDictionary *platformKeyDictionary = [[DSMutableStringValueDictionary alloc] init];
        platformKeyDictionary[@"id"] = @([indexIdentifier unsignedIntValue]);
        platformKeyDictionary[@"purpose"] = @(DWIdentityPublicKeyPurposeAuthentication);
        platformKeyDictionary[@"securityLevel"] = @(DWIdentityPublicKeySecurityLevelMaster); 
        platformKeyDictionary[@"readOnly"] = @NO;
        platformKeyDictionary[@"type"] = @(key->tag);
        platformKeyDictionary[@"data"] = [DSKeyManager publicKeyData:key];
        [platformKeys addObject:platformKeyDictionary];
    }
    return platformKeys;
}

- (DSMutableStringValueDictionary *)assetLockProofDictionary {
    DSMutableStringValueDictionary *assetLockDictionary = [DSMutableStringValueDictionary dictionary];
    if (self.creditFundingTransaction.instantSendLockAwaitingProcessing) {
        assetLockDictionary[@"type"] = @(0);
        assetLockDictionary[@"instantLock"] = self.creditFundingTransaction.instantSendLockAwaitingProcessing.toData;
        assetLockDictionary[@"outputIndex"] = @(self.creditFundingTransaction.lockedOutpoint.n);
        assetLockDictionary[@"transaction"] = [self.creditFundingTransaction toData];
    } else {
        assetLockDictionary[@"type"] = @(1);
        assetLockDictionary[@"coreChainLockedHeight"] = @(self.creditFundingTransaction.blockHeight);
        assetLockDictionary[@"outPoint"] = dsutxo_data(self.creditFundingTransaction.lockedOutpoint);
    }

    return assetLockDictionary;
}

- (DSMutableStringValueDictionary *)baseKeyValueDictionary {
    DSMutableStringValueDictionary *json = [super baseKeyValueDictionary];
    json[@"assetLockProof"] = [self assetLockProofDictionary];
    json[@"publicKeys"] = [self platformKeyDictionaries];
    return json;
}

- (void)applyKeyValueDictionary:(DSMutableStringValueDictionary *)keyValueDictionary {
    [super applyKeyValueDictionary:keyValueDictionary];
    NSDictionary *assetLockDictionary = keyValueDictionary[@"assetLock"];
    self.creditFundingTransaction = [DSCreditFundingTransaction transactionWithMessage:assetLockDictionary[@"transaction"] onChain:self.chain];
    NSDictionary *proofDictionary = keyValueDictionary[@"proof"];
    NSNumber *proofType = proofDictionary[@"type"];
    if ([proofType integerValue] == 0) {
        //this is an instant send proof
        NSData *instantSendLockData = proofDictionary[@"instantLock"];
        //todo: v18 make this deterministic
        self.creditFundingTransaction.instantSendLockAwaitingProcessing = [DSInstantSendTransactionLock instantSendTransactionLockWithNonDeterministicMessage:instantSendLockData onChain:self.chain];
    }

    self.blockchainIdentityUniqueId = [dsutxo_data(self.lockedOutpoint) SHA256_2];
    NSArray *publicKeysDictionariesArray = keyValueDictionary[@"publicKeys"];
    NSMutableDictionary *platformKeys = [NSMutableDictionary dictionary];
    for (DSMutableStringValueDictionary *platformKeyDictionary in publicKeysDictionariesArray) {
        KeyKind keyType = [platformKeyDictionary[@"type"] unsignedIntValue];
        NSUInteger identifier = [platformKeyDictionary[@"id"] unsignedIntValue];
        NSData *keyData = platformKeyDictionary[@"data"];
        OpaqueKey *key = [DSKeyManager keyWithPublicKeyData:keyData ofType:keyType];
        platformKeys[@(identifier)] = [NSValue valueWithPointer:key];
    }
    self.publicKeys = [platformKeys copy];
}

//- (NSString *)description
//{
//    NSString *txid = [NSString hexWithData:[NSData dataWithBytes:self.txHash.u8 length:sizeof(UInt256)].reverse];
//    return [NSString stringWithFormat:@"%@<%p>(id=%@,username=%@,confirmedInBlock=%d)", [self class],self, txid,self.username,self.blockHeight];
//}

@end
