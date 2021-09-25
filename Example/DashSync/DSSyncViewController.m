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
#import "DSBlockchainIdentitiesViewController.h"
#import "DSBloomFilter.h"
#import "DSGovernanceObjectListViewController.h"
#import "DSInvitationsViewController.h"
#import "DSLayer2ViewController.h"
#import "DSMasternodeListsViewController.h"
#import "DSMasternodeViewController.h"
#import "DSPasteboardAddressExtractor.h"
#import "DSPeersViewController.h"
#import "DSQuorumListViewController.h"
#import "DSSearchBlockchainIdentitiesViewController.h"
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
@property (strong, nonatomic) IBOutlet UILabel *blockchainIdentitiesCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *blockchainInvitationsCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *receivingAddressLabel;
@property (strong, nonatomic) IBOutlet UILabel *pasteboardAddressLabel;
@property (strong, nonatomic) IBOutlet UILabel *masternodeListsCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *earliestMasternodeListLabel;
@property (strong, nonatomic) IBOutlet UILabel *lastMasternodeListLabel;
@property (strong, nonatomic) id filterChangedObserver, syncFinishedObserver, syncFailedObserver, balanceObserver, blocksObserver, blocksResetObserver, headersResetObserver, sporkObserver, masternodeObserver, masternodeCountObserver, chainWalletObserver, chainStandaloneDerivationPathObserver, chainSingleAddressObserver, governanceObjectCountObserver, governanceObjectReceivedCountObserver, governanceVoteCountObserver, governanceVoteReceivedCountObserver, connectedPeerConnectionObserver, peerConnectionObserver, blockchainIdentitiesObserver, blockchainInvitationsObserver, quorumObserver;
@property (strong, nonatomic) DSPasteboardAddressExtractor *pasteboardExtractor;

- (IBAction)startSync:(id)sender;
- (IBAction)stopSync:(id)sender;
- (IBAction)wipeData:(id)sender;
- (IBAction)sendToPasteboard:(id)sender;

@end

@implementation DSSyncViewController

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
    [self updateBlockchainIdentitiesCount];
    [self updateBlockchainInvitationsCount];
    [self updatePeerCount];
    [self updateConnectedPeerCount];
    [self updateFilterInfo];

    self.filterChangedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSTransactionManagerFilterDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                              [self updateFilterInfo];
                                                          }
                                                      }];


    self.syncFinishedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainManagerSyncFinishedNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          DSLogPrivate(@"background fetch sync finished");
                                                          [self syncFinished];
                                                      }];

    self.syncFailedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainManagerSyncFailedNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                              DSLogPrivate(@"background fetch sync failed");
                                                              [self syncFailed];
                                                          }
                                                      }];


    self.connectedPeerConnectionObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSPeerManagerConnectedPeersDidChangeNotification
                                                                                             object:nil
                                                                                              queue:nil
                                                                                         usingBlock:^(NSNotification *note) {
                                                                                             if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                                 [self updateConnectedPeerCount];
                                                                                             }
                                                                                         }];

    self.peerConnectionObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSPeerManagerPeersDidChangeNotification
                                                                                    object:nil
                                                                                     queue:nil
                                                                                usingBlock:^(NSNotification *note) {
                                                                                    if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                        [self updatePeerCount];
                                                                                    }
                                                                                }];


    self.blocksObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainNewChainTipBlockNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                              DSLogPrivate(@"update blockheight");
                                                              [self updateBlockHeight];
                                                              [self updateHeaderHeight];
                                                          }
                                                      }];

    self.blocksResetObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainChainSyncBlocksDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          [self updateBlockHeight];
                                                          [self updateBalance];
                                                      }];

    self.headersResetObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainTerminalBlocksDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          [self updateHeaderHeight];
                                                      }];

    self.balanceObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSWalletBalanceDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if (!note.userInfo[DSChainManagerNotificationChainKey] || [note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                              //NSLog(@"update balance");
                                                              [self updateBalance];
                                                          }
                                                      }];
    self.sporkObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSSporkListDidUpdateNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                              DSLogPrivate(@"update spork count");
                                                              [self updateSporks];
                                                          }
                                                      }];
    self.masternodeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSMasternodeListDidChangeNotification
                                                                                object:nil
                                                                                 queue:nil
                                                                            usingBlock:^(NSNotification *note) {
                                                                                if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                    DSLogPrivate(@"update masternode list");
                                                                                    [self updateKnownMasternodes];
                                                                                    [self updateMasternodeLists];
                                                                                }
                                                                            }];


    self.quorumObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSQuorumListDidChangeNotification
                                                                            object:nil
                                                                             queue:nil
                                                                        usingBlock:^(NSNotification *note) {
                                                                            if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                DSLogPrivate(@"update quorums");
                                                                                [self updateQuorumsList];
                                                                            }
                                                                        }];
    self.governanceObjectCountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSGovernanceObjectCountUpdateNotification
                                                                                           object:nil
                                                                                            queue:nil
                                                                                       usingBlock:^(NSNotification *note) {
                                                                                           if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                               NSLog(@"update governance object count");
                                                                                               [self updateReceivedGovernanceProposalCount];
                                                                                           }
                                                                                       }];
    self.governanceObjectReceivedCountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSGovernanceObjectListDidChangeNotification
                                                                                                   object:nil
                                                                                                    queue:nil
                                                                                               usingBlock:^(NSNotification *note) {
                                                                                                   if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                                       DSLogPrivate(@"update governance received object count");
                                                                                                       [self updateReceivedGovernanceProposalCount];
                                                                                                   }
                                                                                               }];

    self.governanceVoteCountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSGovernanceVoteCountUpdateNotification
                                                                                         object:nil
                                                                                          queue:nil
                                                                                     usingBlock:^(NSNotification *note) {
                                                                                         if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                             DSLogPrivate(@"update governance vote count");
                                                                                             [self updateReceivedGovernanceVoteCount];
                                                                                         }
                                                                                     }];
    self.governanceVoteReceivedCountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSGovernanceVotesDidChangeNotification
                                                                                                 object:nil
                                                                                                  queue:nil
                                                                                             usingBlock:^(NSNotification *note) {
                                                                                                 if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                                     DSLogPrivate(@"update governance received vote count");
                                                                                                     [self updateReceivedGovernanceVoteCount];
                                                                                                 }
                                                                                             }];
    self.chainWalletObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainWalletsDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                              [self updateWalletCount];
                                                          }
                                                      }];

    self.blockchainIdentitiesObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSBlockchainIdentityDidUpdateNotification
                                                                                          object:nil
                                                                                           queue:nil
                                                                                      usingBlock:^(NSNotification *note) {
                                                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                              [self updateBlockchainIdentitiesCount];
                                                                                          }
                                                                                      }];

    self.blockchainInvitationsObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSBlockchainInvitationDidUpdateNotification
                                                                                           object:nil
                                                                                            queue:nil
                                                                                       usingBlock:^(NSNotification *note) {
                                                                                           if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                               [self updateBlockchainInvitationsCount];
                                                                                           }
                                                                                       }];
    self.chainStandaloneDerivationPathObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainStandaloneDerivationPathsDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                              [self updateStandaloneDerivationPathsCount];
                                                          }
                                                      }];
    //    self.chainSingleAddressObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil
    //                                                                                         queue:nil usingBlock:^(NSNotification *note) {
    //                                                                                             if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
    //                                                                                             [self updateStandaloneDerivationPathsCount];
    //                                                                                             }
    //                                                                                         }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (DSChain *)chain {
    return self.chainManager.chain;
}

- (void)showSyncing {
    double progress = self.chainManager.combinedSyncProgress;

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
        if ([self.chain timestampForBlockHeight:self.chain.lastSyncBlockHeight] +
                WEEK_TIME_INTERVAL <
            [NSDate timeIntervalSince1970]) {
            if (self.chainManager.chain.earliestWalletCreationTime + DAY_TIME_INTERVAL < start) {
                self.explanationLabel.text = NSLocalizedString(@"Syncing", nil);
            }
        } else
            [self performSelector:@selector(showSyncing) withObject:nil afterDelay:5.0];
    }

    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    self.progressView.hidden = self.pulseView.hidden = NO;
    [UIView animateWithDuration:0.2
                     animations:^{
                         self.progressView.alpha = 1.0;
                     }];
    [self updateProgressView];
}

- (void)stopActivityWithSuccess:(BOOL)success {
    double progressView = self.chainManager.combinedSyncProgress;

    self.start = self.timeout = 0.0;
    if (progressView > DBL_EPSILON && progressView + DBL_EPSILON < 1.0) return; // not done syncing
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    if (self.progressView.alpha < 0.5) return;

    if (success) {
        [self.progressView setProgress:1.0 animated:YES];
        [self.pulseView setProgress:1.0 animated:YES];

        [UIView animateWithDuration:0.2
            animations:^{
                self.progressView.alpha = self.pulseView.alpha = 0.0;
            }
            completion:^(BOOL finished) {
                self.progressView.hidden = self.pulseView.hidden = YES;
                self.progressView.progress = self.pulseView.progress = 0.0;
            }];
    } else {
        self.progressView.hidden = self.pulseView.hidden = YES;
        self.progressView.progress = self.pulseView.progress = 0.0;
    }
}

- (void)setProgressViewTo:(NSNumber *)n {
    self.progressView.progress = n.floatValue;
}

- (void)updateProgressView {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateProgressView) object:nil];

    static int counter = 0;
    NSTimeInterval elapsed = [NSDate timeIntervalSince1970] - self.start;
    double progress = self.chainManager.combinedSyncProgress;
    uint64_t dbFileSize = [DashSync sharedSyncController].dbSize;
    uint32_t lastBlockHeight = self.chain.lastSyncBlockHeight;
    uint32_t lastHeaderHeight = self.chain.lastTerminalBlockHeight;
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
    self.lastMasternodeBlockHeightLabel.text = [NSString stringWithFormat:@"%d", lastHeaderHeight];
    self.downloadPeerLabel.text = self.chainManager.peerManager.downloadPeerName;
    self.chainTipLabel.text = self.chain.chainTip;
    if (progress + DBL_EPSILON >= 1.0) {
        self.percentageLabel.text = @"100%";
        if (self.timeout < 1.0) [self stopActivityWithSuccess:YES];
    } else
        [self performSelector:@selector(updateProgressView) withObject:nil afterDelay:0.2];
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
        if ([string isValidDashAddressOnChain:self.chainManager.chain]) {
            firstAddress = string;
        }
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
            usingUserBlockchainIdentity:nil
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
    self.lastBlockHeightLabel.text = [NSString stringWithFormat:@"%d", self.chain.lastSyncBlockHeight];
}

- (void)updateHeaderHeight {
    self.lastMasternodeBlockHeightLabel.text = [NSString stringWithFormat:@"%d", self.chain.lastTerminalBlockHeight];
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
    self.masternodeCountLabel.text = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)[self.chainManager.masternodeManager.currentMasternodeList whiteMasternodeCount], (unsigned long)[self.chainManager.masternodeManager.currentMasternodeList masternodeCount]];
    self.localMasternodesCountLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.chainManager.masternodeManager localMasternodesCount]];
    self.masternodeListUpdatedLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.chainManager.masternodeManager.currentMasternodeList.height];
}

- (void)updateMasternodeLists {
    uint32_t earliestHeight = self.chainManager.masternodeManager.earliestMasternodeListBlockHeight;
    uint32_t lastHeight = self.chainManager.masternodeManager.lastMasternodeListBlockHeight;
    self.masternodeListsCountLabel.text = [NSString stringWithFormat:@"%lu", self.chainManager.masternodeManager.knownMasternodeListsCount];
    self.earliestMasternodeListLabel.text = (earliestHeight != UINT32_MAX) ? [NSString stringWithFormat:@"%u", earliestHeight] : @"None";
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

- (void)updateBlockchainIdentitiesCount {
    self.blockchainIdentitiesCountLabel.text = [NSString stringWithFormat:@"%u", self.chainManager.chain.localBlockchainIdentitiesCount];
}

- (void)updateBlockchainInvitationsCount {
    self.blockchainInvitationsCountLabel.text = [NSString stringWithFormat:@"%u", self.chainManager.chain.localBlockchainInvitationsCount];
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
        DSBlockchainIdentitiesViewController *blockchainIdentitiesViewController = (DSBlockchainIdentitiesViewController *)segue.destinationViewController;
        blockchainIdentitiesViewController.chainManager = self.chainManager;
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
        DSSearchBlockchainIdentitiesViewController *searchViewController = (DSSearchBlockchainIdentitiesViewController *)segue.destinationViewController;
        searchViewController.chainManager = self.chainManager;
    }
}


@end
