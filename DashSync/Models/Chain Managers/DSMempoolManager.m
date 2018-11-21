//
//  DSMempoolManager.m
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
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

#import "DSMempoolManager.h"
#import "DSOptionsManager.h"
#import "DSChain.h"

@implementation DSMempoolManager

- (instancetype)initWithChain:(id)chain
{
    if (! (self = [super init])) return nil;
    _chain = chain;
    self.managedObjectContext = [NSManagedObject context];
    return self;
}

-(DSPeerManager*)peerManager {
    return chain.chainManager.peerManager;
}


// MARK: - Mempools Sync

- (void)loadMempools
{
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Mempools)) return; // make sure we care about sporks
    for (DSPeer *p in self.connectedPeers) { // after syncing, load filters and get mempools from other peers
        if (p.status != DSPeerStatus_Connected) continue;
        
        if ([self.chain canConstructAFilter] && (p != self.downloadPeer || self.fpRate > BLOOM_REDUCED_FALSEPOSITIVE_RATE*5.0)) {
            [p sendFilterloadMessage:[self bloomFilterForPeer:p].data];
        }
        
        [p sendInvMessageForHashes:self.publishedCallback.allKeys ofType:DSInvType_Tx]; // publish pending tx
        [p sendPingMessageWithPongHandler:^(BOOL success) {
            if (success) {
                [p sendMempoolMessage:self.publishedTx.allKeys completion:^(BOOL success) {
                    if (success) {
                        p.synced = YES;
                        [self removeUnrelayedTransactions];
                        [p sendGetaddrMessage]; // request a list of other bitcoin peers
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter]
                             postNotificationName:DSChainPeerManagerTxStatusNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self.chain}];
                        });
                    }
                    
                    if (p == self.downloadPeer) {
                        [self syncStopped];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter]
                             postNotificationName:DSChainPeerManagerSyncFinishedNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self.chain}];
                        });
                    }
                }];
            }
            else if (p == self.downloadPeer) {
                [self syncStopped];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter]
                     postNotificationName:DSChainPeerManagerSyncFinishedNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self.chain}];
                });
            }
        }];
    }
}

@end
