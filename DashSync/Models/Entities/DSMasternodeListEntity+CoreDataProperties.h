//
//  DSMasternodeListEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 5/23/19.
//
//

#import "DSMasternodeListEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListEntity (CoreDataProperties)

+ (NSFetchRequest<DSMasternodeListEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) DSMerkleBlockEntity *block;
@property (nullable, nonatomic, retain) NSSet<DSSimplifiedMasternodeEntryEntity *> *masternodes;
@property (nullable, nonatomic, retain) NSSet<DSQuorumEntryEntity *> *quorums;

@end

@interface DSMasternodeListEntity (CoreDataGeneratedAccessors)

- (void)addMasternodesObject:(DSSimplifiedMasternodeEntryEntity *)value;
- (void)removeMasternodesObject:(DSSimplifiedMasternodeEntryEntity *)value;
- (void)addMasternodes:(NSSet<DSSimplifiedMasternodeEntryEntity *> *)values;
- (void)removeMasternodes:(NSSet<DSSimplifiedMasternodeEntryEntity *> *)values;

- (void)addQuorumsObject:(DSQuorumEntryEntity *)value;
- (void)removeQuorumsObject:(DSQuorumEntryEntity *)value;
- (void)addQuorums:(NSSet<DSQuorumEntryEntity *> *)values;
- (void)removeQuorums:(NSSet<DSQuorumEntryEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
