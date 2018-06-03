//
//  DSDerivationPathsAddressesViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSDerivationPathsAddressesViewController.h"
#import "DSAddressTableViewCell.h"
#import <DashSync/DashSync.h>

@interface DSDerivationPathsAddressesViewController ()

@property (nonatomic,strong) NSArray * addresses;

@end

@implementation DSDerivationPathsAddressesViewController

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

-(NSManagedObjectContext*)managedObjectContext {
    return [NSManagedObject context];
}

-(NSPredicate*)searchPredicate {
    // Get all shapeshifts that have been received by shapeshift.io or all shapeshifts that have no deposits but where we can verify a transaction has been pushed on the blockchain
    DSDerivationPathEntity * entity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self];
    return [NSPredicate predicateWithFormat:@"(derivationPath == %@)",entity];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSAddressEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:12];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *indexSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
    NSSortDescriptor *internalSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"internal" ascending:NO];
    NSArray *sortDescriptors = @[indexSortDescriptor,internalSortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSPredicate *filterPredicate = [self searchPredicate];
    //[fetchRequest setPredicate:filterPredicate];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
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

    return [[self.derivationPath.allAddresses allObjects] count];
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

}


@end
