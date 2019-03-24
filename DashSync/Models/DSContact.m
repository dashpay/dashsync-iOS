//  
//  Created by Sam Westrich
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSContact.h"

@interface DSContact()

@property (nonatomic, weak) DSAccount* account;
@property (nonatomic, weak) DSBlockchainUser * blockchainUserOwner;
@property (nonatomic, assign) UInt256 contactBlockchainUserRegistrationTransactionHash;
@property (nonatomic, copy) NSString * username;

@end

@implementation DSContact

-(instancetype)initWithUsername:(NSString*)username contactsBlockchainUserRegistrationTransactionHash:(UInt256)contactsBlockchainUserRegistrationTransactionHash blockchainUserOwner:(DSBlockchainUser*)blockchainUserOwner account:(DSAccount*)account {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.account = account;
    self.blockchainUserOwner = blockchainUserOwner;
    self.contactBlockchainUserRegistrationTransactionHash = contactsBlockchainUserRegistrationTransactionHash;
    return self;
}

@end
