//
//  DSTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSTransitionEntity+CoreDataProperties.h"

@implementation DSTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransitionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSTransitionEntity"];
}

@dynamic version;
@dynamic type;
@dynamic creditFee;
@dynamic signatureData;
@dynamic blockchainIdentityUniqueIdData;
@dynamic signatureId;
@dynamic createdTimestamp;
@dynamic registeredTimestamp;
@dynamic blockchainIdentity;
@dynamic transitionHashData;

@end
