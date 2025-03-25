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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSContactRelationshipInfoViewController : UITableViewController

@property (strong, nonatomic) DSIdentity *identity;
@property (strong, nonatomic) DSFriendRequestEntity *incomingFriendRequest;
@property (strong, nonatomic) DSFriendRequestEntity *outgoingFriendRequest;

@property (strong, nonatomic) IBOutlet UILabel *userIdentifier;

@property (strong, nonatomic) IBOutlet UILabel *outgoingExtendedPublicKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *incomingExtendedPublicKeyLabel;

@property (strong, nonatomic) IBOutlet UILabel *outgoingFriendKeyUsedForEncryptionLabel;
@property (strong, nonatomic) IBOutlet UILabel *outgoingOurKeyUsedForEncryptionLabel;
@property (strong, nonatomic) IBOutlet UILabel *incomingFriendKeyUsedForEncryptionLabel;
@property (strong, nonatomic) IBOutlet UILabel *incomingOurKeyUsedForEncryptionLabel;

@property (strong, nonatomic) IBOutlet UILabel *outgoingFriendKeyIndexUsedForEncryptionLabel;
@property (strong, nonatomic) IBOutlet UILabel *outgoingOurKeyIndexUsedForEncryptionLabel;
@property (strong, nonatomic) IBOutlet UILabel *incomingFriendKeyIndexUsedForEncryptionLabel;
@property (strong, nonatomic) IBOutlet UILabel *incomingOurKeyIndexUsedForEncryptionLabel;

@end

NS_ASSUME_NONNULL_END
