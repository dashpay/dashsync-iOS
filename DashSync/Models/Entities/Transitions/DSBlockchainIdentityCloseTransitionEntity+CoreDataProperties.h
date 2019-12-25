//
//  DSBlockchainIdentityCloseTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityCloseTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityCloseTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityCloseTransitionEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *reason;

@end

NS_ASSUME_NONNULL_END
