//
//  DSWalletConstants.m
//  DashSync
//
//  Created by Samuel Sutch on 6/3/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString *const DSChainManagerSyncWillStartNotification = @"DSChainManagerSyncWillStartNotification";

NSString *const DSChainManagerChainSyncDidStartNotification = @"DSChainManagerSyncDidStartNotification";
NSString *const DSChainManagerSyncParametersUpdatedNotification = @"DSChainManagerSyncParametersUpdatedNotification";
NSString *const DSChainManagerSyncFinishedNotification = @"DSChainManagerSyncFinishedNotification";
NSString *const DSChainManagerSyncFailedNotification = @"DSChainManagerSyncFailedNotification";

NSString *const DSTransactionManagerTransactionStatusDidChangeNotification = @"DSTransactionManagerTransactionStatusDidChangeNotification";
NSString *const DSTransactionManagerTransactionReceivedNotification = @"DSTransactionManagerTransactionReceivedNotification";

NSString *const DSChainNewChainTipBlockNotification = @"DSChainNewChainTipBlockNotification";
NSString *const DSPeerManagerPeersDidChangeNotification = @"DSPeerManagerPeersDidChangeNotification";
NSString *const DSPeerManagerConnectedPeersDidChangeNotification = @"DSPeerManagerConnectedPeersDidChangeNotification";
NSString *const DSPeerManagerDownloadPeerDidChangeNotification = @"DSPeerManagerDownloadPeerDidChangeNotification";

NSString *const DSChainWalletsDidChangeNotification = @"DSChainWalletsDidChangeNotification";

NSString *const DSChainStandaloneDerivationPathsDidChangeNotification = @"DSChainStandaloneDerivationPathsDidChangeNotification";
NSString *const DSChainStandaloneAddressesDidChangeNotification = @"DSChainStandaloneAddressesDidChangeNotification";
NSString *const DSChainChainSyncBlocksDidChangeNotification = @"DSChainChainSyncBlocksDidChangeNotification";
NSString *const DSChainTerminalBlocksDidChangeNotification = @"DSChainTerminalBlocksDidChangeNotification";
NSString *const DSChainInitialHeadersDidFinishSyncingNotification = @"DSChainInitialHeadersDidFinishSyncingNotification";
NSString *const DSChainBlocksDidFinishSyncingNotification = @"DSChainBlocksDidFinishSyncingNotification";
NSString *const DSChainBlockWasLockedNotification = @"DSChainBlockWasLockedNotification";
NSString *const DSChainNotificationBlockKey = @"DSChainNotificationBlockKey";

NSString *const DSTransactionManagerFilterDidChangeNotification = @"DSTransactionManagerFilterDidChangeNotification";

NSString *const DSWalletBalanceDidChangeNotification = @"DSWalletBalanceChangedNotification";
NSString *const DSExchangeRatesReportedNotification = @"DSExchangeRatesReportedNotification";
NSString *const DSExchangeRatesErrorKey = @"DSExchangeRatesErrorKey";

NSString *const DSAccountNewAccountFromTransactionNotification = @"DSAccountNewAccountFromTransactionNotification";
NSString *const DSAccountNewAccountShouldBeAddedFromTransactionNotification = @"DSAccountNewAccountShouldBeAddedFromTransactionNotification";

NSString *const DSSporkListDidUpdateNotification = @"DSSporkListDidUpdateNotification";

NSString *const DSMasternodeListDidChangeNotification = @"DSMasternodeListDidChangeNotification";

NSString *const DSCurrentMasternodeListDidChangeNotification = @"DSCurrentMasternodeListDidChangeNotification";

NSString *const DSMasternodeManagerNotificationMasternodeListKey = @"DSMasternodeManagerNotificationMasternodeListKey";

NSString *const DSQuorumListDidChangeNotification = @"DSQuorumListDidChangeNotification";

NSString *const DSMasternodeListDiffValidationErrorNotification = @"DSMasternodeListDiffValidationErrorNotification"; //Also for Quorums

NSString *const DSGovernanceObjectListDidChangeNotification = @"DSGovernanceObjectListDidChangeNotification";
NSString *const DSGovernanceVotesDidChangeNotification = @"DSGovernanceVotesDidChangeNotification";
NSString *const DSGovernanceObjectCountUpdateNotification = @"DSGovernanceObjectCountUpdateNotification";
NSString *const DSGovernanceVoteCountUpdateNotification = @"DSGovernanceVoteCountUpdateNotification";

NSString *const DSChainsDidChangeNotification = @"DSChainsDidChangeNotification";

NSString *const DSChainManagerNotificationChainKey = @"DSChainManagerNotificationChainKey";
NSString *const DSChainManagerNotificationWalletKey = @"DSChainManagerNotificationWalletKey";
NSString *const DSChainManagerNotificationAccountKey = @"DSChainManagerNotificationAccountKey";

NSString *const DSPeerManagerNotificationPeerKey = @"DSPeerManagerNotificationPeerKey";

NSString *const DSTransactionManagerNotificationTransactionKey = @"DSTransactionManagerNotificationTransactionKey";
NSString *const DSTransactionManagerNotificationTransactionChangesKey = @"DSTransactionManagerNotificationTransactionChangesKey";

NSString *const DSTransactionManagerNotificationInstantSendTransactionLockKey = @"DSTransactionManagerNotificationInstantSendTransactionLockKey";

NSString *const DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey = @"DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey";

NSString *const DSTransactionManagerNotificationTransactionAcceptedStatusKey = @"DSTransactionManagerNotificationTransactionAcceptedStatusKey";

NSString *const DPContractDidUpdateNotification = @"DPContractDidUpdateNotification";

NSString *const DSContractUpdateNotificationKey = @"DSContractUpdateNotificationKey";

NSString *const DSBlockchainIdentityDidUpdateNotification = @"DSBlockchainIdentitiesDidUpdateNotification";

NSString *const DSBlockchainIdentityDidUpdateUsernameStatusNotification = @"DSBlockchainIdentityDidUpdateUsernameStatusNotification";

NSString *const DSBlockchainIdentityKey = @"DSBlockchainIdentityKey";

NSString *const DSBlockchainIdentityUsernameKey = @"DSBlockchainIdentityUsernameKey";

NSString *const DSBlockchainIdentityUsernameDomainKey = @"DSBlockchainIdentityUsernameDomainKey";

NSString *const DSBlockchainIdentityUpdateEvents = @"DSBlockchainIdentityUpdateEvents";

NSString *const DSBlockchainIdentityUpdateEventKeyUpdate = @"DSBlockchainIdentityUpdateEventKeyUpdate";

NSString *const DSBlockchainIdentityUpdateEventRegistration = @"DSBlockchainIdentityUpdateEventRegistration";

NSString *const DSBlockchainIdentityUpdateEventCreditBalance = @"DSBlockchainIdentityUpdateEventCreditBalance";

NSString *const DSBlockchainIdentityUpdateEventDashpaySyncronizationBlockHash = @"DSBlockchainIdentityUpdateEventDashpaySyncronizationBlockHash";

NSString *const DSBlockchainInvitationDidUpdateNotification = @"DSBlockchainInvitationDidUpdateNotification";

NSString *const DSBlockchainInvitationKey = @"DSBlockchainInvitationKey";

NSString *const DSBlockchainInvitationUpdateEvents = @"DSBlockchainInvitationUpdateEvents";

NSString *const DSBlockchainInvitationUpdateEventLink = @"DSBlockchainInvitationUpdateEventLink";
