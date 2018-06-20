//
//  DSMasternodeViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/10/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSMasternodeViewController.h"
#import "DSMasternodeTableViewCell.h"
#import <DashSync/DashSync.h>
#import <arpa/inet.h>
#import "DSClaimMasternodeViewController.h"

@interface DSMasternodeViewController ()
@property (nonatomic,strong) NSFetchedResultsController * fetchedResultsController;
@property (nonatomic,strong) NSString * searchString;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *claimButton;
- (IBAction)claimSelectedMasternode:(id)sender;

@end

@implementation DSMasternodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.claimButton.enabled = FALSE;
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
    if (self.searchString && ![self.searchString isEqualToString:@""]) {
        if ([self.searchString isEqualToString:@"0"] || [self.searchString longLongValue]) {
            NSArray * ipArray = [self.searchString componentsSeparatedByString:@"."];
            NSMutableArray *partPredicates = [NSMutableArray array];
            NSPredicate * chainPredicate = [NSPredicate predicateWithFormat:@"masternodeBroadcastHash.chain == %@",self.chain.chainEntity];
            [partPredicates addObject:chainPredicate];
            for (int i = 0; i< MIN(ipArray.count,4); i++) {
                if ([ipArray[i] isEqualToString:@""]) break;
                NSPredicate *currentPartPredicate = [NSPredicate predicateWithFormat:@"(((address >> %@) & 255) == %@)", @(i*8),@([ipArray[i] integerValue])];
                [partPredicates addObject:currentPartPredicate];
            }
            
            return [NSCompoundPredicate andPredicateWithSubpredicates:partPredicates];
        } else {
            return [NSPredicate predicateWithFormat:@"masternodeBroadcastHash.chain == %@",self.chain.chainEntity];
        }
        //        else {
        //            return [NSPredicate predicateWithFormat:@"(blockHash == %@)",self.searchString];
        //        }
        
    } else {
        return [NSPredicate predicateWithFormat:@"masternodeBroadcastHash.chain == %@",self.chain.chainEntity];
    }
    
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSMasternodeBroadcastEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *heightSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"address" ascending:YES];
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

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.claimButton setEnabled:TRUE];
}

-(void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.claimButton setEnabled:FALSE];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSMasternodeTableViewCell *cell = (DSMasternodeTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"MasternodeTableViewCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


-(void)configureCell:(DSMasternodeTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSMasternodeBroadcastEntity *masternodeBroadcastEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
    char s[INET6_ADDRSTRLEN];
    uint32_t ipAddress = masternodeBroadcastEntity.address;
    cell.ipAddressLabel.text = [NSString stringWithFormat:@"%s",inet_ntop(AF_INET, &ipAddress, s, sizeof(s))];
    cell.protocolLabel.text = [NSString stringWithFormat:@"%u",masternodeBroadcastEntity.protocolVersion];
    cell.outputLabel.text = [NSString stringWithFormat:@"%@:%u",masternodeBroadcastEntity.utxoHash.hexString,masternodeBroadcastEntity.utxoIndex];
}

-(void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.searchString = @"0";
    _fetchedResultsController = nil;
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    self.searchString = searchBar.text;
    _fetchedResultsController = nil;
    [self.tableView reloadData];
}

- (IBAction)claimSelectedMasternode:(id)sender {
    if (self.tableView.indexPathForSelectedRow) {
        [self performSegueWithIdentifier:@"ClaimMasternodeSegue" sender:sender];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ClaimMasternodeSegue"]) {
        NSIndexPath * indexPath = self.tableView.indexPathForSelectedRow;
        DSMasternodeBroadcastEntity *masternodeBroadcastEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
        DSClaimMasternodeViewController * claimMasternodeViewController = (DSClaimMasternodeViewController*)segue.destinationViewController;
        claimMasternodeViewController.masternode = masternodeBroadcastEntity.masternodeBroadcast;
        claimMasternodeViewController.chain = self.chain;
    }
}
@end
