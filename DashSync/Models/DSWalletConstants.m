//
//  DSWalletConstants.m
//  DashSync
//
//  Created by Samuel Sutch on 6/3/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* const DSTransactionManagerSyncStartedNotification =      @"DSTransactionManagerSyncStartedNotification";
NSString* const DSTransactionManagerSyncFinishedNotification =     @"DSTransactionManagerSyncFinishedNotification";
NSString* const DSTransactionManagerSyncFailedNotification =       @"DSTransactionManagerSyncFailedNotification";
NSString* const DSTransactionManagerTransactionStatusDidChangeNotification =         @"DSTransactionManagerTransactionStatusDidChangeNotification";
NSString* const DSTransactionManagerTransactionReceivedNotification =         @"DSTransactionManagerTransactionReceivedNotification";

NSString* const DSChainNewChainTipBlockNotification =         @"DSChainNewChainTipBlockNotification";
NSString* const DSPeerManagerPeersDidChangeNotification =      @"DSPeerManagerPeersDidChangeNotification";
NSString* const DSPeerManagerConnectedPeersDidChangeNotification =      @"DSPeerManagerConnectedPeersDidChangeNotification";
NSString* const DSPeerManagerDownloadPeerDidChangeNotification =      @"DSPeerManagerDownloadPeerDidChangeNotification";

NSString* const DSChainWalletsDidChangeNotification =    @"DSChainWalletsDidChangeNotification";
NSString* const DSChainBlockchainIdentitiesDidChangeNotification =    @"DSChainBlockchainIdentitiesDidChangeNotification";

NSString* const DSChainStandaloneDerivationPathsDidChangeNotification =    @"DSChainStandaloneDerivationPathsDidChangeNotification";
NSString* const DSChainStandaloneAddressesDidChangeNotification = @"DSChainStandaloneAddressesDidChangeNotification";
NSString* const DSChainBlocksDidChangeNotification = @"DSChainBlocksDidChainNotification";
NSString* const DSChainBlockWasLockedNotification = @"DSChainBlockWasLockedNotification";
NSString* const DSChainNotificationBlockKey = @"DSChainNotificationBlockKey";

NSString* const DSWalletBalanceDidChangeNotification =        @"DSWalletBalanceChangedNotification";

NSString* const DSSporkListDidUpdateNotification =     @"DSSporkListDidUpdateNotification";

NSString* const DSMasternodeListDidChangeNotification = @"DSMasternodeListDidChangeNotification";

NSString* const DSQuorumListDidChangeNotification = @"DSQuorumListDidChangeNotification";

NSString* const DSMasternodeListDiffValidationErrorNotification = @"DSMasternodeListDiffValidationErrorNotification"; //Also for Quorums

NSString* const DSGovernanceObjectListDidChangeNotification = @"DSGovernanceObjectListDidChangeNotification";
NSString* const DSGovernanceVotesDidChangeNotification = @"DSGovernanceVotesDidChangeNotification";
NSString* const DSGovernanceObjectCountUpdateNotification = @"DSGovernanceObjectCountUpdateNotification";
NSString* const DSGovernanceVoteCountUpdateNotification = @"DSGovernanceVoteCountUpdateNotification";

NSString* const DSChainsDidChangeNotification = @"DSChainsDidChangeNotification";

NSString* const DSChainManagerNotificationChainKey =         @"DSChainManagerNotificationChainKey";

NSString* const DSTransactionManagerNotificationTransactionKey =         @"DSTransactionManagerNotificationTransactionKey";
NSString* const DSTransactionManagerNotificationTransactionChangesKey =         @"DSTransactionManagerNotificationTransactionChangesKey";

NSString* const DSTransactionManagerNotificationInstantSendTransactionLockKey =         @"DSTransactionManagerNotificationInstantSendTransactionLockKey";

NSString* const DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey =         @"DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey";

NSString* const DSTransactionManagerNotificationInstantSendTransactionAcceptedStatusKey =         @"DSTransactionManagerNotificationInstantSendTransactionAcceptedStatusKey";

NSString* const DPContractDidUpdateNotification = @"DPContractDidUpdateNotification";

NSString* const DSContractUpdateNotificationKey = @"DSContractUpdateNotificationKey";
