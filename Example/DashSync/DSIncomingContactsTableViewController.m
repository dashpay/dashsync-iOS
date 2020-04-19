//
//  DSIncomingContactsTableViewController.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 15/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSIncomingContactsTableViewController.h"
#import "DSContactTableViewCell.h"

static NSString * const CellId = @"CellId";

@interface DSIncomingContactsTableViewController ()

@end

@implementation DSIncomingContactsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Requests";
    
}

- (IBAction)refreshAction:(id)sender {
    [self.refreshControl beginRefreshing];
    __weak typeof(self) weakSelf = self;
    [self.blockchainIdentity fetchIncomingContactRequests:^(BOOL success, NSArray<NSError *> *errors) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        [strongSelf.refreshControl endRefreshing];
    }];
}

- (NSString *)entityName {
    return @"DSFriendRequestEntity";
}

-(NSPredicate*)predicate {
    //incoming request from marge to homer
    //own contact is homer
    //self is marge
    //validates to being a request from marge to homer
    return [NSPredicate predicateWithFormat:@"destinationContact == %@ && (SUBQUERY(destinationContact.outgoingRequests, $friendRequest, $friendRequest.destinationContact == SELF.sourceContact).@count == 0)",[self.blockchainIdentity matchingDashpayUserInContext:self.context]];
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors {
    NSSortDescriptor *usernameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"sourceContact.associatedBlockchainIdentity.dashpayUsername.stringValue"
                                                                           ascending:YES];
    return @[usernameSortDescriptor];
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSContactTableViewCell *cell = (DSContactTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"ContactCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSContactTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSFriendRequestEntity * friendRequest = [self.fetchedResultsController objectAtIndexPath:indexPath];
    DSBlockchainIdentityEntity * sourceBlockchainIdentity = friendRequest.sourceContact.associatedBlockchainIdentity;
    DSBlockchainIdentityUsernameEntity * username = [sourceBlockchainIdentity.usernames anyObject];
    cell.textLabel.text = username.stringValue;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    DSFriendRequestEntity * friendRequest = [self.fetchedResultsController objectAtIndexPath:indexPath];
    __weak typeof(self) weakSelf = self;
    [self.blockchainIdentity acceptFriendRequest:friendRequest completion:^(BOOL success, NSError * error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        [strongSelf showAlertTitle:@"Confirming contact request:" result:success];
    }];
}

#pragma mark - Private

- (void)showAlertTitle:(NSString *)title result:(BOOL)result {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:result ? @"✅ success" : @"❌ failure" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

