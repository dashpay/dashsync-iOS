//
//  DSSimplifiedMasternodeEntryEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"

@implementation DSSimplifiedMasternodeEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSSimplifiedMasternodeEntryEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSSimplifiedMasternodeEntryEntity"];
}

@dynamic providerTransactionHash;
@dynamic address;
@dynamic port;
@dynamic keyIDOperator;
@dynamic keyIDVoting;
@dynamic isValid;
@dynamic simplifiedMasternodeEntryHash;
@dynamic chain;

@end
