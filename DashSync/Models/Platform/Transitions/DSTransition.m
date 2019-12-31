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

@property (nonatomic, assign) DSBlockchainIdentitySigningType payloadSignatureType;
@property (nonatomic, copy) NSData * payloadSignatureData;

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
    [data appendData:self.payloadSignatureData];
    return data;
}

-(UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

-(void)setRegistrationTransactionHash:(UInt256)registrationTransactionHash {
    _registrationTransactionHash = registrationTransactionHash;
    self.blockchainIdentityRegistrationTransaction = (DSBlockchainIdentityRegistrationTransition*)[self.chain transactionForHash:registrationTransactionHash];
}

-(DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransaction {
    if (!_blockchainIdentityRegistrationTransaction) self.blockchainIdentityRegistrationTransaction = (DSBlockchainIdentityRegistrationTransition*)[self.chain transactionForHash:self.registrationTransactionHash];
    return _blockchainIdentityRegistrationTransaction;
}

-(BOOL)checkPayloadSignatureForECDSAKey:(DSECDSAKey*)transitionRecoveredPublicKey {
    return uint160_eq([transitionRecoveredPublicKey hash160], self.blockchainIdentityRegistrationTransaction.pubkeyHash);
}

-(BOOL)checkPayloadSignatureForBLSKey:(DSBLSKey*)blockchainIdentityPublicKey {
    [blockchainIdentityPublicKey verify:[self payloadHash] signature:self.payloadSignatureData.UInt768];
    return uint160_eq([blockchainIdentityPublicKey hash160], self.blockchainIdentityRegistrationTransaction.pubkeyHash);
}

-(BOOL)checkPayloadSignature:(DSKey*)key {
    if ([key isMemberOfClass:[DSECDSAKey class]]) {
        return [self checkPayloadSignatureForECDSAKey:(DSECDSAKey*)key];
    } else if ([key isMemberOfClass:[DSBLSKey class]]) {
        return [self checkPayloadSignatureForBLSKey:(DSBLSKey*)key];
    }
    NSAssert(FALSE, @"unimplemented key type");
    return FALSE;
}

-(BOOL)checkPayloadSignedByBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    return [blockchainIdentity verifySignature:self.payloadSignatureData ofType:DSBlockchainIdentitySigningType_ECDSA forMessageDigest:[self payloadHash]];
}

-(void)signPayloadWithKey:(DSKey*)privateKey {
    NSParameterAssert(privateKey);
    
    //ATTENTION If this ever changes from ECDSA, change the max signature size defined above
    //DSDLog(@"Private Key is %@",[privateKey privateKeyStringForChain:self.chain]);
    if ([privateKey isMemberOfClass:[DSBLSKey class]]) {
        self.payloadSignatureType = DSBlockchainIdentitySigningType_BLS;
        self.payloadSignatureData = uint768_data([((DSBLSKey*)privateKey) signDigest:[self payloadHash]]);
    } else if ([privateKey isMemberOfClass:[DSECDSAKey class]]) {
        self.payloadSignatureType = DSBlockchainIdentitySigningType_ECDSA;
        self.payloadSignatureData = [((DSECDSAKey*)privateKey) compactSign:[self payloadHash]];
    }
    self.transitionHash = self.data.SHA256_2;
}

// size in bytes if signed, or estimated size assuming compact pubkey sigs
- (size_t)size
{
    if (! uint256_is_zero(_transitionHash)) return self.data.length;
    return 8 + [self payloadData].length; //todo figure this out (probably wrong)
}

// Returns the binary transaction data that needs to be hashed and signed with the private key for the tx input at
// subscriptIndex. A subscriptIndex of NSNotFound will return the entire signed transaction.
- (NSData *)toData
{
    NSMutableData *d = [NSMutableData data];
    
    [d appendUInt16:self.version];
    [d appendUInt16:self.type];
        NSData * payloadData = [self payloadData];
        [d appendVarInt:payloadData.length];
        [d appendData:payloadData];
    
    return d;
}


-(Class)entityClass {
    return [DSTransitionEntity class];
}

// MARK: - Persistence

-(DSTransitionEntity *)save {
    NSManagedObjectContext * context = [DSTransitionEntity context];
    __block DSTransitionEntity * transactionEntity = nil;
    [context performBlockAndWait:^{ // add the transaction to core data
        [DSChainEntity setContext:context];
        Class transactionEntityClass = [self entityClass];
        [transactionEntityClass setContext:context];
        [DSTransactionHashEntity setContext:context];
        if ([DSTransactionEntity countObjectsMatching:@"transactionHash.txHash == %@", uint256_data(self.txHash)] == 0) {
            
            transactionEntity = [transactionEntityClass managedObject];
            [transactionEntity setAttributesFromTransaction:self];
            [transactionEntityClass saveContext];
        } else {
            transactionEntity = [DSTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(self.txHash)];
            [transactionEntity setAttributesFromTransaction:self];
            [transactionEntityClass saveContext];
        }
    }];
    return transactionEntity;
}

-(BOOL)saveInitial {
    if (self.saved) return nil;
    NSManagedObjectContext * context = [DSTransitionEntity context];
    __block BOOL didSave = FALSE;
    [context performBlockAndWait:^{ // add the transaction to core data
        [DSChainEntity setContext:context];
        Class transactionEntityClass = [self entityClass];
        [transactionEntityClass setContext:context];
        if ([DSTransitionEntity countObjectsMatching:@"transitionHash == %@", uint256_data(self.txHash)] == 0) {
            
            DSTransactionEntity * transactionEntity = [transactionEntityClass managedObject];
            [transactionEntity setAttributesFromTransaction:self];
            [transactionEntityClass saveContext];
            didSave = TRUE;
        }
    }];
    self.saved = didSave;
    return didSave;
}


@end
