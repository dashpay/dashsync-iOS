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

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSBlockchainUser,DSAccount,DSBlockchainUserRegistrationTransaction;

@interface DSContact : NSObject

@property (nonatomic, weak, readonly) DSAccount* account;
@property (nonatomic, weak, readonly) DSBlockchainUser * blockchainUserOwner; //this is the holder of the contacts, not the destination
@property (nonatomic, readonly) UInt256 contactBlockchainUserRegistrationTransactionHash;
@property (nonatomic, readonly) NSString * username;

-(instancetype)initWithUsername:(NSString*)username contactsBlockchainUserRegistrationTransactionHash:(UInt256)contactsBlockchainUserRegistrationTransactionHash blockchainUserOwner:(DSBlockchainUser*)blockchainUserOwner account:(DSAccount*)account;

@end

NS_ASSUME_NONNULL_END
