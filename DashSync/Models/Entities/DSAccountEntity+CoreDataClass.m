//
//  DSAccountEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/22/18.
//
//

#import "DSAccountEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"

@implementation DSAccountEntity

+ (DSAccountEntity* _Nonnull)accountEntityForWalletUniqueID:(NSString*)walletUniqueID index:(uint32_t)index onChain:(DSChain*)chain inContext:(NSManagedObjectContext*)context {
    NSParameterAssert(walletUniqueID);
    NSParameterAssert(chain);
    NSParameterAssert(context);
    NSArray * accounts = [DSAccountEntity objectsInContext:context matching:@"walletUniqueID = %@ && index = %@",walletUniqueID,@(index)];
    if ([accounts count]) {
        NSAssert([accounts count] == 1, @"There can only be one account per index per wallet");
        return [accounts objectAtIndex:0];
    }
    DSAccountEntity * accountEntity = [DSAccountEntity managedObjectInBlockedContext:context];
    accountEntity.walletUniqueID = walletUniqueID;
    accountEntity.index = index;
    accountEntity.chain = [chain chainEntityInContext:context];
    return accountEntity;
}

@end
