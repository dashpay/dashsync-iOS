//  
//  Created by Sam Westrich
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSContactReceivedTransactionsTableViewController.h"
#import "DSTransactionDetailTableViewCell.h"

@interface DSContactReceivedTransactionsTableViewController ()

@property (nonatomic,strong) DSAccount * account;
@property (nonatomic,strong) NSFetchedResultsController * fetchedResultsController;

@end

@implementation DSContactReceivedTransactionsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

-(void)setBlockchainUser:(DSBlockchainUser *)blockchainUser {
    _blockchainUser = blockchainUser;
    if (_friendRequest) {
        self.account = [blockchainUser.wallet accountWithNumber:_friendRequest.account.index];
    }
}

-(void)setFriendRequest:(DSFriendRequestEntity *)friendRequest {
    _friendRequest = friendRequest;
    if (_blockchainUser) {
        self.account = [_blockchainUser.wallet accountWithNumber:_friendRequest.account.index];
    }
}



-(NSPredicate*)searchPredicate {
    return [NSPredicate predicateWithFormat:@"localAddress.derivationPath.friendRequest == %@",self.friendRequest];
}

-(NSManagedObjectContext*)managedObjectContext {
    return [NSManagedObject context];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSTxOutputEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *usernameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"transaction.transactionHash.blockHeight" ascending:YES];
    NSArray *sortDescriptors = @[usernameSortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSPredicate *filterPredicate = [self searchPredicate];
    [fetchRequest setPredicate:filterPredicate];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    _fetchedResultsController = aFetchedResultsController;
    aFetchedResultsController.delegate = self;
    NSError *error = nil;
    if (![aFetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return aFetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
    [self.tableView endUpdates];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [[self.fetchedResultsController fetchedObjects] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSTransactionDetailTableViewCell *cell = (DSTransactionDetailTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"TransactionCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(DSTransactionDetailTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {

    DSTxOutputEntity * transactionOuput = [self.fetchedResultsController objectAtIndexPath:indexPath];
    DSTransaction * transaction = [self.account transactionForHash:transactionOuput.transaction.transactionHash.txHash.UInt256];
    cell.addressLabel.text = transactionOuput.address;
    cell.amountLabel.text = [NSString stringWithFormat:@"%llu",[self.account amountSentByTransaction:transaction]];
}


@end
