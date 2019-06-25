//
//  DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 6/19/19.
//
//

#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSSimplifiedMasternodeEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSSimplifiedMasternodeEntryEntity *> *)fetchRequest;

@property (nonatomic, assign) uint64_t address; //it's really on 32 bits but unsigned
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) BOOL isValid;
@property (nullable, nonatomic, retain) NSData *confirmedHash;
@property (nullable, nonatomic, retain) NSData *keyIDVoting;
@property (nullable, nonatomic, retain) NSData *operatorBLSPublicKey;
@property (nullable, nonatomic, retain) NSObject *previousOperatorBLSPublicKeys;
@property (nullable, nonatomic, retain) NSData *providerRegistrationTransactionHash;
@property (nullable, nonatomic, retain) NSData *simplifiedMasternodeEntryHash;
@property (nullable, nonatomic, retain) NSObject *previousSimplifiedMasternodeEntryHashes;
@property (nullable, nonatomic, retain) NSOrderedSet<DSAddressEntity *> *addresses;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) NSSet<DSGovernanceVoteEntity *> *governanceVotes;
@property (nullable, nonatomic, retain) DSLocalMasternodeEntity *localMasternode;
@property (nullable, nonatomic, retain) NSSet<DSMasternodeListEntity *> *masternodeLists;
@property (nullable, nonatomic, retain) NSSet<DSTransactionLockVoteEntity *> *transactionLockVotes;

@end

@interface DSSimplifiedMasternodeEntryEntity (CoreDataGeneratedAccessors)

- (void)insertObject:(DSAddressEntity *)value inAddressesAtIndex:(NSUInteger)idx;
- (void)removeObjectFromAddressesAtIndex:(NSUInteger)idx;
- (void)insertAddresses:(NSArray<DSAddressEntity *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeAddressesAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInAddressesAtIndex:(NSUInteger)idx withObject:(DSAddressEntity *)value;
- (void)replaceAddressesAtIndexes:(NSIndexSet *)indexes withAddresses:(NSArray<DSAddressEntity *> *)values;
- (void)addAddressesObject:(DSAddressEntity *)value;
- (void)removeAddressesObject:(DSAddressEntity *)value;
- (void)addAddresses:(NSOrderedSet<DSAddressEntity *> *)values;
- (void)removeAddresses:(NSOrderedSet<DSAddressEntity *> *)values;

- (void)addGovernanceVotesObject:(DSGovernanceVoteEntity *)value;
- (void)removeGovernanceVotesObject:(DSGovernanceVoteEntity *)value;
- (void)addGovernanceVotes:(NSSet<DSGovernanceVoteEntity *> *)values;
- (void)removeGovernanceVotes:(NSSet<DSGovernanceVoteEntity *> *)values;

- (void)addMasternodeListsObject:(DSMasternodeListEntity *)value;
- (void)removeMasternodeListsObject:(DSMasternodeListEntity *)value;
- (void)addMasternodeLists:(NSSet<DSMasternodeListEntity *> *)values;
- (void)removeMasternodeLists:(NSSet<DSMasternodeListEntity *> *)values;

- (void)addTransactionLockVotesObject:(DSTransactionLockVoteEntity *)value;
- (void)removeTransactionLockVotesObject:(DSTransactionLockVoteEntity *)value;
- (void)addTransactionLockVotes:(NSSet<DSTransactionLockVoteEntity *> *)values;
- (void)removeTransactionLockVotes:(NSSet<DSTransactionLockVoteEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
