//
//  DSIdentitiesViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/26/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSIdentitiesViewController.h"
#import "DSIdentityActionsViewController.h"
#import "DSIdentityTableViewCell.h"
#import "DSCreateIdentityFromInvitationViewController.h"
#import "DSCreateIdentityViewController.h"
#import "DSMerkleBlock.h"

@interface DSIdentitiesViewController ()

@property (nonatomic, strong) NSArray<NSArray *> *orderedIdentities;
@property (strong, nonatomic) id identitiesObserver;

- (IBAction)createIdentity:(id)sender;

@end

@implementation DSIdentitiesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadData];
    self.identitiesObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSIdentityDidUpdateNotification
                                                                                object:nil
                                                                                 queue:nil
                                                                            usingBlock:^(NSNotification *note) {
        if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self.chainManager chain]]) {
            [self loadData];
            [self.tableView reloadData];
        }
    }];
}

- (void)loadData {
    NSMutableArray *mOrderedIdentities = [NSMutableArray array];
    for (DSWallet *wallet in self.chainManager.chain.wallets) {
        if ([wallet.identities count]) {
            [mOrderedIdentities addObject:[[wallet.identities allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"registrationAssetLockTransaction.blockHeight" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"registrationAssetLockTransaction.timestamp" ascending:NO]]]];
        }
    }
    self.orderedIdentities = [mOrderedIdentities copy];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.identitiesObserver];
}

- (DSWallet *)walletAtIndex:(NSUInteger)index {
    NSUInteger currentIndex = 0;
    for (DSWallet *wallet in self.chainManager.chain.wallets) {
        if ([wallet.identities count]) {
            if (currentIndex == index) return wallet;
            currentIndex++;
        }
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.orderedIdentities[section] count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.orderedIdentities count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSIdentityTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BlockchainIdentityCellIdentifier"];

    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(DSIdentityTableViewCell *)identityCell atIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        DSIdentity *identity = self.orderedIdentities[indexPath.section][indexPath.row];
        identityCell.usernameLabel.text = identity.currentDashpayUsername ? identity.currentDashpayUsername : @"Not yet set";
        identityCell.creditBalanceLabel.text = [NSString stringWithFormat:@"%llu", identity.creditBalance];
        if (identity.registrationAssetLockTransaction) {
            if (identity.registrationAssetLockTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
                identityCell.confirmationsLabel.text = @"unconfirmed";
            } else {
                identityCell.confirmationsLabel.text = [NSString stringWithFormat:@"%u", (self.chainManager.chain.lastSyncBlockHeight - identity.registrationAssetLockTransaction.blockHeight + 1)];
            }
        }
        identityCell.registrationL2StatusLabel.text = identity.localizedRegistrationStatusString;
        identityCell.publicKeysLabel.text = [NSString stringWithFormat:@"%u/%u", identity.activeKeyCount, identity.totalKeyCount];
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            DSIdentity *identity = self.orderedIdentities[indexPath.section][indexPath.row];
            [identity unregisterLocally];
        }],
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Edit" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            //[self performSegueWithIdentifier:@"CreateBlockchainIdentitySegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
        }]
    ]];
    config.performsFirstActionWithFullSwipe = false;
    return config;
}

- (IBAction)createIdentity:(id)sender {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Create Blockchain Identity"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    [controller addAction:[UIAlertAction actionWithTitle:@"From Wallet"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
        [self performSegueWithIdentifier:@"CreateBlockchainIdentitySegue" sender:self];
    }]];
    [controller addAction:[UIAlertAction actionWithTitle:@"From Invitation"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
        [self performSegueWithIdentifier:@"CreateBlockchainIdentityFromInvitationSegue" sender:self];
    }]];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"CreateBlockchainIdentitySegue"]) {
        DSCreateIdentityViewController *controller = (DSCreateIdentityViewController *)((UINavigationController *)segue.destinationViewController).topViewController;
        controller.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"CreateBlockchainIdentityFromInvitationSegue"]) {
        DSCreateIdentityFromInvitationViewController *controller = (DSCreateIdentityFromInvitationViewController *)((UINavigationController *)segue.destinationViewController).topViewController;
        controller.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityActionsSegue"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        DSIdentityActionsViewController *controller = segue.destinationViewController;
        controller.chainManager = self.chainManager;
        controller.identity = self.orderedIdentities[indexPath.section][indexPath.row];
    }
}

@end
