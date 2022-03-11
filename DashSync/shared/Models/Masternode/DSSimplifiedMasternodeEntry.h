//
//  DSSimplifiedMasternodeEntry.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "BigIntTypes.h"
#import "dash_shared_core.h"
#import <Foundation/Foundation.h>

@class DSChain, DSSimplifiedMasternodeEntryEntity, DSWallet, DSBlock;

@interface DSSimplifiedMasternodeEntry : NSObject

@property (nonatomic, readonly) UInt256 providerRegistrationTransactionHash;
@property (nonatomic, readonly) UInt256 confirmedHash;
@property (nonatomic, readonly) UInt256 confirmedHashHashedWithProviderRegistrationTransactionHash;
@property (nonatomic, readonly) UInt128 address;
@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) NSString *ipAddressString;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, readonly) NSString *portString;
@property (nonatomic, readonly) NSString *validString;
@property (nonatomic, readonly) UInt384 operatorPublicKey;
@property (nonatomic, readonly) NSDictionary *previousOperatorPublicKeys;
@property (nonatomic, readonly) NSDictionary *previousSimplifiedMasternodeEntryHashes;
@property (nonatomic, readonly) NSDictionary *previousValidity;
@property (nonatomic, readonly) uint32_t knownConfirmedAtHeight;
@property (nonatomic, readonly) uint32_t updateHeight;
@property (nonatomic, readonly) UInt160 keyIDVoting;
@property (nonatomic, readonly) NSString *votingAddress;
@property (nonatomic, readonly) NSString *operatorAddress;
@property (nonatomic, readonly) BOOL isValid;
@property (nonatomic, readonly) UInt256 simplifiedMasternodeEntryHash;
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, readonly) NSData *payloadData;
@property (nonatomic, readonly) NSString *uniqueID;
@property (nonatomic, readonly, class) uint32_t payloadLength;
@property (nonatomic, readonly) uint64_t platformPing;
@property (nonatomic, readonly) NSDate *platformPingDate;

+ (instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey previousOperatorBLSPublicKeys:(NSDictionary<DSBlock *, NSData *> *)previousOperatorBLSPublicKeys keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid previousValidity:(NSDictionary<DSBlock *, NSNumber *> *)previousValidity knownConfirmedAtHeight:(uint32_t)knownConfirmedAtHeight updateHeight:(uint32_t)updateHeight simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash previousSimplifiedMasternodeEntryHashes:(NSDictionary<DSBlock *, NSData *> *)previousSimplifiedMasternodeEntryHashes onChain:(DSChain *)chain;

- (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryEntityInContext:(NSManagedObjectContext *)context;

- (BOOL)verifySignature:(UInt768)signature forMessageDigest:(UInt256)messageDigest;

- (UInt256)simplifiedMasternodeEntryHashAtBlock:(DSBlock *)merkleBlock;

- (UInt256)simplifiedMasternodeEntryHashAtBlockHash:(UInt256)blockHash;

- (UInt256)simplifiedMasternodeEntryHashAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup;

- (UInt256)simplifiedMasternodeEntryHashAtBlockHeight:(uint32_t)blockHeight;

- (UInt384)operatorPublicKeyAtBlock:(DSBlock *)merkleBlock;

- (UInt384)operatorPublicKeyAtBlockHash:(UInt256)blockHash;

- (UInt384)operatorPublicKeyAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup;

- (UInt384)operatorPublicKeyAtBlockHeight:(uint32_t)blockHeight;

- (BOOL)isValidAtBlock:(DSBlock *)merkleBlock;

- (BOOL)isValidAtBlockHash:(UInt256)blockHash;

- (BOOL)isValidAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup;

- (BOOL)isValidAtBlockHeight:(uint32_t)blockHeight;

- (UInt256)confirmedHashAtBlock:(DSBlock *)merkleBlock;

- (UInt256)confirmedHashAtBlockHash:(UInt256)blockHash;

- (UInt256)confirmedHashAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup;

- (UInt256)confirmedHashAtBlockHeight:(uint32_t)blockHeight;

- (UInt256)confirmedHashHashedWithProviderRegistrationTransactionHashAtBlockHeight:(uint32_t)blockHeight;

- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash usingOurString:(NSString *)ours usingTheirString:(NSString *)theirs;
- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash usingOurString:(NSString *)ours usingTheirString:(NSString *)theirs blockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup;
- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other atBlockHash:(UInt256)blockHash;

- (NSDictionary *)toDictionaryAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup;

- (void)setPlatformPing:(uint64_t)platformPing at:(NSDate *)time;

- (void)savePlatformPingInfoInContext:(NSManagedObjectContext *)context;

@end
