//
//  DSLocalMasternodeEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//
//

#import "DSLocalMasternodeEntity+CoreDataProperties.h"

@implementation DSLocalMasternodeEntity (CoreDataProperties)

+ (NSFetchRequest<DSLocalMasternodeEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSLocalMasternodeEntity"];
}

@dynamic operatorKeysIndex;
@dynamic operatorKeysWalletUniqueId;
@dynamic ownerKeysIndex;
@dynamic ownerKeysWalletUniqueId;
@dynamic votingKeysIndex;
@dynamic votingKeysWalletUniqueId;
@dynamic holdingKeysIndex;
@dynamic holdingKeysWalletUniqueId;
@dynamic addresses;
@dynamic providerRegistrationTransaction;
@dynamic simplifiedMasternodeEntry;

@end
