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

#import "BigIntTypes.h"
#import "DSTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSCreditFundingTransaction : DSTransaction

@property (nonatomic, readonly) uint64_t fundingAmount;
@property (nonatomic, readonly) UInt256 creditBurnIdentityIdentifier;
@property (nonatomic, readonly) DSUTXO lockedOutpoint;
@property (nonatomic, readonly) UInt160 creditBurnPublicKeyHash;
@property (nonatomic, readonly) uint32_t usedDerivationPathIndex;

- (uint32_t)usedDerivationPathIndexForWallet:(DSWallet *)wallet;

@end

NS_ASSUME_NONNULL_END
