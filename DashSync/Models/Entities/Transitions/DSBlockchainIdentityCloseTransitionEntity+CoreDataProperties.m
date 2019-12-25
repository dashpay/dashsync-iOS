//
//  DSBlockchainIdentityCloseTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityCloseTransitionEntity+CoreDataProperties.h"

@implementation DSBlockchainIdentityCloseTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityCloseTransitionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainIdentityCloseTransitionEntity"];
}

@dynamic reason;

@end
