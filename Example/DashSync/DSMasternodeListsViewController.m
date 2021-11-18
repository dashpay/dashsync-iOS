//
//  DSMasternodeListsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/18/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSMasternodeListsViewController.h"
#import "BRBubbleView.h"
#import "DSClaimMasternodeViewController.h"
#import "DSMasternodeDetailViewController.h"
#import "DSMasternodeListTableViewCell.h"
#import "DSMasternodeViewController.h"
#import "DSMerkleBlock.h"
#import "DSRegisterMasternodeViewController.h"
#import <DashSync/DashSync.h>

@interface DSMasternodeListsViewController ()
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) IBOutlet UITextField *blockHeightTextField;
@property (strong, nonatomic) IBOutlet UIButton *fetchButton;
@property (strong, nonatomic) NSMutableDictionary<NSData *, NSNumber *> *validMerkleRootDictionary;

@end

@implementation DSMasternodeListsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _validMerkleRootDictionary = [NSMutableDictionary dictionary];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Automation KVO

- (NSManagedObjectContext *)managedObjectContext {
    return [NSManagedObjectContext viewContext];
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSMasternodeListEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];

    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];

    // Edit the sort key as appropriate.
    NSSortDescriptor *heightSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"block.height" ascending:NO];
    NSArray *sortDescriptors = @[heightSortDescriptor];

    [fetchRequest setSortDescriptors:sortDescriptors];

    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"block.chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]];
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
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
             atIndex:(NSUInteger)sectionIndex
       forChangeType:(NSFetchedResultsChangeType)type {
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    UITableView *tableView = self.tableView;

    switch (type) {
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
    id<NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSMasternodeListTableViewCell *cell = (DSMasternodeListTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"MasternodeListTableViewCellIdentifier" forIndexPath:indexPath];
    cell.masternodeListCellDelegate = self;
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [self.tableView beginUpdates];
        DSMasternodeListEntity *masternodeListEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [masternodeListEntity deleteObjectAndWait];
        [masternodeListEntity.managedObjectContext ds_saveInBlockAndWait];
        [self.chain.chainManager.masternodeManager reloadMasternodeLists];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView endUpdates];
    }
}


- (void)configureCell:(DSMasternodeListTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (cell) {
        DSMasternodeListEntity *masternodeListEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
        cell.heightLabel.text = [NSString stringWithFormat:@"%u", masternodeListEntity.block.height];
        cell.countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)masternodeListEntity.masternodes.count];
        NSNumber *valid = [self.validMerkleRootDictionary objectForKey:masternodeListEntity.block.blockHash];
        [cell.validButton setTitle:valid ? ([valid boolValue] ? @"V" : @"X") : @"?" forState:UIControlStateNormal];
    }
}

- (IBAction)fetchMasternodeList:(id)sender {
    uint32_t blockHeight = (![self.blockHeightTextField.text isEqualToString:@""]) ? [self.blockHeightTextField.text intValue] : self.chain.lastSyncBlock.height;

    NSError *error = nil;
    [self.chain.chainManager.masternodeManager requestMasternodeListForBlockHeight:blockHeight error:&error];
    if (error) {
        [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"sent!", nil)
                                                    center:CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2)] popIn]
                                  popOutAfterDelay:2.0]];
    }
}

- (IBAction)fetchNextMasternodeList:(id)sender {
    int32_t lastKnownBlockHeight = self.chain.chainManager.masternodeManager.currentMasternodeList.height;
    if (lastKnownBlockHeight + 24 > self.chain.lastSyncBlock.height) return;
    uint32_t blockHeight = lastKnownBlockHeight + 24;

    NSError *error = nil;
    [self.chain.chainManager.masternodeManager requestMasternodeListForBlockHeight:blockHeight error:&error];
    if (error) {
        [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"sent!", nil)
                                                    center:CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2)] popIn]
                                  popOutAfterDelay:2.0]];
    }
}

- (IBAction)reloadList:(id)sender {
    [self.chain.chainManager.masternodeManager reloadMasternodeLists];
}

- (void)masternodeListTableViewCellRequestsValidation:(DSMasternodeListTableViewCell *)tableViewCell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:tableViewCell];
    DSMasternodeListEntity *masternodeListEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
    DSMasternodeList *masternodeList = [self.chain.chainManager.masternodeManager masternodeListForBlockHash:masternodeListEntity.block.blockHash.UInt256];
    BOOL equal = uint256_eq(masternodeListEntity.masternodeListMerkleRoot.UInt256, [masternodeList masternodeMerkleRoot]);
    [self.validMerkleRootDictionary setObject:@(equal) forKey:uint256_data(masternodeList.blockHash)];
    [tableViewCell.validButton setTitle:(equal ? @"V" : @"X") forState:UIControlStateNormal];
    if (!equal) {
        DSLogPrivate(@"The merkle roots are not equal, from disk we have <%@> calculated we have <%@>", masternodeListEntity.masternodeListMerkleRoot.hexString, uint256_hex([masternodeList masternodeMerkleRoot]));
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"MasternodeListSegue"]) {
        NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
        DSMasternodeListEntity *masternodeListEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
        DSMasternodeViewController *masternodeViewController = (DSMasternodeViewController *)segue.destinationViewController;
        masternodeViewController.chain = self.chain;
        UInt256 hash = masternodeListEntity.block.blockHash.UInt256;
        // could be moved into rust lib
        DSMasternodeList *masternodeList = [self.chain.chainManager.masternodeManager masternodeListForBlockHash:hash];
        masternodeViewController.masternodeList = masternodeList;
    }
}

@end
