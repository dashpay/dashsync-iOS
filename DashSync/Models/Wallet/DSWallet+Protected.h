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

#import "DSWallet.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSWallet ()

@property (nonatomic, readonly) NSString * mnemonicUniqueID;

@property (nonatomic, readonly) NSString * creationTimeUniqueID;

@property (nonatomic, readonly) SeedRequestBlock seedRequestBlock;

@property (nonatomic, readonly) BOOL hasAnExtendedPublicKeyMissing;

//this is used from the account to help determine best start sync position for future resync
- (void)setGuessedWalletCreationTime:(NSTimeInterval)guessedWalletCreationTime;

//get the MNEMONIC KEY prefixed unique ID
+ (NSString* _Nonnull)mnemonicUniqueIDForUniqueID:(NSString*)uniqueID;

//get the CREATION TIME KEY prefixed unique ID
+ (NSString* _Nonnull)creationTimeUniqueIDForUniqueID:(NSString*)uniqueID;

+ (NSOrderedSet*)blockZonesFromChainSynchronizationFingerprint:(NSData*)chainSynchronizationFingerprint;

+ (NSData*)chainSynchronizationFingerprintForBlockZones:(NSOrderedSet *)blockHeightZones forChainHeight:(uint32_t)chainHeight;

- (void)loadBlockchainIdentities;

@end

NS_ASSUME_NONNULL_END
