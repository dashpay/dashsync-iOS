//
//  DSDerivationPathsAddressesViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSDerivationPathsAddressesViewController.h"
#import "DSAddressTableViewCell.h"
#import <DashSync/DashSync.h>
#import "BRBubbleView.h"
#import "DSAddressesExporterViewController.h"
#import "DSAddressesTransactionsViewController.h"

@interface DSDerivationPathsAddressesViewController ()

@property (nonatomic,strong) NSArray * addresses;
@property (nonatomic,strong) NSFetchedResultsController * fetchedResultsController;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;
@property (nonatomic,assign) BOOL externalScope;

@end

@implementation DSDerivationPathsAddressesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _externalScope = YES;
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

-(NSManagedObjectContext*)managedObjectContext {
    if (!_managedObjectContext) self.managedObjectContext = [NSManagedObject context];
    return _managedObjectContext;
}

-(NSPredicate*)searchPredicate {
    DSDerivationPathEntity * entity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self.derivationPath];
    return [NSPredicate predicateWithFormat:@"(derivationPath == %@) && (internal == %@)",entity,@(!self.externalScope)];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSAddressEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:12];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *indexSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
    NSSortDescriptor *internalSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"internal" ascending:NO];
    NSArray *sortDescriptors = @[internalSortDescriptor,indexSortDescriptor];
    
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


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)changeType
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
    DSAddressTableViewCell *cell = (DSAddressTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"AddressCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


-(void)configureCell:(DSAddressTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSAddressEntity *addressEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.addressLabel.text = addressEntity.address;
    cell.derivationPathLabel.text = [NSString stringWithFormat:@"%@/%d/%u",self.derivationPath.stringRepresentation,addressEntity.internal?1:0,addressEntity.index];
    cell.balanceLabel.text = [NSString stringWithFormat:@"%llu",addressEntity.balance];
    cell.inLabel.text = [NSString stringWithFormat:@"%llu",addressEntity.inAmount];
    cell.outLabel.text = [NSString stringWithFormat:@"%llu",addressEntity.outAmount];

}

-(IBAction)copyAddress:(id)sender {
    for (UITableViewCell * cell in self.tableView.visibleCells) {
        if ([sender isDescendantOfView:cell]) {
            NSIndexPath * indexPath = [self.tableView indexPathForCell:cell];
            DSAddressEntity *addressEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = addressEntity.address;
            [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"copied", nil)
                                                        center:CGPointMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0 - 130.0)] popIn]
                                   popOutAfterDelay:2.0]];
            break;
        }
    }

}

// MARK:- Search Bar Delegate

-(void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    self.externalScope = !selectedScope;
    self.fetchedResultsController = nil;
    [self.tableView reloadData];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
if ([segue.identifier isEqualToString:@"ExportAddressesSegue"]) {
    DSAddressesExporterViewController * addressesExporterViewController = (DSAddressesExporterViewController*)segue.destinationViewController;
    addressesExporterViewController.derivationPath = self.derivationPath;
} else if ([segue.identifier isEqualToString:@"AddressTransactionsSegue"]) {
    DSAddressEntity *addressEntity = [self.fetchedResultsController objectAtIndexPath:[self.tableView indexPathForSelectedRow]];
    DSAddressesTransactionsViewController * addressesTransactionsViewController = (DSAddressesTransactionsViewController*)segue.destinationViewController;
    addressesTransactionsViewController.title = addressEntity.address;
    addressesTransactionsViewController.address = addressEntity.address;
}
}



@end
