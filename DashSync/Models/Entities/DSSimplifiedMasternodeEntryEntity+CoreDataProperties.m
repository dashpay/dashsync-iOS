//
//  DSSimplifiedMasternodeEntryEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 6/19/19.
//
//

#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"

@implementation DSSimplifiedMasternodeEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSSimplifiedMasternodeEntryEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSSimplifiedMasternodeEntryEntity"];
}

@dynamic address;
@dynamic confirmedHash;
@dynamic isValid;
@dynamic keyIDVoting;
@dynamic operatorBLSPublicKey;
@dynamic port;
@dynamic previousOperatorBLSPublicKeys;
@dynamic previousValidity;
@dynamic providerRegistrationTransactionHash;
@dynamic simplifiedMasternodeEntryHash;
@dynamic addresses;
@dynamic chain;
@dynamic governanceVotes;
@dynamic localMasternode;
@dynamic masternodeLists;
@dynamic previousSimplifiedMasternodeEntryHashes;
@dynamic ipv6Address;
@dynamic updateHeight;
@dynamic knownConfirmedAtHeight;
@dynamic platformPingDate;
@dynamic platformPing;
@dynamic coreVersion;
@dynamic coreProtocol;
@dynamic coreLastConnectionDate;
@dynamic platformVersion;

@end
