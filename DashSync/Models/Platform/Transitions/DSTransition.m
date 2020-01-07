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
#import "DSTransitionEntity+CoreDataClass.h"
#import "DSBlockchainIdentity.h"
#import "DSTransition.h"
#import "NSDate+Utils.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"

@interface DSTransition()

@property (nonatomic, strong) DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction;
@property (nonatomic, assign) uint16_t version;
@property (nonatomic, assign) UInt256 blockchainIdentityUniqueId;

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

-(instancetype)initWithTransitionVersion:(uint16_t)version blockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId onChain:(DSChain * _Nonnull)chain {
    NSParameterAssert(chain);
    
    if (!(self = [self initOnChain:chain])) return nil;
    self.type = DSTransitionType_Classic;
    self.version = version;
    self.blockchainIdentityUniqueId = blockchainIdentityUniqueId;
    return self;
}

-(NSData*)basePayloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.version];
    [data appendUInt256:self.registrationTransactionHash];
    [data appendUInt64:self.creditFee];
    return data;
}


-(NSData*)payloadDataForHash {
    NSMutableData * data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    [data appendUInt8:0];
    return data;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    //[data appendUInt8:96]; ??
    [data appendData:self.signatureData];
    return data;
}

-(UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

-(void)setRegistrationTransactionHash:(UInt256)registrationTransactionHash {
    _registrationTransactionHash = registrationTransactionHash;
    self.blockchainIdentityRegistrationTransaction = (DSBlockchainIdentityRegistrationTransition*)[self.chain transactionForHash:registrationTransactionHash];
}

//-(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransaction {
//    if (!_blockchainIdentityRegistrationTransaction) self.blockchainIdentityRegistrationTransaction = (DSBlockchainIdentityRegistrationTransition*)[self.chain transactionForHash:self.registrationTransactionHash];
//    return _blockchainIdentityRegistrationTransaction;
//}

-(BOOL)checkTransitionSignatureForECDSAKey:(DSECDSAKey*)transitionRecoveredPublicKey {
    return [transitionRecoveredPublicKey verify:[self payloadHash] signatureData:self.signatureData];
    //return uint160_eq([transitionRecoveredPublicKey hash160], self.blockchainIdentityRegistrationTransaction.pubkeyHash);
}

-(BOOL)checkTransitionSignatureForBLSKey:(DSBLSKey*)blockchainIdentityPublicKey {
    return [blockchainIdentityPublicKey verify:[self payloadHash] signature:self.signatureData.UInt768];
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
    return [blockchainIdentity verifySignature:self.signatureData ofType:DSBlockchainIdentitySigningType_ECDSA forMessageDigest:[self payloadHash]];
}

-(void)signWithKey:(DSKey*)privateKey {
    NSParameterAssert(privateKey);
    
    //ATTENTION If this ever changes from ECDSA, change the max signature size defined above
    //DSDLog(@"Private Key is %@",[privateKey privateKeyStringForChain:self.chain]);
    if ([privateKey isMemberOfClass:[DSBLSKey class]]) {
        self.signatureType = DSBlockchainIdentitySigningType_BLS;
        self.signatureData = uint768_data([((DSBLSKey*)privateKey) signDigest:[self payloadHash]]);
    } else if ([privateKey isMemberOfClass:[DSECDSAKey class]]) {
        self.signatureType = DSBlockchainIdentitySigningType_ECDSA;
        self.signatureData = [((DSECDSAKey*)privateKey) compactSign:[self payloadHash]];
    }
    self.transitionHash = self.data.SHA256_2;
}

// size in bytes if signed, or estimated size assuming compact pubkey sigs
- (size_t)size
{
    if (! uint256_is_zero(_transitionHash)) return self.data.length;
    return 8 + [self payloadData].length; //todo figure this out (probably wrong)
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
        json[@"signaturePublicKeyId"] = @(0);
        _keyValueDictionary = json;
    }
    return _keyValueDictionary;
}


-(Class)entityClass {
    return [DSTransitionEntity class];
}

// MARK: - Persistence

-(DSTransitionEntity *)save {
    NSManagedObjectContext * context = [DSTransitionEntity context];
    __block DSTransitionEntity * transitionEntity = nil;
    [context performBlockAndWait:^{ // add the transaction to core data
        [DSChainEntity setContext:context];
        Class transitionEntityClass = [self entityClass];
        [transitionEntityClass setContext:context];
        if ([DSTransitionEntity countObjectsMatching:@"transitionHash == %@", uint256_data(self.transitionHash)] == 0) {
            
            transitionEntity = [transitionEntityClass managedObject];
            [transitionEntity setAttributesFromTransition:self];
            [transitionEntityClass saveContext];
        } else {
            transitionEntity = [DSTransitionEntity anyObjectMatching:@"transitionHash == %@", uint256_data(self.transitionHash)];
            [transitionEntity setAttributesFromTransition:self];
            [transitionEntityClass saveContext];
        }
    }];
    return transitionEntity;
}

-(BOOL)saveInitial {
    if (self.saved) return nil;
    NSManagedObjectContext * context = [DSTransitionEntity context];
    __block BOOL didSave = FALSE;
    [context performBlockAndWait:^{ // add the transaction to core data
        [DSChainEntity setContext:context];
        Class transitionEntityClass = [self entityClass];
        [transitionEntityClass setContext:context];
        if ([DSTransitionEntity countObjectsMatching:@"transitionHash == %@", uint256_data(self.transitionHash)] == 0) {
            
            DSTransitionEntity * transitionEntity = [transitionEntityClass managedObject];
            [transitionEntity setAttributesFromTransition:self];
            [transitionEntityClass saveContext];
            didSave = TRUE;
        }
    }];
    self.saved = didSave;
    return didSave;
}


@end
