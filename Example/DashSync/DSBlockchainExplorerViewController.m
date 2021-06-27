//
//  DSBlockchainExplorerViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSBlockchainExplorerViewController.h"
#import "DSMerkleBlockTableViewCell.h"
#import <DashSync/DashSync.h>

@interface DSBlockchainExplorerViewController ()

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) NSString *searchString;

@end

@implementation DSBlockchainExplorerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Automation KVO

- (NSManagedObjectContext *)managedObjectContext {
    return [NSManagedObjectContext viewContext];
}

- (NSPredicate *)searchPredicate {
    // Get all shapeshifts that have been received by shapeshift.io or all shapeshifts that have no deposits but where we can verify a transaction has been pushed on the blockchain
    NSManagedObjectContext *context = self.managedObjectContext;
    if (self.searchString && ![self.searchString isEqualToString:@""]) {
        if (self.searchString.length < 10 && ([self.searchString isEqualToString:@"0"] || [self.searchString longLongValue])) {
            return [NSPredicate predicateWithFormat:@"chain == %@ && (height == %@)", [self.chain chainEntityInContext:context], @([self.searchString longLongValue])];
        } else if (self.searchString.length > 10) {
            return [NSPredicate predicateWithFormat:@"chain == %@ && (blockHash == %@ || blockHash == %@ )", [self.chain chainEntityInContext:context], self.searchString.hexToData, self.searchString.hexToData.reverse];
        } else {
            return [NSPredicate predicateWithFormat:@"chain == %@", [self.chain chainEntityInContext:context]];
        }
    } else {
        return [NSPredicate predicateWithFormat:@"chain == %@", [self.chain chainEntityInContext:context]];
    }
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSMerkleBlockEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];

    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];

    // Edit the sort key as appropriate.
    NSSortDescriptor *heightSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"height" ascending:NO];
    NSArray *sortDescriptors = @[heightSortDescriptor];

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
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
             atIndex:(NSUInteger)sectionIndex
       forChangeType:(NSFetchedResultsChangeType)type {
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
        atIndexPath:(NSIndexPath *)indexPath
      forChangeType:(NSFetchedResultsChangeType)changeType
       newIndexPath:(NSIndexPath *)newIndexPath {
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.fetchedResultsController fetchedObjects] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSMerkleBlockTableViewCell *cell = (DSMerkleBlockTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"MerkleBlockCellIdentifier" forIndexPath:indexPath];

    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


- (void)configureCell:(DSMerkleBlockTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    DSMerkleBlockEntity *merkleBlockEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.blockHeightLabel.text = [NSString stringWithFormat:@"%u", merkleBlockEntity.height];
    cell.blockHashLabel.text = merkleBlockEntity.blockHash.reverse.hexString;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:merkleBlockEntity.timestamp];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    cell.timestampLabel.text = [dateFormatter stringFromDate:date];
    cell.chainLockedLabel.text = merkleBlockEntity.chainLock ? [NSString stringWithFormat:@"Yes-%@", merkleBlockEntity.chainLock.validSignature ? @"Valid" : @"Invalid"] : @"Unknown";
    NSString *chainWorkString = uint256_reverse_hex(merkleBlockEntity.chainWork.UInt256);
    NSRange range = [chainWorkString rangeOfString:@"^0*" options:NSRegularExpressionSearch];
    chainWorkString = [chainWorkString stringByReplacingCharactersInRange:range withString:@""];
    cell.chainWorkLabel.text = chainWorkString;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.searchString = @"0";
    _fetchedResultsController = nil;
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    self.searchString = searchBar.text;
    _fetchedResultsController = nil;
    [self.tableView reloadData];
}
@end
