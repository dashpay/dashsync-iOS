//
//  DSExampleViewController.m
//  DashSync
//
//  Created by Andrew Podkovyrin on 03/19/2018.
//  Copyright (c) 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>

#import "BRBubbleView.h"
#import "DSActionsViewController.h"
#import "DSBlockchainExplorerViewController.h"
#import "DSIdentitiesViewController.h"
#import "DSBloomFilter.h"
#import "DSGovernanceObjectListViewController.h"
#import "DSInvitationsViewController.h"
#import "DSLayer2ViewController.h"
#import "DSMasternodeListsViewController.h"
#import "DSMasternodeViewController.h"
#import "DSNetworkActivityView.h"
#import "DSPasteboardAddressExtractor.h"
#import "DSPeersViewController.h"
#import "DSQuorumListViewController.h"
#import "DSSearchIdentitiesViewController.h"
#import "DSSporksViewController.h"
#import "DSStandaloneDerivationPathViewController.h"
#import "DSSyncViewController.h"
#import "DSTransactionManager.h"
#import "DSTransactionsViewController.h"
#import "DSWalletViewController.h"

@interface DSSyncViewController ()

@property (strong, nonatomic) IBOutlet UILabel *explanationLabel;
@property (strong, nonatomic) IBOutlet UILabel *percentageLabel;
@property (strong, nonatomic) IBOutlet UILabel *dbSizeLabel;
@property (strong, nonatomic) IBOutlet UILabel *filterSizeLabel;
@property (strong, nonatomic) IBOutlet UILabel *filterAddressesLabel;
@property (strong, nonatomic) IBOutlet UILabel *lastBlockHeightLabel;
@property (strong, nonatomic) IBOutlet UILabel *syncProgressLabel;
@property (strong, nonatomic) IBOutlet UILabel *syncStateLabel;
@property (strong, nonatomic) IBOutlet UILabel *peersSyncStateLabel;
@property (strong, nonatomic) IBOutlet UILabel *headersSyncStateLabel;
@property (strong, nonatomic) IBOutlet UILabel *blocksSyncStateLabel;
@property (strong, nonatomic) IBOutlet UILabel *masternodesSyncStateLabel;
@property (strong, nonatomic) IBOutlet UILabel *platformSyncStateLabel;
@property (strong, nonatomic) IBOutlet UILabel *lastMasternodeBlockHeightLabel;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView, *pulseView;
@property (assign, nonatomic) NSTimeInterval timeout, start;
@property (strong, nonatomic) IBOutlet UILabel *connectedPeerCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *peerCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *downloadPeerLabel;
@property (strong, nonatomic) IBOutlet UILabel *chainTipLabel;
@property (strong, nonatomic) IBOutlet UILabel *transactionCountBalanceLabel;
@property (strong, nonatomic) IBOutlet UILabel *walletCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *standaloneDerivationPathsCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *standaloneAddressesCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *sporksCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *masternodeCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *quorumCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *localMasternodesCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *masternodeListUpdatedLabel;
@property (strong, nonatomic) IBOutlet UILabel *receivedProposalCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *receivedVotesCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *identitiesCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *invitationsCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *receivingAddressLabel;
@property (strong, nonatomic) IBOutlet UILabel *pasteboardAddressLabel;
@property (strong, nonatomic) IBOutlet UILabel *masternodeListsCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *earliestMasternodeListLabel;
@property (strong, nonatomic) IBOutlet UILabel *lastMasternodeListLabel;
@property (strong, nonatomic) id filterChangedObserver, syncFinishedObserver, syncFailedObserver, balanceObserver, syncStateObserver, sporkObserver, masternodeObserver, masternodeCountObserver, chainWalletObserver, chainStandaloneDerivationPathObserver, chainSingleAddressObserver, governanceObjectCountObserver, governanceObjectReceivedCountObserver, governanceVoteCountObserver, governanceVoteReceivedCountObserver, connectedPeerConnectionObserver, peerConnectionObserver, identitiesObserver, invitationsObserver, quorumObserver;
@property (strong, nonatomic) DSPasteboardAddressExtractor *pasteboardExtractor;

- (IBAction)startSync:(id)sender;
- (IBAction)stopSync:(id)sender;
- (IBAction)wipeData:(id)sender;
- (IBAction)sendToPasteboard:(id)sender;

@end

@implementation DSSyncViewController

+ (id <NSObject>)addObserver:(nullable NSNotificationName)name usingBlock:(void (^)(NSNotification *notification))block {
    return [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil usingBlock:block];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _pasteboardExtractor = [[DSPasteboardAddressExtractor alloc] init];

    [self updateReceivingAddress];
    [self updateBalance];
    [self updateSporks];
    [self updateBlockHeight];
    [self updateHeaderHeight];
    [self updateKnownMasternodes];
    [self updateMasternodeLists];
    [self updateQuorumsList];
    [self updateWalletCount];
    [self updateStandaloneDerivationPathsCount];
    [self updateSingleAddressesCount];
    [self updateReceivedGovernanceProposalCount];
    [self updateReceivedGovernanceVoteCount];
    [self updateIdentitiesCount];
    [self updateInvitationsCount];
    [self updatePeerCount];
    [self updateConnectedPeerCount];
    [self updateFilterInfo];
    [self updateWithSyncState:self.chainManager.syncState];

    self.filterChangedObserver = [[self class] addObserver:DSTransactionManagerFilterDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateFilterInfo];
    }];
    self.syncFinishedObserver = [[self class] addObserver:DSChainManagerSyncFinishedNotification usingBlock:^(NSNotification *note) {
        [self syncFinished];
    }];
    self.syncFailedObserver = [[self class] addObserver:DSChainManagerSyncFailedNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self syncFailed];
    }];
    self.connectedPeerConnectionObserver = [[self class] addObserver:DSPeerManagerConnectedPeersDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateConnectedPeerCount];
    }];
    self.peerConnectionObserver = [[self class] addObserver:DSPeerManagerPeersDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updatePeerCount];
    }];
    self.syncStateObserver = [[self class] addObserver:DSChainManagerSyncStateDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
            DSSyncState *state = note.userInfo[DSChainManagerNotificationSyncStateKey];
            [self updateBlockHeight];
            [self updateHeaderHeight];
            [self updateBalance];
            [self updateProgressView:state];
        }
    }];
    self.balanceObserver = [[self class] addObserver:DSWalletBalanceDidChangeNotification usingBlock:^(NSNotification *note) {
        if (!note.userInfo[DSChainManagerNotificationChainKey] || [note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateBalance];
    }];
    self.sporkObserver = [[self class] addObserver:DSSporkListDidUpdateNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateSporks];
    }];
    self.masternodeObserver = [[self class] addObserver:DSMasternodeListDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
            [self updateKnownMasternodes];
            [self updateMasternodeLists];
        }
    }];
    self.quorumObserver = [[self class] addObserver:DSQuorumListDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateQuorumsList];
    }];
    self.governanceObjectCountObserver = [[self class] addObserver:DSGovernanceObjectCountUpdateNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateReceivedGovernanceProposalCount];
    }];
    self.governanceObjectReceivedCountObserver = [[self class] addObserver:DSGovernanceObjectListDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateReceivedGovernanceProposalCount];
    }];

    self.governanceVoteCountObserver = [[self class] addObserver:DSGovernanceVoteCountUpdateNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateReceivedGovernanceVoteCount];
    }];
    self.governanceVoteReceivedCountObserver = [[self class] addObserver:DSGovernanceVotesDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateReceivedGovernanceVoteCount];
    }];
    self.chainWalletObserver = [[self class] addObserver:DSChainWalletsDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateWalletCount];
    }];

    self.identitiesObserver = [[self class] addObserver:DSIdentityDidUpdateNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateIdentitiesCount];
    }];

    self.invitationsObserver = [[self class] addObserver:DSInvitationDidUpdateNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateInvitationsCount];
    }];
    self.chainStandaloneDerivationPathObserver = [[self class] addObserver:DSChainStandaloneDerivationPathsDidChangeNotification usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]])
            [self updateStandaloneDerivationPathsCount];
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateReceivingAddress];
    [self updateBalance];
    [self updateSporks];
    [self updateBlockHeight];
    [self updateHeaderHeight];
    [self updateKnownMasternodes];
    [self updateMasternodeLists];
    [self updateQuorumsList];
    [self updateWalletCount];
    [self updateStandaloneDerivationPathsCount];
    [self updateSingleAddressesCount];
    [self updateReceivedGovernanceProposalCount];
    [self updateReceivedGovernanceVoteCount];
    [self updateIdentitiesCount];
    [self updateInvitationsCount];
    [self updatePeerCount];
    [self updateConnectedPeerCount];
    [self updateFilterInfo];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (DSChain *)chain {
    return self.chainManager.chain;
}

- (void)showSyncingWithState:(DSSyncState *)state {
    double progress = state.progress;

    if (progress > DBL_EPSILON && progress + DBL_EPSILON < 1.0 && self.chainManager.chain.earliestWalletCreationTime + DAY_TIME_INTERVAL < [NSDate timeIntervalSince1970]) {
        self.explanationLabel.text = NSLocalizedString(@"Syncing:", nil);
    }
}

- (void)startActivityWithTimeout:(NSTimeInterval)timeout {
    NSTimeInterval start = [NSDate timeIntervalSince1970];

    if (timeout > 1 && start + timeout > self.start + self.timeout) {
        self.timeout = timeout;
        self.start = start;
    }

    if (timeout <= DBL_EPSILON) {
        if ([self.chain timestampForBlockHeight:self.chainManager.syncState.lastSyncBlockHeight] + WEEK_TIME_INTERVAL < [NSDate timeIntervalSince1970]) {
            if (self.chainManager.chain.earliestWalletCreationTime + DAY_TIME_INTERVAL < start)
                self.explanationLabel.text = NSLocalizedString(@"Syncing", nil);
        } else
            [self performSelector:@selector(showSyncingWithState:) withObject:self.chainManager.syncState afterDelay:5.0];
    }

    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [[DSNetworkActivityView shared] start];
    self.progressView.hidden = self.pulseView.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        self.progressView.alpha = 1.0;
    }];
    [self updateProgressView:[self.chainManager.syncState copy]];
}

- (void)setProgressViewTo:(NSNumber *)n {
    self.progressView.progress = n.floatValue;
}

- (void)updateWithSyncState:(DSSyncState *)state {
    self.peersSyncStateLabel.text = state.peersDescription;
    self.headersSyncStateLabel.text = state.headersDescription;
    self.blocksSyncStateLabel.text = state.chainDescription;
    self.masternodesSyncStateLabel.text = state.masternodesDescription;
    self.platformSyncStateLabel.text = state.platformDescription;
    self.syncStateLabel.text = DSSyncStateExtKindDescription(state.extKind);
}

- (void)updateProgressView:(DSSyncState *)state {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateProgressView:) object:nil];

    static int counter = 0;
    NSTimeInterval elapsed = [NSDate timeIntervalSince1970] - self.start;
    double progress = state.progress;
    uint64_t dbFileSize = [DashSync sharedSyncController].dbSize;
    uint32_t lastBlockHeight = state.lastSyncBlockHeight;
    uint32_t lastHeaderHeight = state.lastTerminalBlockHeight;
    if (self.timeout > 1.0 && 0.1 + 0.9 * elapsed / self.timeout < progress) progress = 0.1 + 0.9 * elapsed / self.timeout;

    if ((counter % 13) == 0) {
        self.pulseView.alpha = 1.0;
        [self.pulseView setProgress:progress animated:progress > self.pulseView.progress];
        [self.progressView setProgress:progress animated:progress > self.progressView.progress];

        if (progress > self.progressView.progress) {
            [self performSelector:@selector(setProgressViewTo:) withObject:@(progress) afterDelay:1.0];
        } else
            self.progressView.progress = progress;

        [UIView animateWithDuration:1.59
                              delay:1.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             self.pulseView.alpha = 0.0;
                         }
                         completion:nil];

        [self.pulseView performSelector:@selector(setProgress:) withObject:nil afterDelay:2.59];
    } else if ((counter % 13) >= 5) {
        [self.progressView setProgress:progress animated:progress > self.progressView.progress];
        [self.pulseView setProgress:progress animated:progress > self.pulseView.progress];
    }

    counter++;

    self.explanationLabel.text = NSLocalizedString(@"Syncing", nil);
    self.percentageLabel.text = [NSString stringWithFormat:@"%0.1f%%", (progress > 0.1 ? progress - 0.1 : 0.0) * 111.0];
    self.dbSizeLabel.text = [NSString stringWithFormat:@"%0.1llu KB", dbFileSize / 1000];
    self.lastBlockHeightLabel.text = [NSString stringWithFormat:@"%d", lastBlockHeight];
    self.syncProgressLabel.text = [NSString stringWithFormat:@"%f", progress];
    [self updateWithSyncState:state];
    self.lastMasternodeBlockHeightLabel.text = [NSString stringWithFormat:@"%d", lastHeaderHeight];
    self.downloadPeerLabel.text = self.chainManager.peerManager.downloadPeerName;
    self.chainTipLabel.text = self.chain.chainTip;
    if (progress + DBL_EPSILON >= 1.0) {
        self.percentageLabel.text = @"100%";
        if (self.timeout < 1.0) {
            self.start = self.timeout = 0.0;
            if (progress > DBL_EPSILON && progress + DBL_EPSILON < 1.0) return; // not done syncing
            [UIApplication sharedApplication].idleTimerDisabled = NO;
            [[DSNetworkActivityView shared] stop];
            if (self.progressView.alpha < 0.5) return;

            [self.progressView setProgress:1.0 animated:YES];
            [self.pulseView setProgress:1.0 animated:YES];

            [UIView animateWithDuration:0.2 animations:^{
                self.progressView.alpha = self.pulseView.alpha = 0.0;
            }
                             completion:^(BOOL finished) {
                self.progressView.hidden = self.pulseView.hidden = YES;
                self.progressView.progress = self.pulseView.progress = 0.0;
            }];

        }
    }
//    else
//        [self performSelector:@selector(updateProgressView:) withObject:state afterDelay:0.2];
}

- (void)updateFilterInfo {
    self.filterSizeLabel.text = [NSString stringWithFormat:@"%lu B", (unsigned long)self.chainManager.transactionManager.bloomFilter.length];
    self.filterAddressesLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.chainManager.transactionManager.bloomFilter.elementCount];
}

- (IBAction)startSync:(id)sender {
    [[DashSync sharedSyncController] startSyncForChain:self.chainManager.chain];
    [self startActivityWithTimeout:5.0];
}

- (IBAction)stopSync:(id)sender {
    [[DashSync sharedSyncController] stopSyncForChain:self.chainManager.chain];
    [self startActivityWithTimeout:5.0];
}

- (IBAction)wipeData:(id)sender {
    UIAlertController *wipeDataAlertController = [UIAlertController alertControllerWithTitle:@"What do you wish to Wipe?" message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Peer Data"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
                                                                  [[DashSync sharedSyncController] wipePeerDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext peerContext]];
                                                              }]];

    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Chain Sync Data"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
                                                                  [[DashSync sharedSyncController] wipeBlockchainNonTerminalDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
                                                              }]];

    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"All Chain Data"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
                                                                  [[NSManagedObjectContext chainContext] performBlock:^{
                                                                      [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
                                                                      [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
                                                                  }];
                                                              }]];

    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Masternode Data"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
                                                                  [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
                                                              }]];

    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Governance Data"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
                                                                  [[DashSync sharedSyncController] wipeGovernanceDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
                                                              }]];

    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Spork Data"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
                                                                  [[DashSync sharedSyncController] wipeSporkDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
                                                              }]];

    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Wallet Data"
                                                                style:UIAlertActionStyleDestructive
                                                              handler:^(UIAlertAction *_Nonnull action) {
        [[DashSync sharedSyncController] wipeWalletDataForChain:self.chainManager.chain forceReauthentication:YES inContext:[NSManagedObjectContext chainContext]];
    }]];

    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Everything"
                                                                style:UIAlertActionStyleDestructive
                                                              handler:^(UIAlertAction *_Nonnull action) {
        [[DashSync sharedSyncController] wipePeerDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
        [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
        [[DashSync sharedSyncController] wipeSporkDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
        [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
        [[DashSync sharedSyncController] wipeGovernanceDataForChain:self.chainManager.chain inContext:[NSManagedObjectContext chainContext]];
        [[DashSync sharedSyncController] wipeWalletDataForChain:self.chainManager.chain forceReauthentication:YES inContext:[NSManagedObjectContext chainContext]]; //this takes care of blockchain info as well;
    }]];

    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                                style:UIAlertActionStyleCancel
                                                              handler:^(UIAlertAction *_Nonnull action){

                                                              }]];
    [self presentViewController:wipeDataAlertController animated:TRUE completion:nil];
}

- (IBAction)sendToPasteboard:(id)sender {
    NSArray *addresses = [self.pasteboardExtractor extractAddresses];
    NSString *firstAddress = nil;
    for (NSString *string in addresses) {
        if (DIsValidDashAddress(DChar(string), self.chainManager.chain.chainType))
            firstAddress = string;
    }
    if ([self.pasteboardAddressLabel.text isEqual:firstAddress]) {
        [self payToAddressFromPasteboardAvailable:^(BOOL success){

        }];
    } else {
        self.pasteboardAddressLabel.text = firstAddress;
    }
}

- (void)payToAddressFromPasteboardAvailable:(void (^)(BOOL success))completion {
    DSAccount *account = self.chainManager.chain.firstAccountWithBalance;
    if (!account || account.balance < 1000) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Not enough balance"
                             message:@""
                      preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okButton = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"ok", nil)
                      style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction *action){

                    }];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    DSPaymentRequest *paymentRequest = [DSPaymentRequest requestWithString:self.pasteboardAddressLabel.text onChain:account.wallet.chain];
    paymentRequest.amount = 1000;

    if ([paymentRequest isValidAsNonDashpayPaymentRequest]) {
        __block BOOL displayedSentMessage = FALSE;

        [account.wallet.chain.chainManager.transactionManager confirmPaymentRequest:paymentRequest
            usingUserIdentity:nil
            fromAccount:account
            acceptInternalAddress:YES
            acceptReusingAddress:YES
            addressIsFromPasteboard:YES
            requiresSpendingAuthenticationPrompt:NO
            keepAuthenticatedIfErrorAfterAuthentication:NO
            requestingAdditionalInfo:^(DSRequestingAdditionalInfo additionalInfoRequestType) {
            }
            presentChallenge:^(NSString *_Nonnull challengeTitle, NSString *_Nonnull challengeMessage, NSString *_Nonnull actionTitle, void (^_Nonnull actionBlock)(void), void (^_Nonnull cancelBlock)(void)) {
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:challengeTitle
                                     message:challengeMessage
                              preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *ignoreButton = [UIAlertAction
                    actionWithTitle:actionTitle
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *action) {
                                actionBlock();
                            }];
                UIAlertAction *cancelButton = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"cancel", nil)
                              style:UIAlertActionStyleCancel
                            handler:^(UIAlertAction *action) {
                                cancelBlock();
                            }];

                [alert addAction:cancelButton]; //cancel should always be on the left
                [alert addAction:ignoreButton];
                [self presentViewController:alert animated:YES completion:nil];
            }
            transactionCreationCompletion:^BOOL(DSTransaction *tx, NSString *prompt, uint64_t amount, uint64_t proposedFee, NSArray<NSString *> *addresses, BOOL isSecure) {
                return TRUE; //just continue and let Dash Sync do it's thing
            }
            signedCompletion:^BOOL(DSTransaction *_Nonnull tx, NSError *_Nullable error, BOOL cancelled) {
                if (cancelled) {
                } else if (error) {
                    UIAlertController *alert = [UIAlertController
                        alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                         message:error.localizedDescription
                                  preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okButton = [UIAlertAction
                        actionWithTitle:NSLocalizedString(@"ok", nil)
                                  style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction *action){

                                }];
                    [alert addAction:okButton];
                    [self presentViewController:alert animated:YES completion:nil];
                }
                return TRUE;
            }
            publishedCompletion:^(DSTransaction *_Nonnull tx, NSError *_Nullable error, BOOL sent) {
                if (sent) {
                    [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"sent!", nil)
                                                                center:CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2)] popIn]
                                              popOutAfterDelay:2.0]];


                    displayedSentMessage = TRUE;
                }
            }
            errorNotificationBlock:^(NSError *_Nonnull error, NSString *_Nullable errorTitle, NSString *_Nullable errorMessage, BOOL shouldCancel) {
                if (errorTitle || errorMessage) {
                    UIAlertController *alert = [UIAlertController
                        alertControllerWithTitle:errorTitle
                                         message:errorMessage
                                  preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okButton = [UIAlertAction
                        actionWithTitle:NSLocalizedString(@"ok", nil)
                                  style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction *action){
                                }];
                    [alert addAction:okButton];
                    [self presentViewController:alert animated:YES completion:nil];
                }
            }];
    }
}

// MARK: - Blockchain events

- (void)syncFinished {
}

- (void)syncFailed {
}

- (void)updateReceivingAddress {
    if (self.chain.wallets.count) {
        DSWallet *firstWallet = self.chain.wallets[0];
        DSAccount *account = [firstWallet accountWithNumber:0];
        self.receivingAddressLabel.text = [account receiveAddress];
    } else {
        self.receivingAddressLabel.text = @"";
    }
}

- (void)updateBalance {
    self.transactionCountBalanceLabel.text = [NSString stringWithFormat:@"%lu / %@", [self.chain.allTransactions count], [[DSPriceManager sharedInstance] stringForDashAmount:self.chainManager.chain.balance]];
}

- (void)updateBlockHeight {
    self.lastBlockHeightLabel.text = [NSString stringWithFormat:@"%d", self.chainManager.syncState.lastSyncBlockHeight];
}

- (void)updateHeaderHeight {
    self.lastMasternodeBlockHeightLabel.text = [NSString stringWithFormat:@"%d", self.chainManager.syncState.lastTerminalBlockHeight];
}

- (void)updatePeerCount {
    uint64_t peerCount = self.chainManager.peerManager.peerCount;
    self.peerCountLabel.text = [NSString stringWithFormat:@"%llu", peerCount];
}

- (void)updateConnectedPeerCount {
    uint64_t connectedPeerCount = self.chainManager.peerManager.connectedPeerCount;
    self.connectedPeerCountLabel.text = [NSString stringWithFormat:@"%llu", connectedPeerCount];
}

- (void)updateSporks {
    self.sporksCountLabel.text = [NSString stringWithFormat:@"%lu", [[self.chainManager.sporkManager.sporkDictionary allKeys] count]];
}

- (void)updateKnownMasternodes {
    DMasternodeList *list = [self.chainManager.chain.masternodeManager currentMasternodeList];
    uintptr_t count = list ? list->masternodes->count : 0;
    self.masternodeCountLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)count];
    self.localMasternodesCountLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.chainManager.masternodeManager localMasternodesCount]];
    self.masternodeListUpdatedLabel.text = [NSString stringWithFormat:@"%u", (unsigned long)list ? list->known_height : 0];
}

- (void)updateMasternodeLists {
//    uint32_t earliestHeight = self.chainManager.masternodeManager.earliestMasternodeListBlockHeight;
    uint32_t lastHeight = self.chainManager.masternodeManager.lastMasternodeListBlockHeight;
    self.masternodeListsCountLabel.text = [NSString stringWithFormat:@"%lu", self.chainManager.masternodeManager.knownMasternodeListsCount];
//    self.earliestMasternodeListLabel.text = (earliestHeight != UINT32_MAX) ? [NSString stringWithFormat:@"%u", earliestHeight] : @"None";
    self.lastMasternodeListLabel.text = (lastHeight != UINT32_MAX) ? [NSString stringWithFormat:@"%u", lastHeight] : @"None";
}


- (void)updateQuorumsList {
    self.quorumCountLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.chainManager.masternodeManager activeQuorumsCount]];
}

- (void)updateWalletCount {
    self.walletCountLabel.text = [NSString stringWithFormat:@"%lu", [self.chainManager.chain.wallets count]];
}

- (void)updateStandaloneDerivationPathsCount {
    self.standaloneDerivationPathsCountLabel.text = [NSString stringWithFormat:@"%lu", [self.chainManager.chain.standaloneDerivationPaths count]];
}

- (void)updateSingleAddressesCount {
    self.standaloneAddressesCountLabel.text = [NSString stringWithFormat:@"%d", 0];
}

- (void)updateReceivedGovernanceVoteCount {
    self.receivedVotesCountLabel.text = [NSString stringWithFormat:@"%lu / %lu", (unsigned long)[self.chainManager.governanceSyncManager governanceVotesCount], self.chainManager.governanceSyncManager.totalGovernanceVotesCount];
}

- (void)updateIdentitiesCount {
    self.identitiesCountLabel.text = [NSString stringWithFormat:@"%u", self.chainManager.chain.localIdentitiesCount];
}

- (void)updateInvitationsCount {
    self.invitationsCountLabel.text = [NSString stringWithFormat:@"%u", self.chainManager.chain.localInvitationsCount];
}

- (void)updateReceivedGovernanceProposalCount {
    self.receivedProposalCountLabel.text = [NSString stringWithFormat:@"%lu / %lu / %u", (unsigned long)[self.chainManager.governanceSyncManager proposalObjectsCount], (unsigned long)[self.chainManager.governanceSyncManager governanceObjectsCount], self.chainManager.chain.totalGovernanceObjectsCount];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"WalletsListSegue"]) {
        DSWalletViewController *walletViewController = (DSWalletViewController *)segue.destinationViewController;
        walletViewController.chain = self.chainManager.chain;
    } else if ([segue.identifier isEqualToString:@"StandaloneDerivationPathsSegue"]) {
        DSStandaloneDerivationPathViewController *standaloneDerivationPathController = (DSStandaloneDerivationPathViewController *)segue.destinationViewController;
        standaloneDerivationPathController.chain = self.chainManager.chain;
    } else if ([segue.identifier isEqualToString:@"SporksListSegue"]) {
        DSSporksViewController *sporksViewController = (DSSporksViewController *)segue.destinationViewController;
        sporksViewController.chain = self.chainManager.chain;
        sporksViewController.sporksArray = [[[[self.chainManager.sporkManager sporkDictionary] allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:TRUE]]] mutableCopy];
    } else if ([segue.identifier isEqualToString:@"BlockchainExplorerSegue"]) {
        DSBlockchainExplorerViewController *blockchainExplorerViewController = (DSBlockchainExplorerViewController *)segue.destinationViewController;
        blockchainExplorerViewController.chain = self.chainManager.chain;
    } else if ([segue.identifier isEqualToString:@"HeaderBlockchainExplorerSegue"]) {
        DSBlockchainExplorerViewController *blockchainExplorerViewController = (DSBlockchainExplorerViewController *)segue.destinationViewController;
        blockchainExplorerViewController.chain = self.chainManager.chain;
    } else if ([segue.identifier isEqualToString:@"MasternodeListSegue"]) {
        DSMasternodeViewController *masternodeViewController = (DSMasternodeViewController *)segue.destinationViewController;
        masternodeViewController.chain = self.chainManager.chain;
    } else if ([segue.identifier isEqualToString:@"MasternodeListsSegue"]) {
        DSMasternodeListsViewController *masternodeListsViewController = (DSMasternodeListsViewController *)segue.destinationViewController;
        masternodeListsViewController.chain = self.chainManager.chain;
    } else if ([segue.identifier isEqualToString:@"QuorumListSegue"]) {
        DSQuorumListViewController *quorumListViewController = (DSQuorumListViewController *)segue.destinationViewController;
        quorumListViewController.chain = self.chainManager.chain;
    } else if ([segue.identifier isEqualToString:@"GovernanceObjectsSegue"]) {
        DSGovernanceObjectListViewController *governanceObjectViewController = (DSGovernanceObjectListViewController *)segue.destinationViewController;
        governanceObjectViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"TransactionsViewSegue"]) {
        DSTransactionsViewController *transactionsViewController = (DSTransactionsViewController *)segue.destinationViewController;
        transactionsViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentitiesSegue"]) {
        DSIdentitiesViewController *identitiesViewController = (DSIdentitiesViewController *)segue.destinationViewController;
        identitiesViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"BlockchainInvitationsSegue"]) {
        DSInvitationsViewController *invitationsViewController = (DSInvitationsViewController *)segue.destinationViewController;
        invitationsViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"ShowPeersSegue"]) {
        DSPeersViewController *peersViewController = (DSPeersViewController *)segue.destinationViewController;
        peersViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"Layer2Segue"]) {
        DSLayer2ViewController *layer2ViewController = (DSLayer2ViewController *)segue.destinationViewController;
        layer2ViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"ActionsSegue"]) {
        DSActionsViewController *actionsViewController = (DSActionsViewController *)segue.destinationViewController;
        actionsViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"SearchBlockchainIdentitiesSegue"]) {
        DSSearchIdentitiesViewController *searchViewController = (DSSearchIdentitiesViewController *)segue.destinationViewController;
        searchViewController.chainManager = self.chainManager;
    }
}


@end
