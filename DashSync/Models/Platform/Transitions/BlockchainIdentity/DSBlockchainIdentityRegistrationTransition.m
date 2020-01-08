//
//  DSBlockchainIdentityRegistrationTransition.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSBlockchainIdentityRegistrationTransition.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSBlockchainIdentityRegistrationTransitionEntity+CoreDataClass.h"
#import "DSTransition+Protected.h"
#import "BigIntTypes.h"

@interface DSBlockchainIdentityRegistrationTransition()

@property (nonatomic,strong) NSDictionary <NSNumber*,DSKey*>* publicKeys;
@property (nonatomic,assign) DSUTXO lockedOutpoint;
@property (nonatomic,assign) DSBlockchainIdentityType identityType;

@end

@implementation DSBlockchainIdentityRegistrationTransition

-(instancetype)initWithVersion:(uint16_t)version forIdentityType:(DSBlockchainIdentityType)identityType registeringPublicKeys:(NSDictionary <NSNumber*,DSKey*>*)publicKeys usingLockedOutpoint:(DSUTXO)lockedOutpoint onChain:(DSChain *)chain {
    NSParameterAssert(chain);
    NSParameterAssert(publicKeys);
    NSAssert(publicKeys.count, @"There must be at least one key when registering a user");

    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransitionType_IdentityRegistration;
    self.identityType = identityType;
    self.version = 1;
    self.lockedOutpoint = lockedOutpoint;
    self.publicKeys = publicKeys;
    return self;
}

-(Class)entityClass {
    return [DSBlockchainIdentityRegistrationTransitionEntity class];
}

- (NSMutableArray *)platformKeyDictionaries {
    NSMutableArray * platformKeys = [NSMutableArray array];
    for (NSNumber * indexIdentifier in self.publicKeys) {
        DSKey * key = self.publicKeys[indexIdentifier];
        DSMutableStringValueDictionary *platformKeyDictionary = [[DSMutableStringValueDictionary alloc] init];
        platformKeyDictionary[@"id"] = indexIdentifier;
        platformKeyDictionary[@"type"] = @(key.keyType);
        platformKeyDictionary[@"data"] = key.publicKeyData.base64String;
        platformKeyDictionary[@"isEnabled"] = @YES;
        [platformKeys addObject:platformKeyDictionary];
    }
    return platformKeys;
}

- (DSMutableStringValueDictionary *)baseKeyValueDictionary {
    DSMutableStringValueDictionary *json = [super baseKeyValueDictionary];
    json[@"identityType"] = @(self.identityType);
    json[@"lockedOutPoint"] = dsutxo_data(self.lockedOutpoint).base64String;
    json[@"publicKeys"] = [self platformKeyDictionaries];
    return json;
}

//- (NSString *)description
//{
//    NSString *txid = [NSString hexWithData:[NSData dataWithBytes:self.txHash.u8 length:sizeof(UInt256)].reverse];
//    return [NSString stringWithFormat:@"%@<%p>(id=%@,username=%@,confirmedInBlock=%d)", [self class],self, txid,self.username,self.blockHeight];
//}

@end
