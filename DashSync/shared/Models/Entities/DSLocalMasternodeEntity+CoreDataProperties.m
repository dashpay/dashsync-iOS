//
//  DSLocalMasternodeEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 3/3/19.
//
//

#import "DSLocalMasternodeEntity+CoreDataProperties.h"

@implementation DSLocalMasternodeEntity (CoreDataProperties)

+ (NSFetchRequest<DSLocalMasternodeEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSLocalMasternodeEntity"];
}

@dynamic holdingKeysIndex;
@dynamic holdingKeysWalletUniqueId;
@dynamic operatorKeysIndex;
@dynamic operatorKeysWalletUniqueId;
@dynamic ownerKeysIndex;
@dynamic ownerKeysWalletUniqueId;
@dynamic votingKeysIndex;
@dynamic votingKeysWalletUniqueId;
@dynamic providerRegistrationTransaction;
@dynamic simplifiedMasternodeEntry;
@dynamic providerUpdateRegistrarTransactions;
@dynamic providerUpdateServiceTransactions;
@dynamic providerUpdateRevocationTransactions;

@end
