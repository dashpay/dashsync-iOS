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

#import "DSSimpleIndexedDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain;

@interface DSCreditFundingDerivationPath : DSSimpleIndexedDerivationPath

+ (instancetype)blockchainIdentityRegistrationFundingDerivationPathForWallet:(DSWallet*)wallet;
+ (instancetype)blockchainIdentityTopupFundingDerivationPathForWallet:(DSWallet*)wallet;

- (NSString*)receiveAddress;

- (void)signTransaction:(DSTransaction *)transaction withPrompt:(NSString *)authprompt completion:(TransactionValidityCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
