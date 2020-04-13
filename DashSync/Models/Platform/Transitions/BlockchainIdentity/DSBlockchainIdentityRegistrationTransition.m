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
#import "DSTransition+Protected.h"
#import "BigIntTypes.h"

@interface DSBlockchainIdentityRegistrationTransition()

@property (nonatomic,strong) NSDictionary <NSNumber*,DSKey*>* publicKeys;
@property (nonatomic,assign) DSUTXO lockedOutpoint;
@property (nonatomic,assign) DSBlockchainIdentityType identityType;

@end

@implementation DSBlockchainIdentityRegistrationTransition

- (instancetype)initOnChain:(DSChain*)chain
{
    if (! (self = [super initOnChain:chain])) return nil;
    self.type = DSTransitionType_IdentityRegistration;
    return self;
}

-(instancetype)initWithVersion:(uint16_t)version forIdentityType:(DSBlockchainIdentityType)identityType registeringPublicKeys:(NSDictionary <NSNumber*,DSKey*>*)publicKeys usingLockedOutpoint:(DSUTXO)lockedOutpoint onChain:(DSChain *)chain {
    NSParameterAssert(chain);
    NSParameterAssert(publicKeys);
    NSAssert(publicKeys.count, @"There must be at least one key when registering a user");

    if (!(self = [self initOnChain:chain])) return nil;
    self.identityType = identityType;
    self.version = 1;
    self.lockedOutpoint = lockedOutpoint;
    self.blockchainIdentityUniqueId = [dsutxo_data(lockedOutpoint) SHA256_2];
    self.publicKeys = publicKeys;
    return self;
}

- (NSMutableArray *)platformKeyDictionaries {
    NSMutableArray * platformKeys = [NSMutableArray array];
    for (NSNumber * indexIdentifier in self.publicKeys) {
        DSKey * key = self.publicKeys[indexIdentifier];
        DSMutableStringValueDictionary *platformKeyDictionary = [[DSMutableStringValueDictionary alloc] init];
        platformKeyDictionary[@"id"] = @([indexIdentifier unsignedIntValue] + 1);
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

-(void)applyKeyValueDictionary:(DSMutableStringValueDictionary *)keyValueDictionary {
    [super applyKeyValueDictionary:keyValueDictionary];
    self.identityType = [keyValueDictionary[@"identityType"] unsignedIntValue];
    NSString * lockedOutPointString = keyValueDictionary[@"lockedOutPoint"];
    self.lockedOutpoint = [lockedOutPointString.base64ToData transactionOutpoint];
    self.blockchainIdentityUniqueId = [dsutxo_data(self.lockedOutpoint) SHA256_2];
    NSArray * publicKeysDictionariesArray = keyValueDictionary[@"publicKeys"];
    NSMutableDictionary * platformKeys = [NSMutableDictionary dictionary];
    for (DSMutableStringValueDictionary * platformKeyDictionary in publicKeysDictionariesArray) {
        DSKeyType keyType = [platformKeyDictionary[@"type"] unsignedIntValue];
        NSUInteger identifier = [platformKeyDictionary[@"id"] unsignedIntValue] - 1;
        NSData* keyData = ((NSString*)platformKeyDictionary[@"data"]).base64ToData;
        DSKey * key = [DSKey keyWithPublicKeyData:keyData forKeyType:keyType];
        [platformKeys setObject:key forKey:@(identifier)];
    }
    self.publicKeys = [platformKeys copy];
}

//- (NSString *)description
//{
//    NSString *txid = [NSString hexWithData:[NSData dataWithBytes:self.txHash.u8 length:sizeof(UInt256)].reverse];
//    return [NSString stringWithFormat:@"%@<%p>(id=%@,username=%@,confirmedInBlock=%d)", [self class],self, txid,self.username,self.blockHeight];
//}

@end
