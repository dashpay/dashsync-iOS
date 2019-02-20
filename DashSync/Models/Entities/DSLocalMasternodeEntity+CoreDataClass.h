//
//  DSLocalMasternodeEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSProviderRegistrationTransactionEntity,DSLocalMasternode;

NS_ASSUME_NONNULL_BEGIN

@interface DSLocalMasternodeEntity : NSManagedObject

- (DSLocalMasternode* _Nullable)loadLocalMasternode;

- (void)setAttributesFromLocalMasternode:(DSLocalMasternode*)localMasternode;

@end

NS_ASSUME_NONNULL_END

#import "DSLocalMasternodeEntity+CoreDataProperties.h"
