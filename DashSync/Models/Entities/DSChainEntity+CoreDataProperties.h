//
//  DSChainEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSChainEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSChainEntity (CoreDataProperties)

+ (NSFetchRequest<DSChainEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *baseBlockHash;
@property (nullable, nonatomic, retain) NSData *syncBlockHash;
@property (nonatomic, assign) uint32_t syncBlockHeight;
@property (nullable, nonatomic, retain) NSData *syncLocators;
@property (nullable, nonatomic, retain) NSData *checkpoints;
@property (nullable, nonatomic, copy) NSString *devnetIdentifier;
@property (nonatomic, assign) uint32_t totalGovernanceObjectsCount;
@property (nonatomic, assign) uint16_t type;
@property (nullable, nonatomic, retain) NSSet<DSAccountEntity *> *accounts;
@property (nullable, nonatomic, retain) NSSet<DSMerkleBlockEntity *> *blocks;
@property (nullable, nonatomic, retain) NSSet<DSDashpayUserEntity *> *contacts;
@property (nullable, nonatomic, retain) NSSet<DSDerivationPathEntity *> *derivationPaths;
@property (nullable, nonatomic, retain) NSSet<DSGovernanceObjectHashEntity *> *governanceObjectHashes;
@property (nullable, nonatomic, retain) NSSet<DSPeerEntity *> *peers;
@property (nullable, nonatomic, retain) NSSet<DSQuorumEntryEntity *> *quorums;
@property (nullable, nonatomic, retain) NSSet<DSSimplifiedMasternodeEntryEntity *> *simplifiedMasternodeEntries;
@property (nullable, nonatomic, retain) NSSet<DSSporkHashEntity *> *sporks;
@property (nullable, nonatomic, retain) NSSet<DSTransactionHashEntity *> *transactionHashes;
@property (nullable, nonatomic, retain) NSSet<DSGovernanceVoteHashEntity *> *votes;
@property (nullable, nonatomic, retain) NSSet<DSBlockchainIdentityEntity *> *identities;

@end

@interface DSChainEntity (CoreDataGeneratedAccessors)

- (void)addAccountsObject:(DSAccountEntity *)value;
- (void)removeAccountsObject:(DSAccountEntity *)value;
- (void)addAccounts:(NSSet<DSAccountEntity *> *)values;
- (void)removeAccounts:(NSSet<DSAccountEntity *> *)values;

- (void)addBlocksObject:(DSMerkleBlockEntity *)value;
- (void)removeBlocksObject:(DSMerkleBlockEntity *)value;
- (void)addBlocks:(NSSet<DSMerkleBlockEntity *> *)values;
- (void)removeBlocks:(NSSet<DSMerkleBlockEntity *> *)values;

- (void)addContactsObject:(DSDashpayUserEntity *)value;
- (void)removeContactsObject:(DSDashpayUserEntity *)value;
- (void)addContacts:(NSSet<DSDashpayUserEntity *> *)values;
- (void)removeContacts:(NSSet<DSDashpayUserEntity *> *)values;

- (void)addDerivationPathsObject:(DSDerivationPathEntity *)value;
- (void)removeDerivationPathsObject:(DSDerivationPathEntity *)value;
- (void)addDerivationPaths:(NSSet<DSDerivationPathEntity *> *)values;
- (void)removeDerivationPaths:(NSSet<DSDerivationPathEntity *> *)values;

- (void)addGovernanceObjectHashesObject:(DSGovernanceObjectHashEntity *)value;
- (void)removeGovernanceObjectHashesObject:(DSGovernanceObjectHashEntity *)value;
- (void)addGovernanceObjectHashes:(NSSet<DSGovernanceObjectHashEntity *> *)values;
- (void)removeGovernanceObjectHashes:(NSSet<DSGovernanceObjectHashEntity *> *)values;

- (void)addPeersObject:(DSPeerEntity *)value;
- (void)removePeersObject:(DSPeerEntity *)value;
- (void)addPeers:(NSSet<DSPeerEntity *> *)values;
- (void)removePeers:(NSSet<DSPeerEntity *> *)values;

- (void)addQuorumsObject:(DSQuorumEntryEntity *)value;
- (void)removeQuorumsObject:(DSQuorumEntryEntity *)value;
- (void)addQuorums:(NSSet<DSQuorumEntryEntity *> *)values;
- (void)removeQuorums:(NSSet<DSQuorumEntryEntity *> *)values;

- (void)addSimplifiedMasternodeEntriesObject:(DSSimplifiedMasternodeEntryEntity *)value;
- (void)removeSimplifiedMasternodeEntriesObject:(DSSimplifiedMasternodeEntryEntity *)value;
- (void)addSimplifiedMasternodeEntries:(NSSet<DSSimplifiedMasternodeEntryEntity *> *)values;
- (void)removeSimplifiedMasternodeEntries:(NSSet<DSSimplifiedMasternodeEntryEntity *> *)values;

- (void)addSporksObject:(DSSporkHashEntity *)value;
- (void)removeSporksObject:(DSSporkHashEntity *)value;
- (void)addSporks:(NSSet<DSSporkHashEntity *> *)values;
- (void)removeSporks:(NSSet<DSSporkHashEntity *> *)values;

- (void)addTransactionHashesObject:(DSTransactionHashEntity *)value;
- (void)removeTransactionHashesObject:(DSTransactionHashEntity *)value;
- (void)addTransactionHashes:(NSSet<DSTransactionHashEntity *> *)values;
- (void)removeTransactionHashes:(NSSet<DSTransactionHashEntity *> *)values;

- (void)addVotesObject:(DSGovernanceVoteHashEntity *)value;
- (void)removeVotesObject:(DSGovernanceVoteHashEntity *)value;
- (void)addVotes:(NSSet<DSGovernanceVoteHashEntity *> *)values;
- (void)removeVotes:(NSSet<DSGovernanceVoteHashEntity *> *)values;

- (void)addIdentitiesObject:(DSBlockchainIdentityEntity *)value;
- (void)removeIdentitiesObject:(DSBlockchainIdentityEntity *)value;
- (void)addIdentities:(NSSet<DSBlockchainIdentityEntity *> *)values;
- (void)removeIdentities:(NSSet<DSBlockchainIdentityEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
