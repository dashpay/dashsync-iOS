//
//  DSBlockchainIdentityTopupTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainIdentityTopupTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityTopupTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityTopupTransitionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *registrationTransactionHash;

@end

NS_ASSUME_NONNULL_END
