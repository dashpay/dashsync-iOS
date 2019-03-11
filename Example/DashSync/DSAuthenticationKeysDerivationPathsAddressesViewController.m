//
//  DSAuthenticationKeysDerivationPathsAddressesViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 3/11/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSAuthenticationKeysDerivationPathsAddressesViewController.h"
#import "DSAddressTableViewCell.h"
#import <DashSync/DashSync.h>
#import "BRBubbleView.h"
#import "DSAddressesExporterViewController.h"
#import "DSAddressesTransactionsViewController.h"

@interface DSAuthenticationKeysDerivationPathsAddressesViewController ()

@property (nonatomic,strong) NSArray * addresses;
@property (nonatomic,strong) NSFetchedResultsController * fetchedResultsController;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSAuthenticationKeysDerivationPathsAddressesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
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
    return [NSPredicate predicateWithFormat:@"(derivationPath == %@)",entity];
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
    NSArray *sortDescriptors = @[indexSortDescriptor];
    
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
    cell.derivationPathLabel.text = [NSString stringWithFormat:@"%@/%u",self.derivationPath.stringRepresentation,addressEntity.index];
    cell.publicKeyLabel.text = [self.derivationPath publicKeyDataAtIndex:addressEntity.index].hexString;
}



//-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    if ([segue.identifier isEqualToString:@"ExportAddressesSegue"]) {
//        DSAddressesExporterViewController * addressesExporterViewController = (DSAddressesExporterViewController*)segue.destinationViewController;
//        addressesExporterViewController.derivationPath = self.derivationPath;
//    } else if ([segue.identifier isEqualToString:@"AddressTransactionsSegue"]) {
//        DSAddressEntity *addressEntity = [self.fetchedResultsController objectAtIndexPath:[self.tableView indexPathForSelectedRow]];
//        DSAddressesTransactionsViewController * addressesTransactionsViewController = (DSAddressesTransactionsViewController*)segue.destinationViewController;
//        addressesTransactionsViewController.title = addressEntity.address;
//        addressesTransactionsViewController.address = addressEntity.address;
//        addressesTransactionsViewController.wallet = self.derivationPath.wallet;
//    }
//}



@end
