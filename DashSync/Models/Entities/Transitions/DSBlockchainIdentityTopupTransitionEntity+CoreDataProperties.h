//
//  DSBlockchainIdentityTopupTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityTopupTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityTopupTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityTopupTransitionEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *topupAmount;

@end

NS_ASSUME_NONNULL_END
