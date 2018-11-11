//
//  DSExampleViewController.m
//  DashSync
//
//  Created by Andrew Podkovyrin on 03/19/2018.
//  Copyright (c) 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>

#import "DSSyncViewController.h"
#import "DSWalletViewController.h"
#import "DSSporksViewController.h"
#import "DSBlockchainExplorerViewController.h"
#import "DSMasternodeViewController.h"
#import "DSStandaloneDerivationPathController.h"
#import "DSGovernanceObjectListViewController.h"
#import "DSTransactionsViewController.h"
#import "DSBlockchainUsersViewController.h"
#import "DSPeersViewController.h"
#import "DSLayer2ViewController.h"

@interface DSSyncViewController ()

@property (strong, nonatomic) IBOutlet UILabel *explanationLabel;
@property (strong, nonatomic) IBOutlet UILabel *percentageLabel;
@property (strong, nonatomic) IBOutlet UILabel *dbSizeLabel;
@property (strong, nonatomic) IBOutlet UILabel *lastBlockHeightLabel;
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
@property (strong, nonatomic) IBOutlet UILabel *masternodeBroadcastsCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *verifiedMasternodeCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *receivedProposalCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *receivedVotesCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *blockchainUsersCountLabel;
@property (strong, nonatomic) id syncFinishedObserver,syncFailedObserver,balanceObserver,blocksObserver,blocksResetObserver,sporkObserver,masternodeObserver,masternodeCountObserver, chainWalletObserver,chainStandaloneDerivationPathObserver,chainSingleAddressObserver,governanceObjectCountObserver,governanceObjectReceivedCountObserver,governanceVoteCountObserver,governanceVoteReceivedCountObserver,connectedPeerConnectionObserver,peerConnectionObserver,blockchainUsersObserver;

- (IBAction)startSync:(id)sender;
- (IBAction)stopSync:(id)sender;
- (IBAction)wipeData:(id)sender;

@end

@implementation DSSyncViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateBalance];
    [self updateSporks];
    [self updateBlockHeight];
    [self updateMasternodeCount];
    [self updateMasternodeList];
    [self updateWalletCount];
    [self updateStandaloneDerivationPathsCount];
    [self updateSingleAddressesCount];
    [self updateReceivedGovernanceProposalCount];
    [self updateReceivedGovernanceVoteCount];
    [self updateBlockchainUsersCount];
    [self updatePeerCount];
    [self updateConnectedPeerCount];
    
    self.syncFinishedObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerSyncFinishedNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           NSLog(@"background fetch sync finished");
                                                           [self syncFinished];
                                                       }];
    
    self.syncFailedObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerSyncFailedNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                               NSLog(@"background fetch sync failed");
                                                               [self syncFailed];
                                                           }
                                                       }];
    
    
    self.connectedPeerConnectionObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerConnectedPeersDidChangeNotification object:nil
                                                                                     queue:nil usingBlock:^(NSNotification *note) {
                                                                                                                                                    if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                         [self updateConnectedPeerCount];
                                                                                                                                                    }
                                                                                     }];
    
    self.peerConnectionObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerPeersDidChangeNotification object:nil
                                                                                        queue:nil usingBlock:^(NSNotification *note) {
                                                                                                                                                       if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                            [self updatePeerCount];
                                                                                                                                                       }
                                                                                        }];
    
    
    self.blocksObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerNewBlockNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           
                                                           if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                               NSLog(@"update blockheight");
                                                               [self updateBlockHeight];
                                                           }
                                                       }];
    
    self.blocksResetObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainBlocksDidChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           [self updateBlockHeight];
                                                           [self updateBalance];
                                                       }];
    
    self.balanceObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSWalletBalanceDidChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           if (!note.userInfo[DSChainPeerManagerNotificationChainKey] ||[note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                               //NSLog(@"update balance");
                                                               [self updateBalance];
                                                           }
                                                       }];
    self.sporkObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSSporkListDidUpdateNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                               NSLog(@"update spork count");
                                                               [self updateSporks];
                                                           }
                                                       }];
    self.masternodeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSMasternodeListDidChangeNotification object:nil
                                                                                 queue:nil usingBlock:^(NSNotification *note) {
                                                                                     if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                         NSLog(@"update masternode broadcast count");
                                                                                         [self updateMasternodeList];
                                                                                     }
                                                                                 }];
    self.masternodeCountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSMasternodeListCountUpdateNotification object:nil
                                                                                      queue:nil usingBlock:^(NSNotification *note) {
                                                                                          if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                              NSLog(@"update masternode count");
                                                                                              [self updateMasternodeCount];
                                                                                          }
                                                                                      }];
    self.governanceObjectCountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSGovernanceObjectCountUpdateNotification object:nil
                                                                                            queue:nil usingBlock:^(NSNotification *note) {
                                                                                                if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                                    NSLog(@"update governance object count");
                                                                                                    [self updateReceivedGovernanceProposalCount];
                                                                                                }
                                                                                            }];
    self.governanceObjectReceivedCountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSGovernanceObjectListDidChangeNotification object:nil
                                                                                                    queue:nil usingBlock:^(NSNotification *note) {
                                                                                                        if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                                            NSLog(@"update governance received object count");
                                                                                                            [self updateReceivedGovernanceProposalCount];
                                                                                                        }
                                                                                                    }];
    
    self.governanceVoteCountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSGovernanceVoteCountUpdateNotification object:nil
                                                                                          queue:nil usingBlock:^(NSNotification *note) {
                                                                                              if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                                  NSLog(@"update governance vote count");
                                                                                                  [self updateReceivedGovernanceVoteCount];
                                                                                              }
                                                                                          }];
    self.governanceVoteReceivedCountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSGovernanceVotesDidChangeNotification object:nil
                                                                                                  queue:nil usingBlock:^(NSNotification *note) {
                                                                                                      if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                                          NSLog(@"update governance received vote count");
                                                                                                          [self updateReceivedGovernanceVoteCount];
                                                                                                      }
                                                                                                  }];
    self.chainWalletObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainWalletsDidChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                               [self updateWalletCount];
                                                           }
                                                       }];
    
    self.blockchainUsersObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSChainBlockchainUsersDidChangeNotification object:nil
                                                                                          queue:nil usingBlock:^(NSNotification *note) {
                                                                                              if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                                                                  [self updateBlockchainUsersCount];
                                                                                              }
                                                                                          }];
    self.chainStandaloneDerivationPathObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
                                                               [self updateStandaloneDerivationPathsCount];
                                                           }
                                                       }];
    //    self.chainSingleAddressObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSChainStandaloneDerivationPathsDidChangeNotification object:nil
    //                                                                                         queue:nil usingBlock:^(NSNotification *note) {
    //                                                                                             if ([note.userInfo[DSChainPeerManagerNotificationChainKey] isEqual:[self chain]]) {
    //                                                                                             [self updateStandaloneDerivationPathsCount];
    //                                                                                             }
    //                                                                                         }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(DSChain*)chain {
    return self.chainPeerManager.chain;
}

- (void)showSyncing
{
    double progress = self.chainPeerManager.syncProgress;
    
    if (progress > DBL_EPSILON && progress + DBL_EPSILON < 1.0 && self.chainPeerManager.chain.earliestWalletCreationTime + DAY_TIME_INTERVAL < [NSDate timeIntervalSinceReferenceDate]) {
        self.explanationLabel.text = NSLocalizedString(@"Syncing:", nil);
    }
}

- (void)startActivityWithTimeout:(NSTimeInterval)timeout
{
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    if (timeout > 1 && start + timeout > self.start + self.timeout) {
        self.timeout = timeout;
        self.start = start;
    }
    
    if (timeout <= DBL_EPSILON) {
        if ([self.chain timestampForBlockHeight:self.chain.lastBlockHeight] +
            WEEK_TIME_INTERVAL < [NSDate timeIntervalSinceReferenceDate]) {
            if (self.chainPeerManager.chain.earliestWalletCreationTime + DAY_TIME_INTERVAL < start) {
                self.explanationLabel.text = NSLocalizedString(@"Syncing", nil);
            }
        }
        else [self performSelector:@selector(showSyncing) withObject:nil afterDelay:5.0];
    }
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    self.progressView.hidden = self.pulseView.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{ self.progressView.alpha = 1.0; }];
    [self updateProgressView];
}

- (void)stopActivityWithSuccess:(BOOL)success
{
    double progressView = self.chainPeerManager.syncProgress;
    
    self.start = self.timeout = 0.0;
    if (progressView > DBL_EPSILON && progressView + DBL_EPSILON < 1.0) return; // not done syncing
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    if (self.progressView.alpha < 0.5) return;
    
    if (success) {
        [self.progressView setProgress:1.0 animated:YES];
        [self.pulseView setProgress:1.0 animated:YES];
        
        [UIView animateWithDuration:0.2 animations:^{
            self.progressView.alpha = self.pulseView.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.progressView.hidden = self.pulseView.hidden = YES;
            self.progressView.progress = self.pulseView.progress = 0.0;
        }];
    }
    else {
        self.progressView.hidden = self.pulseView.hidden = YES;
        self.progressView.progress = self.pulseView.progress = 0.0;
    }
}

- (void)setProgressViewTo:(NSNumber *)n
{
    self.progressView.progress = n.floatValue;
}

- (void)updateProgressView
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateProgressView) object:nil];
    
    static int counter = 0;
    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - self.start;
    double progress = self.chainPeerManager.syncProgress;
    uint64_t dbFileSize = [DashSync sharedSyncController].dbSize;
    uint32_t lastBlockHeight = self.chain.lastBlockHeight;
    if (self.timeout > 1.0 && 0.1 + 0.9*elapsed/self.timeout < progress) progress = 0.1 + 0.9*elapsed/self.timeout;
    
    if ((counter % 13) == 0) {
        self.pulseView.alpha = 1.0;
        [self.pulseView setProgress:progress animated:progress > self.pulseView.progress];
        [self.progressView setProgress:progress animated:progress > self.progressView.progress];
        
        if (progress > self.progressView.progress) {
            [self performSelector:@selector(setProgressViewTo:) withObject:@(progress) afterDelay:1.0];
        }
        else self.progressView.progress = progress;
        
        [UIView animateWithDuration:1.59 delay:1.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.pulseView.alpha = 0.0;
        } completion:nil];
        
        [self.pulseView performSelector:@selector(setProgress:) withObject:nil afterDelay:2.59];
    }
    else if ((counter % 13) >= 5) {
        [self.progressView setProgress:progress animated:progress > self.progressView.progress];
        [self.pulseView setProgress:progress animated:progress > self.pulseView.progress];
    }
    
    counter++;
    
    self.explanationLabel.text = NSLocalizedString(@"Syncing", nil);
    self.percentageLabel.text = [NSString stringWithFormat:@"%0.1f%%",(progress > 0.1 ? progress - 0.1 : 0.0)*111.0];
    self.dbSizeLabel.text = [NSString stringWithFormat:@"%0.1llu KB",dbFileSize/1000];
    self.lastBlockHeightLabel.text = [NSString stringWithFormat:@"%d",lastBlockHeight];
    self.downloadPeerLabel.text = self.chainPeerManager.downloadPeerName;
    self.chainTipLabel.text = self.chain.chainTip;
    if (progress + DBL_EPSILON >= 1.0) {
        self.percentageLabel.text = @"100%";
        if (self.timeout < 1.0) [self stopActivityWithSuccess:YES];
    }
    else [self performSelector:@selector(updateProgressView) withObject:nil afterDelay:0.2];
}

- (IBAction)startSync:(id)sender {
    [[DashSync sharedSyncController] startSyncForChain:self.chainPeerManager.chain];
    [self startActivityWithTimeout:5.0];
}

- (IBAction)stopSync:(id)sender {
    [[DashSync sharedSyncController] stopSyncForChain:self.chainPeerManager.chain];
    [self startActivityWithTimeout:5.0];
}

- (IBAction)wipeData:(id)sender {
    UIAlertController * wipeDataAlertController = [UIAlertController alertControllerWithTitle:@"What do you wish to Wipe?" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Peer Data" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[DashSync sharedSyncController] wipePeerDataForChain:self.chainPeerManager.chain];
    }]];
    
    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Chain Data" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chainPeerManager.chain];
    }]];
    
    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Masternode Data" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chainPeerManager.chain];
    }]];
    
    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Governance Data" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[DashSync sharedSyncController] wipeGovernanceDataForChain:self.chainPeerManager.chain];
    }]];
    
    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Spork Data" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[DashSync sharedSyncController] wipeSporkDataForChain:self.chainPeerManager.chain];
    }]];
    
    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Wallet Data" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[DashSync sharedSyncController] wipeWalletDataForChain:self.chainPeerManager.chain forceReauthentication:YES];
    }]];
    
    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Everything" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[DashSync sharedSyncController] wipePeerDataForChain:self.chainPeerManager.chain];
        [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chainPeerManager.chain];
        [[DashSync sharedSyncController] wipeSporkDataForChain:self.chainPeerManager.chain];
        [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chainPeerManager.chain];
        [[DashSync sharedSyncController] wipeGovernanceDataForChain:self.chainPeerManager.chain];
        [[DashSync sharedSyncController] wipeWalletDataForChain:self.chainPeerManager.chain forceReauthentication:YES]; //this takes care of blockchain info as well;
    }]];
    
    [wipeDataAlertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [self presentViewController:wipeDataAlertController animated:TRUE completion:nil];
}

// MARK: - Blockchain events

-(void)syncFinished {
    
}

-(void)syncFailed {
    
}

-(void)updateBalance {
    self.transactionCountBalanceLabel.text = [NSString stringWithFormat:@"%lu / %@",[self.chain.allTransactions count],[[DSPriceManager sharedInstance] stringForDashAmount:self.chainPeerManager.chain.balance]];
}

-(void)updateBlockHeight {
    self.lastBlockHeightLabel.text = [NSString stringWithFormat:@"%d",self.chain.lastBlockHeight];
}

-(void)updatePeerCount {
    uint64_t peerCount = self.chainPeerManager.peerCount;
    self.peerCountLabel.text = [NSString stringWithFormat:@"%llu",peerCount];
}

-(void)updateConnectedPeerCount {
    uint64_t connectedPeerCount = self.chainPeerManager.connectedPeerCount;
    self.connectedPeerCountLabel.text = [NSString stringWithFormat:@"%llu",connectedPeerCount];
}

-(void)updateSporks {
    self.sporksCountLabel.text = [NSString stringWithFormat:@"%lu",[[self.chainPeerManager.sporkManager.sporkDictionary allKeys] count]];
}

-(void)updateMasternodeCount {
    self.masternodeCountLabel.text = [NSString stringWithFormat:@"%u",self.chainPeerManager.chain.totalMasternodeCount];
}

-(void)updateMasternodeList {
        self.masternodeCountLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)[self.chainPeerManager.masternodeManager simplifiedMasternodeEntryCount]];
        self.masternodeBroadcastsCountLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)[self.chainPeerManager.masternodeManager simplifiedMasternodeEntryCount]];
        self.verifiedMasternodeCountLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)[self.chainPeerManager.masternodeManager simplifiedMasternodeEntryCount]];
}

-(void)updateWalletCount {
    self.walletCountLabel.text = [NSString stringWithFormat:@"%lu",[self.chainPeerManager.chain.wallets count]];
}

-(void)updateStandaloneDerivationPathsCount {
    self.standaloneDerivationPathsCountLabel.text = [NSString stringWithFormat:@"%lu",[self.chainPeerManager.chain.standaloneDerivationPaths count]];
}

-(void)updateSingleAddressesCount {
    self.standaloneAddressesCountLabel.text = [NSString stringWithFormat:@"%d",0];
}

-(void)updateReceivedGovernanceVoteCount {
    self.receivedVotesCountLabel.text = [NSString stringWithFormat:@"%lu / %lu",(unsigned long)[self.chainPeerManager.governanceSyncManager governanceVotesCount],self.chainPeerManager.governanceSyncManager.totalGovernanceVotesCount];
}

-(void)updateBlockchainUsersCount {
    self.blockchainUsersCountLabel.text = [NSString stringWithFormat:@"%u",self.chainPeerManager.chain.blockchainUsersCount];
}

-(void)updateReceivedGovernanceProposalCount {
    self.receivedProposalCountLabel.text = [NSString stringWithFormat:@"%lu / %lu / %u",(unsigned long)[self.chainPeerManager.governanceSyncManager proposalObjectsCount],(unsigned long)[self.chainPeerManager.governanceSyncManager governanceObjectsCount],self.chainPeerManager.chain.totalGovernanceObjectsCount];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"WalletsListSegue"]) {
        DSWalletViewController * walletViewController = (DSWalletViewController*)segue.destinationViewController;
        walletViewController.chain = self.chainPeerManager.chain;
    } else if ([segue.identifier isEqualToString:@"StandaloneDerivationPathsSegue"]) {
        DSStandaloneDerivationPathController * standaloneDerivationPathController = (DSStandaloneDerivationPathController*)segue.destinationViewController;
        standaloneDerivationPathController.chain = self.chainPeerManager.chain;
    } else if ([segue.identifier isEqualToString:@"SporksListSegue"]) {
        DSSporksViewController * sporksViewController = (DSSporksViewController*)segue.destinationViewController;
        sporksViewController.chain = self.chainPeerManager.chain;
        sporksViewController.sporksArray = [[[[self.chainPeerManager.sporkManager sporkDictionary] allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:TRUE]]] mutableCopy];
    } else if ([segue.identifier isEqualToString:@"BlockchainExplorerSegue"]) {
        DSBlockchainExplorerViewController * blockchainExplorerViewController = (DSBlockchainExplorerViewController*)segue.destinationViewController;
        blockchainExplorerViewController.chain = self.chainPeerManager.chain;
    } else if ([segue.identifier isEqualToString:@"MasternodeListSegue"]) {
        DSMasternodeViewController * masternodeViewController = (DSMasternodeViewController*)segue.destinationViewController;
        masternodeViewController.chain = self.chainPeerManager.chain;
    } else if ([segue.identifier isEqualToString:@"GovernanceObjectsSegue"]) {
        DSGovernanceObjectListViewController * governanceObjectViewController = (DSGovernanceObjectListViewController*)segue.destinationViewController;
        governanceObjectViewController.chainPeerManager = self.chainPeerManager;
    } else if ([segue.identifier isEqualToString:@"TransactionsViewSegue"]) {
        DSTransactionsViewController * transactionsViewController = (DSTransactionsViewController*)segue.destinationViewController;
        transactionsViewController.chainPeerManager = self.chainPeerManager;
    } else if ([segue.identifier isEqualToString:@"BlockchainUsersSegue"]) {
        DSBlockchainUsersViewController * blockchainUsersViewController = (DSBlockchainUsersViewController*)segue.destinationViewController;
        blockchainUsersViewController.chainPeerManager = self.chainPeerManager;
    } else if ([segue.identifier isEqualToString:@"ShowPeersSegue"]) {
        DSPeersViewController * peersViewController = (DSPeersViewController*)segue.destinationViewController;
        peersViewController.chainPeerManager = self.chainPeerManager;
    } else if ([segue.identifier isEqualToString:@"Layer2Segue"]) {
        DSLayer2ViewController * layer2ViewController = (DSLayer2ViewController*)segue.destinationViewController;
        layer2ViewController.chainPeerManager = self.chainPeerManager;
    }
}


@end
