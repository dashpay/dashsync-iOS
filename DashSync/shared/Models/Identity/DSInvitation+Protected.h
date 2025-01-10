//
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "BigIntTypes.h"
#import "DSInvitation.h"
#import "DSBlockchainInvitationEntity+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain;

@interface DSInvitation (Protected)

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet;

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
       withInvitationEntity:(DSBlockchainInvitationEntity *)invitationEntity;

- (instancetype)initWithUniqueId:(UInt256)uniqueId
                     isTransient:(BOOL)isTransient
                         onChain:(DSChain *)chain;

- (instancetype)initAtIndex:(uint32_t)index
                   inWallet:(DSWallet *)wallet;
- (instancetype)initAtIndex:(uint32_t)index
   withAssetLockTransaction:(DSAssetLockTransaction *)transaction
                   inWallet:(DSWallet *)wallet;

- (void)registerInWalletForIdentityUniqueId:(UInt256)identityUniqueId;
- (void)registerInWalletForAssetLockTransaction:(DSAssetLockTransaction *)transaction;

- (void)deletePersistentObjectAndSave:(BOOL)save
                            inContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END
