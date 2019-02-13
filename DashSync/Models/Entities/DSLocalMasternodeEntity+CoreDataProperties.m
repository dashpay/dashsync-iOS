//
//  DSLocalMasternodeEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 2/14/19.
//
//

#import "DSLocalMasternodeEntity+CoreDataProperties.h"

@implementation DSLocalMasternodeEntity (CoreDataProperties)

+ (NSFetchRequest<DSLocalMasternodeEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSLocalMasternodeEntity"];
}

@dynamic operatorKeysWalletUniqueId;
@dynamic ownerKeysWalletUniqueId;
@dynamic votingKeysWalletUniqueId;
@dynamic operatorKeysIndex;
@dynamic ownerKeysIndex;
@dynamic votingKeysIndex;
@dynamic providerRegistrationTransaction;

@end
