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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mocDidSaveNotification:)
                                                 name:NSManagedObjectContextDidSaveNotification object:self.context];
}

- (IBAction)refreshAction:(id)sender {
    [self.refreshControl beginRefreshing];
    __weak typeof(self) weakSelf = self;
    [self.blockchainIdentity fetchIncomingContactRequests:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        [strongSelf.refreshControl endRefreshing];
    }];
}

- (void)mocDidSaveNotification:(NSNotification *)notification {
    // Since NSFetchedResultsController doesn't observe relationship changes we have to manully trigger an update
    // http://openradar.appspot.com/radar?id=1754401
    BOOL (^objectsHasChangedContact)(NSArray *, DSDashpayUserEntity *) = ^BOOL(NSArray *objects, DSDashpayUserEntity *contact) {
        BOOL hasRelationshipChanges = NO;
        for (NSManagedObject *mo in objects) {
            if ([mo isKindOfClass:DSFriendRequestEntity.class]) {
                DSFriendRequestEntity *friendRequest = (DSFriendRequestEntity *)mo;
                if (friendRequest.sourceContact == contact ||
                    friendRequest.destinationContact == contact) {
                    hasRelationshipChanges = YES;
                    break;
                }
            }
        }
        
        return hasRelationshipChanges;
    };
    
    NSArray <NSManagedObject *> *insertedObjects = notification.userInfo[NSInsertedObjectsKey];
    NSArray <NSManagedObject *> *updatedObjects = notification.userInfo[NSUpdatedObjectsKey];
    NSArray <NSManagedObject *> *deletedObjects = notification.userInfo[NSDeletedObjectsKey];
    
    DSDashpayUserEntity *contact = [self.blockchainIdentity matchingDashpayUserInContext:self.context];
    if (objectsHasChangedContact(insertedObjects, contact) ||
        objectsHasChangedContact(updatedObjects, contact) ||
        objectsHasChangedContact(deletedObjects, contact)) {
        self.fetchedResultsController = nil;
        [self.tableView reloadData];
    }
}

- (NSString *)entityName {
    return @"DSFriendRequestEntity";
}

-(NSPredicate*)predicate {
    //incoming request from marge to homer
    //own contact is homer
    //self is marge
    //validates to being a request from marge to homer
    return [NSPredicate predicateWithFormat:@"destinationContact == %@ && (SUBQUERY(destinationContact.outgoingRequests, $friendRequest, $friendRequest.destinationContact == SELF.sourceContact).@count == 0)",self.blockchainIdentity.matchingDashpayUser];
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
    [self.blockchainIdentity acceptFriendRequest:friendRequest completion:^(BOOL success) {
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

