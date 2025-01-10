//
//  DSContactsViewController.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 08/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSContactsViewController.h"
#import "DSContactReceivedTransactionsTableViewController.h"
#import "DSContactRelationshipActionsViewController.h"
#import "DSContactRelationshipInfoViewController.h"
#import "DSContactSendDashViewController.h"
#import "DSContactSentTransactionsTableViewController.h"
#import "DSContactTableViewCell.h"

static NSString *const CellId = @"CellId";

@interface DSContactsViewController ()

@end

@implementation DSContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)setIdentity:(DSIdentity *)identity {
    _identity = identity;

    self.title = identity.currentDashpayUsername;
}

- (IBAction)refreshAction:(id)sender {
    [self.refreshControl beginRefreshing];
    __weak typeof(self) weakSelf = self;
    [self.identity fetchContactRequests:^(BOOL success, NSArray<NSError *> *errors) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (!success && errors.count) {
            [self showAlertTitle:[errors[0] localizedDescription] result:NO];
        }
        [strongSelf.refreshControl endRefreshing];
    }];
}

- (NSString *)entityName {
    return @"DSDashpayUserEntity";
}

- (NSPredicate *)predicate {
    return [NSPredicate predicateWithFormat:@"ANY friends == %@", [self.identity matchingDashpayUserInContext:self.context]];
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors {
    NSSortDescriptor *usernameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"associatedBlockchainIdentity.dashpayUsername.stringValue" ascending:YES];
    return @[usernameSortDescriptor];
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSContactTableViewCell *cell = (DSContactTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"ContactCellIdentifier" forIndexPath:indexPath];

    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(DSContactTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    DSDashpayUserEntity *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = friend.username;
}

#pragma mark - Private

- (void)showAlertTitle:(NSString *)title result:(BOOL)result {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:result ? @"✅ success" : @"❌ failure" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath *selectedIndex = self.tableView.indexPathForSelectedRow;
    DSDashpayUserEntity *dashpayFriend = [self.fetchedResultsController objectAtIndexPath:selectedIndex];
    DSDashpayUserEntity *me = [self.identity matchingDashpayUserInContext:self.context];
    DSFriendRequestEntity *meToFriend = [[me.outgoingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"destinationContact == %@", dashpayFriend]] anyObject];
    DSFriendRequestEntity *friendToMe = [[me.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@", dashpayFriend]] anyObject];
    NSAssert(meToFriend, @"We are friends after all - us to them");
    NSAssert(friendToMe, @"We are friends after all - them to us");
    if ([segue.identifier isEqualToString:@"ContactTransactionsSegue"]) {
        UITabBarController *tabBarController = segue.destinationViewController;
        tabBarController.title = dashpayFriend.username;
        for (UIViewController *controller in tabBarController.viewControllers) {
            if ([controller isKindOfClass:[DSContactReceivedTransactionsTableViewController class]]) {
                DSContactReceivedTransactionsTableViewController *receivedTransactionsController = (DSContactReceivedTransactionsTableViewController *)controller;
                receivedTransactionsController.chainManager = self.chainManager;
                receivedTransactionsController.identity = self.identity;
                receivedTransactionsController.friendRequest = meToFriend;
            } else if ([controller isKindOfClass:[DSContactSentTransactionsTableViewController class]]) {
                DSContactSentTransactionsTableViewController *sentTransactionsController = (DSContactSentTransactionsTableViewController *)controller;
                sentTransactionsController.chainManager = self.chainManager;
                sentTransactionsController.identity = self.identity;
                sentTransactionsController.friendRequest = friendToMe;
            } else if ([controller isKindOfClass:[DSContactSendDashViewController class]]) {
                ((DSContactSendDashViewController *)controller).identity = self.identity;
                ((DSContactSendDashViewController *)controller).contact = dashpayFriend;
            } else if ([controller isKindOfClass:[DSContactRelationshipInfoViewController class]]) {
                ((DSContactRelationshipInfoViewController *)controller).identity = self.identity;
                ((DSContactRelationshipInfoViewController *)controller).incomingFriendRequest = friendToMe;
                ((DSContactRelationshipInfoViewController *)controller).outgoingFriendRequest = meToFriend;
            } else if ([controller isKindOfClass:[DSContactRelationshipActionsViewController class]]) {
                ((DSContactRelationshipInfoViewController *)controller).identity = self.identity;
                ((DSContactRelationshipInfoViewController *)controller).incomingFriendRequest = friendToMe;
                ((DSContactRelationshipInfoViewController *)controller).outgoingFriendRequest = meToFriend;
            }
        }
    }
}


@end
