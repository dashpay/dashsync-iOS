//
//  DSMasternodeListEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 5/20/19.
//
//

#import "DSMasternodeListEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListEntity (CoreDataProperties)

+ (NSFetchRequest<DSMasternodeListEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) DSSimplifiedMasternodeEntryEntity *masternodes;
@property (nullable, nonatomic, retain) DSMerkleBlockEntity *block;

@end

NS_ASSUME_NONNULL_END
