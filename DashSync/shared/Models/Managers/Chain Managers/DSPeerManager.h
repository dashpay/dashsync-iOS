//
//  DSPeerManager.h
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 10/6/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//  Updated by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
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

#import "DSChain.h"
#import "DSMessageRequest.h"
#import "DSPeer.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *_Nonnull const DSPeerManagerNotificationPeerKey;

FOUNDATION_EXPORT NSString *_Nonnull const DSPeerManagerConnectedPeersDidChangeNotification;
FOUNDATION_EXPORT NSString *_Nonnull const DSPeerManagerDownloadPeerDidChangeNotification;
FOUNDATION_EXPORT NSString *_Nonnull const DSPeerManagerPeersDidChangeNotification;

FOUNDATION_EXPORT NSString *_Nonnull const DSPeerManagerFilterDidChangeNotification;

#define PEER_MAX_CONNECTIONS 5
#define SETTINGS_FIXED_PEER_KEY @"SETTINGS_FIXED_PEER"


#define LAST_SYNCED_GOVERANCE_OBJECTS @"LAST_SYNCED_GOVERANCE_OBJECTS"
#define LAST_SYNCED_MASTERNODE_LIST @"LAST_SYNCED_MASTERNODE_LIST"

@class DSTransaction, DSGovernanceSyncManager, DSMasternodeManager, DSSporkManager, DSPeer, DSGovernanceVote, DSDAPIPeerManager, DSTransactionManager;

@interface DSPeerManager : NSObject <DSPeerDelegate
#if TARGET_OS_IOS
                               ,
                               UIAlertViewDelegate
#endif
                               >

@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly) NSUInteger peerCount;
@property (nonatomic, readonly) NSUInteger connectedPeerCount; // number of connected peers
@property (nullable, nonatomic, readonly) NSString *downloadPeerName;
@property (nonatomic, readonly) DSChain *chain;
@property (nullable, nonatomic, readonly) DSPeer *downloadPeer;
@property (nullable, nonatomic, readonly) DSPeer *fixedPeer;
@property (nonatomic, readonly) NSArray *registeredDevnetPeers;
@property (nonatomic, readonly) NSArray *registeredDevnetPeerServices;
@property (nullable, nonatomic, readonly) NSString *trustedPeerHost;

- (DSPeerStatus)statusForLocation:(UInt128)IPAddress port:(uint32_t)port;
- (DSPeerType)typeForLocation:(UInt128)IPAddress port:(uint32_t)port;
- (void)setTrustedPeerHost:(NSString *_Nullable)host;
- (void)removeTrustedPeerHost;


- (void)clearPeers;
- (void)connect;
- (void)disconnect;

- (void)clearRegisteredPeers;
- (void)registerPeerAtLocation:(UInt128)IPAddress port:(uint32_t)port dapiJRPCPort:(uint32_t)dapiJRPCPort dapiGRPCPort:(uint32_t)dapiGRPCPort;

- (void)sendRequest:(DSMessageRequest *)request;

@end

NS_ASSUME_NONNULL_END
