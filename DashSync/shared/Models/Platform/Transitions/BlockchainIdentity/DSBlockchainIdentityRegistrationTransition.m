//
//  DSBlockchainIdentityRegistrationTransition.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSBlockchainIdentityRegistrationTransition.h"
#import "BigIntTypes.h"
#import "DSCreditFundingTransaction.h"
#import "DSECDSAKey.h"
#import "DSInstantSendTransactionLock.h"
#import "DSTransaction+Protected.h"
#import "DSTransactionFactory.h"
#import "DSTransition+Protected.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSBlockchainIdentityRegistrationTransition ()

@property (nonatomic, strong) NSDictionary<NSNumber *, DSKey *> *publicKeys;
@property (nonatomic, strong) DSCreditFundingTransaction *creditFundingTransaction;

@end

@implementation DSBlockchainIdentityRegistrationTransition

- (instancetype)initOnChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransitionType_IdentityRegistration;
    return self;
}

- (instancetype)initWithVersion:(uint16_t)version registeringPublicKeys:(NSDictionary<NSNumber *, DSKey *> *)publicKeys usingCreditFundingTransaction:(DSCreditFundingTransaction *)creditFundingTransaction onChain:(DSChain *)chain {
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
        DSKey *key = self.publicKeys[indexIdentifier];
        DSMutableStringValueDictionary *platformKeyDictionary = [[DSMutableStringValueDictionary alloc] init];
        platformKeyDictionary[@"id"] = @([indexIdentifier unsignedIntValue]);
        platformKeyDictionary[@"type"] = @(key.keyType);
        platformKeyDictionary[@"data"] = key.publicKeyData;
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
        self.creditFundingTransaction.instantSendLockAwaitingProcessing = [DSInstantSendTransactionLock instantSendTransactionLockWithMessage:instantSendLockData onChain:self.chain];
    }

    self.blockchainIdentityUniqueId = [dsutxo_data(self.lockedOutpoint) SHA256_2];
    NSArray *publicKeysDictionariesArray = keyValueDictionary[@"publicKeys"];
    NSMutableDictionary *platformKeys = [NSMutableDictionary dictionary];
    for (DSMutableStringValueDictionary *platformKeyDictionary in publicKeysDictionariesArray) {
        DSKeyType keyType = [platformKeyDictionary[@"type"] unsignedIntValue];
        NSUInteger identifier = [platformKeyDictionary[@"id"] unsignedIntValue];
        NSData *keyData = platformKeyDictionary[@"data"];
        DSKey *key = [DSKey keyWithPublicKeyData:keyData forKeyType:keyType];
        platformKeys[@(identifier)] = key;
    }
    self.publicKeys = [platformKeys copy];
}

//- (NSString *)description
//{
//    NSString *txid = [NSString hexWithData:[NSData dataWithBytes:self.txHash.u8 length:sizeof(UInt256)].reverse];
//    return [NSString stringWithFormat:@"%@<%p>(id=%@,username=%@,confirmedInBlock=%d)", [self class],self, txid,self.username,self.blockHeight];
//}

@end
