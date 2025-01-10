//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>
#import "DSInvitation.h"
#import "DSWallet.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSWallet (Invitation)

@property (nonatomic, readonly) NSDictionary<NSData *, DSInvitation *> *invitations;
// the first unused index for invitations
@property (nonatomic, readonly) uint32_t unusedInvitationIndex;
// the amount of known blockchain invitations
@property (nonatomic, readonly) uint32_t invitationsCount;

- (void)setupInvitations;

- (void)unregisterInvitation:(DSInvitation *)invitation;
- (void)addInvitation:(DSInvitation *)invitation;
- (void)registerInvitation:(DSInvitation *)invitation;
- (BOOL)containsInvitation:(DSInvitation *)invitation;
- (DSInvitation *)createInvitation;
- (DSInvitation *)createInvitationUsingDerivationIndex:(uint32_t)index;
- (DSInvitation *_Nullable)invitationForUniqueId:(UInt256)uniqueId;
- (void)wipeInvitationsInContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END
