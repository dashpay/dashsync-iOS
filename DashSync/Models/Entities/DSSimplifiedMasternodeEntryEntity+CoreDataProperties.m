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

@dynamic providerRegistrationTransactionHash;
@dynamic confirmedHash;
@dynamic address;
@dynamic port;
@dynamic operatorBLSPublicKey;
@dynamic keyIDVoting;
@dynamic isValid;
@dynamic simplifiedMasternodeEntryHash;
@dynamic chain;
@dynamic claimed;

@end
