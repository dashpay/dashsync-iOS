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
#import "DSChain.h"
#import "DSTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain (Transaction)

// MARK: - Transactions

/*! @brief Returns all wallet transactions sorted by date, most recent first.  */
@property (nonatomic, readonly) NSArray<DSTransaction *> *allTransactions;

/*! @brief Returns the transaction with the given hash if it's been registered in any wallet on the chain (might also return non-registered) */
- (DSTransaction *_Nullable)transactionForHash:(UInt256)txHash;

///*! @brief Returns the direction of a transaction for the chain (Sent - Received - Moved - Not Account Funds) */
//- (DSTransactionDirection)directionOfTransaction:(DSTransaction *)transaction;

/*! @brief Returns the amount received globally from the transaction (total outputs to change and/or receive addresses) */
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction;

/*! @brief Returns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included) */
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction;

/*! @brief Returns if this transaction has any local references. Local references are a pubkey hash contained in a wallet, pubkeys in wallets special derivation paths, or anything that would make the transaction relevant for this device. */
- (BOOL)transactionHasLocalReferences:(DSTransaction *)transaction;


// MARK: Protected
- (BOOL)registerSpecialTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately;

- (void)triggerUpdatesForLocalReferences:(DSTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
