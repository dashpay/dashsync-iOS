//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSContactRelationshipInfoViewController.h"

@interface DSContactRelationshipInfoViewController ()

@end

@implementation DSContactRelationshipInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    DSAccount *account = [self.blockchainIdentity.wallet accountWithNumber:0];

    DSBlockchainIdentity *friend = self.incomingFriendRequest.sourceContact.associatedBlockchainIdentity.blockchainIdentity;

    DSIncomingFundsDerivationPath *incomingDerivationPath = [account derivationPathForFriendshipWithIdentifier:self.incomingFriendRequest.friendshipIdentifier];
    NSAssert(incomingDerivationPath.extendedPublicKey, @"Extended public key must exist already");

    DSIncomingFundsDerivationPath *outgoingDerivationPath = [account derivationPathForFriendshipWithIdentifier:self.outgoingFriendRequest.friendshipIdentifier];
    NSAssert(outgoingDerivationPath.extendedPublicKey, @"Extended public key must exist already");

    self.userIdentifier.text = friend.uniqueIdString;

    self.incomingExtendedPublicKeyLabel.text = incomingDerivationPath.extendedPublicKeyData.hexString;
    self.outgoingExtendedPublicKeyLabel.text = outgoingDerivationPath.extendedPublicKeyData.hexString;

    self.incomingOurKeyIndexUsedForEncryptionLabel.text = [NSString stringWithFormat:@"%@", @(self.incomingFriendRequest.destinationKeyIndex)];
    self.incomingFriendKeyIndexUsedForEncryptionLabel.text = [NSString stringWithFormat:@"%@", @(self.incomingFriendRequest.sourceKeyIndex)];
    self.outgoingOurKeyIndexUsedForEncryptionLabel.text = [NSString stringWithFormat:@"%@", @(self.outgoingFriendRequest.sourceKeyIndex)];
    self.outgoingFriendKeyIndexUsedForEncryptionLabel.text = [NSString stringWithFormat:@"%@", @(self.outgoingFriendRequest.destinationKeyIndex)];

    self.incomingOurKeyUsedForEncryptionLabel.text = [self.blockchainIdentity keyAtIndex:self.incomingFriendRequest.destinationKeyIndex].publicKeyData.hexString;
    self.incomingFriendKeyUsedForEncryptionLabel.text = [friend keyAtIndex:self.incomingFriendRequest.sourceKeyIndex].publicKeyData.hexString;
    self.outgoingOurKeyUsedForEncryptionLabel.text = [self.blockchainIdentity keyAtIndex:self.incomingFriendRequest.sourceKeyIndex].publicKeyData.hexString;
    self.outgoingFriendKeyUsedForEncryptionLabel.text = [friend keyAtIndex:self.incomingFriendRequest.destinationKeyIndex].publicKeyData.hexString;
}

@end
