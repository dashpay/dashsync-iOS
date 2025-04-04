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
#import "DSTransaction.h"
#import "DSTransactionOutput.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSAssetLockTransaction : DSTransaction

@property (nonatomic, assign) uint8_t specialTransactionVersion;
@property (nonatomic, strong) NSMutableArray<DSTransactionOutput *> *creditOutputs;
@property (nonatomic, readonly) UInt160 creditBurnPublicKeyHash;
@property (nonatomic, readonly) DSUTXO lockedOutpoint;

- (instancetype)initOnChain:(DSChain *)chain withCreditOutputs:(NSArray<DSTransactionOutput *> *)creditOutputs payloadVersion:(uint8_t)payloadVersion;

- (instancetype)initWithInputHashes:(NSArray *)hashes
                       inputIndexes:(NSArray *)indexes
                       inputScripts:(NSArray *)scripts
                     inputSequences:(NSArray *)inputSequences
                    outputAddresses:(NSArray *)addresses
                      outputAmounts:(NSArray *)amounts
                      creditOutputs:(NSArray<DSTransactionOutput *> *)creditOutputs
                     payloadVersion:(uint8_t)payloadVersion
                            onChain:(DSChain *)chain;


- (BOOL)checkInvitationDerivationPathIndexForWallet:(DSWallet *)wallet isIndex:(uint32_t)index;
- (BOOL)checkDerivationPathIndexForWallet:(DSWallet *)wallet isIndex:(uint32_t)index;

- (void)markInvitationAddressAsUsedInWallet:(DSWallet *)wallet;
- (void)markAddressAsUsedInWallet:(DSWallet *)wallet;

@end

NS_ASSUME_NONNULL_END
