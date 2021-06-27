//
//  DSBlockchainInvitationsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/26/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSInvitationsViewController.h"
#import "DSBlockchainIdentityActionsViewController.h"
#import "DSCreateInvitationViewController.h"
#import "DSInvitationDetailViewController.h"
#import "DSInvitationTableViewCell.h"
#import "DSMerkleBlock.h"
#import <DashSync/DSCreditFundingTransaction.h>

@interface DSInvitationsViewController ()

@property (nonatomic, strong) NSArray<NSArray *> *orderedBlockchainInvitations;
@property (strong, nonatomic) id blockchainInvitationsObserver;

@end

@implementation DSInvitationsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self loadData];

    self.blockchainInvitationsObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSBlockchainIdentityDidUpdateNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self.chainManager chain]]) {
                                                              [self loadData];
                                                              [self.tableView reloadData];
                                                          }
                                                      }];

    // Do any additional setup after loading the view.
}

- (void)loadData {
    NSMutableArray *mOrderedBlockchainInvitations = [NSMutableArray array];
    for (DSWallet *wallet in self.chainManager.chain.wallets) {
        if ([wallet.blockchainInvitations count]) {
            [mOrderedBlockchainInvitations addObject:[[wallet.blockchainInvitations allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"identity.registrationCreditFundingTransaction.blockHeight" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"identity.registrationCreditFundingTransaction.timestamp" ascending:NO]]]];
        }
    }

    self.orderedBlockchainInvitations = [mOrderedBlockchainInvitations copy];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.blockchainInvitationsObserver];
}

- (DSWallet *)walletAtIndex:(NSUInteger)index {
    NSUInteger currentIndex = 0;
    for (DSWallet *wallet in self.chainManager.chain.wallets) {
        if ([wallet.blockchainInvitations count]) {
            if (currentIndex == index) {
                return wallet;
            }
            currentIndex++;
        }
    }
    return nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.orderedBlockchainInvitations[section] count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.orderedBlockchainInvitations count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSInvitationTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockchainInvitationCellIdentifier"];

    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(DSInvitationTableViewCell *)blockchainInvitationCell atIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        DSBlockchainInvitation *blockchainInvitation = self.orderedBlockchainInvitations[indexPath.section][indexPath.row];
        blockchainInvitationCell.usernameLabel.text = blockchainInvitation.identity.currentDashpayUsername ? blockchainInvitation.identity.currentDashpayUsername : @"Not yet set";
        blockchainInvitationCell.creditBalanceLabel.text = [NSString stringWithFormat:@"%llu", blockchainInvitation.identity.creditBalance];
        if (blockchainInvitation.identity.registrationCreditFundingTransaction) {
            if (blockchainInvitation.identity.registrationCreditFundingTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
                blockchainInvitationCell.confirmationsLabel.text = @"unconfirmed";
            } else {
                blockchainInvitationCell.confirmationsLabel.text = [NSString stringWithFormat:@"%u", (self.chainManager.chain.lastSyncBlockHeight - blockchainInvitation.identity.registrationCreditFundingTransaction.blockHeight + 1)];
            }
        }
        blockchainInvitationCell.registrationL2StatusLabel.text = blockchainInvitation.identity.localizedRegistrationStatusString;
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                            title:@"Delete"
                                                                          handler:^(UITableViewRowAction *_Nonnull action, NSIndexPath *_Nonnull indexPath) {
                                                                              DSBlockchainIdentity *blockchainIdentity = self.orderedBlockchainInvitations[indexPath.section][indexPath.row];
                                                                              [blockchainIdentity unregisterLocally];
                                                                          }];
    UITableViewRowAction *editAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                          title:@"Edit"
                                                                        handler:^(UITableViewRowAction *_Nonnull action, NSIndexPath *_Nonnull indexPath){
                                                                            //[self performSegueWithIdentifier:@"CreateBlockchainIdentitySegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
                                                                        }];
    return @[deleteAction, editAction];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"CreateBlockchainInvitationSegue"]) {
        DSCreateInvitationViewController *createBlockchainInvitationViewController = (DSCreateInvitationViewController *)((UINavigationController *)segue.destinationViewController).topViewController;
        createBlockchainInvitationViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"InvitationDetailSegue"]) {
        DSInvitationDetailViewController *invitationDetailViewController = segue.destinationViewController;
        invitationDetailViewController.chainManager = self.chainManager;
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        DSBlockchainInvitation *blockchainInvitation = self.orderedBlockchainInvitations[indexPath.section][indexPath.row];
        invitationDetailViewController.invitation = blockchainInvitation;
    }
}

@end
