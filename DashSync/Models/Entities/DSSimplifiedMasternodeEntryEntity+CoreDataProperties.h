//
//  DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSSimplifiedMasternodeEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSSimplifiedMasternodeEntryEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *providerTransactionHash;
@property (nonatomic, assign) uint32_t address;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) BOOL claimed;
@property (nullable, nonatomic, retain) NSData *keyIDOperator;
@property (nullable, nonatomic, retain) NSData *keyIDVoting;
@property (nonatomic, assign) Boolean isValid;
@property (nullable, nonatomic, retain) NSData *simplifiedMasternodeEntryHash;
@property (nullable, nonatomic, retain) DSChainEntity *chain;

@end

NS_ASSUME_NONNULL_END
