//
//  DSContractEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 2/11/20.
//
//

#import "DSContractEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSContractEntity (CoreDataProperties)

+ (NSFetchRequest<DSContractEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSString *localContractIdentifier;
@property (nullable, nonatomic, retain) NSData *registeredBlockchainIdentityUniqueID;
@property (nullable, nonatomic, retain) NSData *entropy;
@property (assign, nonatomic) uint16_t state;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) DSBlockchainIdentityEntity *creator;

@end

NS_ASSUME_NONNULL_END
