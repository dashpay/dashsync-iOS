//
//  DSInvitationsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/26/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSInvitationsViewController.h"
#import "DSIdentityActionsViewController.h"
#import "DSCreateInvitationViewController.h"
#import "DSInvitationDetailViewController.h"
#import "DSInvitationTableViewCell.h"
#import "DSMerkleBlock.h"

@interface DSInvitationsViewController ()

@property (nonatomic, strong) NSArray<NSArray *> *orderedInvitations;
@property (strong, nonatomic) id invitationsObserver;

@end

@implementation DSInvitationsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self loadData];

    self.invitationsObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSIdentityDidUpdateNotification
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
    NSMutableArray *mOrderedInvitations = [NSMutableArray array];
    for (DSWallet *wallet in self.chainManager.chain.wallets) {
        if (![wallet.invitations count]) continue;
        NSArray<DSInvitation *> *allInvitations = [wallet.invitations allValues];
        NSArray<NSSortDescriptor *> *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"identity.registrationAssetLockTransaction.blockHeight" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"identity.registrationAssetLockTransaction.timestamp" ascending:NO]];
        NSArray<DSInvitation *> *allInvitationsSorted = [allInvitations sortedArrayUsingDescriptors:sortDescriptors];
        [mOrderedInvitations addObject:allInvitationsSorted];
    }

    self.orderedInvitations = [mOrderedInvitations copy];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.invitationsObserver];
}

- (DSWallet *)walletAtIndex:(NSUInteger)index {
    NSUInteger currentIndex = 0;
    for (DSWallet *wallet in self.chainManager.chain.wallets) {
        if ([wallet.invitations count]) {
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
    return [self.orderedInvitations[section] count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.orderedInvitations count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSInvitationTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockchainInvitationCellIdentifier"];

    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(DSInvitationTableViewCell *)invitationCell atIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        DSInvitation *invitation = self.orderedInvitations[indexPath.section][indexPath.row];
        invitationCell.usernameLabel.text = invitation.identity.currentDashpayUsername ? invitation.identity.currentDashpayUsername : @"Not yet set";
        invitationCell.creditBalanceLabel.text = [NSString stringWithFormat:@"%llu", invitation.identity.creditBalance];
        if (invitation.identity.registrationAssetLockTransaction) {
            if (invitation.identity.registrationAssetLockTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
                invitationCell.confirmationsLabel.text = @"unconfirmed";
            } else {
                invitationCell.confirmationsLabel.text = [NSString stringWithFormat:@"%u", (self.chainManager.chain.lastSyncBlockHeight - invitation.identity.registrationAssetLockTransaction.blockHeight + 1)];
            }
        }
        invitationCell.registrationL2StatusLabel.text = invitation.identity.localizedRegistrationStatusString;
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        DSIdentity *identity = self.orderedInvitations[indexPath.section][indexPath.row];
        [identity unregisterLocally];
        }],
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Edit" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        //[self performSegueWithIdentifier:@"CreateBlockchainIdentitySegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
        }]
    ]];
    config.performsFirstActionWithFullSwipe = false;
    return config;

    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"CreateBlockchainInvitationSegue"]) {
        DSCreateInvitationViewController *createInvitationViewController = (DSCreateInvitationViewController *)((UINavigationController *)segue.destinationViewController).topViewController;
        createInvitationViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"InvitationDetailSegue"]) {
        DSInvitationDetailViewController *invitationDetailViewController = segue.destinationViewController;
        invitationDetailViewController.chainManager = self.chainManager;
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        DSInvitation *invitation = self.orderedInvitations[indexPath.section][indexPath.row];
        invitationDetailViewController.invitation = invitation;
    }
}

@end
