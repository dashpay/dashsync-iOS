//
//  DSMasternodeManager+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 11/22/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSMasternodeDiffMessageContext.h"
#import "DSMasternodeManager.h"
#import "DSMnDiffProcessingResult.h"
#import "DSQRInfoProcessingResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeManager (Protected)

- (instancetype)initWithChain:(DSChain *_Nonnull)chain;
- (void)setUp;
- (void)loadFileDistributedMasternodeLists;
- (void)wipeMasternodeInfo;
- (void)getRecentMasternodeList:(NSUInteger)blocksAgo withSafetyDelay:(uint32_t)safetyDelay;
- (void)getCurrentMasternodeListWithSafetyDelay:(uint32_t)safetyDelay;
- (void)getMasternodeListsForBlockHashes:(NSOrderedSet *)blockHashes;

- (void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData *)masternodeDiffMessage;
- (void)peer:(DSPeer *)peer relayedQuorumRotationInfoMessage:(NSData *)quorumRotationInfoMessage;

- (DSLocalMasternode *)localMasternodeFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry claimedWithOwnerWallet:(DSWallet *)wallet ownerKeyIndex:(uint32_t)ownerKeyIndex;
- (DSMasternodeDiffMessageContext *)createDiffMessageContextWithLastBlock:(DSMerkleBlock * _Nullable)lastBlock useInsightAsBackup:(BOOL)useInsightAsBackup;
- (void)processMasternodeDiffMessage:(NSData *)message baseMasternodeListHash:(NSData * _Nullable)baseMasternodeListHash lastBlock:(DSMerkleBlock * _Nullable)lastBlock useInsightAsBackup:(BOOL)useInsightAsBackup completion:(void (^)(DSMnDiffProcessingResult *result))completion;
- (void)processQRInfoMessage:(LLMQRotationInfo *)quorumRotationInfo baseMasternodeListHash:(NSData * _Nullable)baseMasternodeListHash lastBlock:(DSMerkleBlock * _Nullable)lastBlock useInsightAsBackup:(BOOL)useInsightAsBackup completion:(void (^)(DSQRInfoProcessingResult *result))completion;

+ (void)saveMasternodeList:(DSMasternodeList *)masternodeList toChain:(DSChain *)chain havingModifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums createUnknownBlocks:(BOOL)createUnknownBlocks inContext:(NSManagedObjectContext *)context completion:(void (^)(NSError *error))completion;

@end


NS_ASSUME_NONNULL_END
