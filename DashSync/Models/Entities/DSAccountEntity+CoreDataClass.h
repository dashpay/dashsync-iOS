//
//  DSAccountEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 6/22/18.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSTxOutputEntity, DSDerivationPath, DSChainEntity, DSChain;

NS_ASSUME_NONNULL_BEGIN

@interface DSAccountEntity : NSManagedObject

+ (DSAccountEntity *_Nonnull)accountEntityForWalletUniqueID:(NSString *)walletUniqueID index:(uint32_t)index onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END

#import "DSAccountEntity+CoreDataProperties.h"
