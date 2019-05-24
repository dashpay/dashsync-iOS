//
//  DSMasternodeListEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 5/23/19.
//
//

#import "DSMasternodeListEntity+CoreDataClass.h"
#import "DSMasternodeList.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"

@implementation DSMasternodeListEntity

-(DSMasternodeList*)masternodeListWithSimplifiedMasternodeEntryPool:(NSDictionary <NSData*,DSSimplifiedMasternodeEntry*>*)simplifiedMasternodeEntries quorumEntryPool:(NSDictionary <NSData*,DSQuorumEntry*>*)quorumEntries {
    NSMutableArray * masternodeEntriesArray = [NSMutableArray array];
    for (DSSimplifiedMasternodeEntryEntity * masternodeEntity in self.masternodes) {
        DSSimplifiedMasternodeEntry * masternodeEntry = [simplifiedMasternodeEntries objectForKey:masternodeEntity.providerRegistrationTransactionHash];
        if (!masternodeEntry) {
            masternodeEntry = masternodeEntity.simplifiedMasternodeEntry;
        }
        [masternodeEntriesArray addObject:masternodeEntry];
    }
    NSMutableArray * quorumEntriesArray = [NSMutableArray array];
    for (DSQuorumEntryEntity * quorumEntity in self.quorums) {
        DSQuorumEntry * quorumEntry = [quorumEntries objectForKey:quorumEntity.commitmentHashData];
        if (!quorumEntry) {
            quorumEntry = quorumEntity.quorumEntry;
        }
        [quorumEntriesArray addObject:quorumEntry];
    }
    return [DSMasternodeList masternodeListWithSimplifiedMasternodeEntries:masternodeEntriesArray quorumEntries:quorumEntriesArray atBlockHash:self.block.blockHash.UInt256 onChain:self.block.chain.chain];
}

+ (void)deleteAllOnChain:(DSChainEntity*)chainEntity {
    NSArray * masternodeLists = [self objectsMatching:@"(block.chain == %@)",chainEntity];
    for (DSMasternodeListEntity * masternodeList in masternodeLists) {
        [chainEntity.managedObjectContext deleteObject:masternodeList];
    }
}

@end
