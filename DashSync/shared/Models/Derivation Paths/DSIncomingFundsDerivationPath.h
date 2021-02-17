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

#import "DSDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSIncomingFundsDerivationPath : DSDerivationPath

@property (nonatomic, readonly) UInt256 contactSourceBlockchainIdentityUniqueId;
@property (nonatomic, readonly) UInt256 contactDestinationBlockchainIdentityUniqueId;
@property (nonatomic, readonly) DSBlockchainIdentity *contactSourceBlockchainIdentity;
@property (nonatomic, readonly) DSBlockchainIdentity *contactDestinationBlockchainIdentity;
@property (nonatomic, readonly) BOOL sourceIsLocal;
@property (nonatomic, readonly) BOOL destinationIsLocal;

+ (instancetype)contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:(UInt256)destinationBlockchainIdentityUniqueId sourceBlockchainIdentityUniqueId:(UInt256)sourceBlockchainIdentityUniqueId forAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain;

//The extended public key will be saved to disk (storeExternalDerivationPathExtendedPublicKeyToKeyChain call needed)
+ (instancetype)externalDerivationPathWithExtendedPublicKey:(DSKey *)extendedPublicKey withDestinationBlockchainIdentityUniqueId:(UInt256)destinationBlockchainIdentityUniqueId sourceBlockchainIdentityUniqueId:(UInt256)sourceBlockchainIdentityUniqueId onChain:(DSChain *)chain;

//The extended public key will be loaded from disk
+ (instancetype)externalDerivationPathWithExtendedPublicKeyUniqueID:(NSString *)extendedPublicKeyUniqueId withDestinationBlockchainIdentityUniqueId:(UInt256)destinationBlockchainIdentityUniqueId sourceBlockchainIdentityUniqueId:(UInt256)sourceBlockchainIdentityUniqueId onChain:(DSChain *)chain;

// returns the first unused external address
@property (nonatomic, readonly, nullable) NSString *receiveAddress;

// all previously generated external addresses
@property (nonatomic, readonly) NSArray *allReceiveAddresses;

// used external addresses
@property (nonatomic, readonly) NSArray *usedReceiveAddresses;

- (NSArray *_Nullable)registerAddressesWithGapLimit:(NSUInteger)gapLimit error:(NSError *_Nullable *_Nullable)error;

- (NSString *_Nullable)privateKeyStringAtIndex:(uint32_t)n fromSeed:(NSData *)seed;
- (NSArray *_Nullable)serializedPrivateKeys:(NSArray *)n fromSeed:(NSData *)seed;
- (NSArray *_Nullable)privateKeys:(NSArray *)n fromSeed:(NSData *)seed;

- (NSData *_Nullable)publicKeyDataAtIndex:(uint32_t)n;

// gets an addess at an index one level down based on bip32
- (NSString *)addressAtIndex:(uint32_t)index;

- (NSString *)receiveAddressAtOffset:(NSUInteger)offset;

- (NSIndexPath *_Nullable)indexPathForKnownAddress:(NSString *)address;

- (void)storeExternalDerivationPathExtendedPublicKeyToKeyChain;

- (void)loadAddressesInContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END
