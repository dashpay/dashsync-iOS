//
//  DSGovernanceObjectListViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/15/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSGovernanceObjectListViewController.h"
#import "DSProposalTableViewCell.h"
#import <DashSync/DashSync.h>

#define SUPERBLOCK_AVEREAGE_TIME 2575480

@interface DSGovernanceObjectListViewController ()
@property (nonatomic,strong) NSFetchedResultsController * fetchedResultsController;
@property (nonatomic,strong) NSString * searchString;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *voteButton;
- (IBAction)showVoteDialog:(id)sender;

@end

@implementation DSGovernanceObjectListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.voteButton.enabled = FALSE;
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
            return [NSPredicate predicateWithFormat:@"governanceObjectHash.chain == %@ && (identifier == %@)",self.chainPeerManager.chain.chainEntity,@([self.searchString longLongValue])];
        } else {
            return [NSPredicate predicateWithFormat:@"governanceObjectHash.chain == %@",self.chainPeerManager.chain.chainEntity];
        }
        //        else {
        //            return [NSPredicate predicateWithFormat:@"(blockHash == %@)",self.searchString];
        //        }
        
    } else {
        return [NSPredicate predicateWithFormat:@"governanceObjectHash.chain == %@",self.chainPeerManager.chain.chainEntity];
    }
    
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSGovernanceObjectEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *heightSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO];
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSProposalTableViewCell *cell = (DSProposalTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"ProposalCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.voteButton.enabled = TRUE;
}

-(void)configureCell:(DSProposalTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSGovernanceObjectEntity *governanceObjectEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.paymentAddresLabel.text = governanceObjectEntity.paymentAddress;
    cell.identifierLabel.text = governanceObjectEntity.identifier;
    cell.amountLabel.attributedText = [[DSWalletManager sharedInstance] attributedStringForDashAmount:governanceObjectEntity.amount];
    cell.urlLabel.text = governanceObjectEntity.url;
    NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterLongStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    cell.startDateLabel.text = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:governanceObjectEntity.timestamp]];
    cell.endDateLabel.text = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:governanceObjectEntity.endEpoch]];
    NSTimeInterval duration = governanceObjectEntity.endEpoch - governanceObjectEntity.startEpoch;
    NSTimeInterval previousDuration = [[NSDate date] timeIntervalSince1970] - governanceObjectEntity.startEpoch;
    NSUInteger cycles = duration / SUPERBLOCK_AVEREAGE_TIME;
    NSUInteger previousCycles = previousDuration / SUPERBLOCK_AVEREAGE_TIME;
    
    cell.paymentsCountLabel.text = [NSString stringWithFormat:@"%lu / %lu",(unsigned long)previousCycles,(unsigned long)cycles];
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

-(void)vote:(DSGovernanceVoteOutcome)outcome {
    DSGovernanceObjectEntity * proposalEntity = [self.fetchedResultsController objectAtIndexPath:[self.tableView indexPathForSelectedRow]];
    [self.chainPeerManager.governanceSyncManager vote:outcome onGovernanceProposal:[proposalEntity governanceObject]];
}

- (IBAction)showVoteDialog:(id)sender {
    DSGovernanceObject * proposal = [self.fetchedResultsController objectAtIndexPath:[self.tableView indexPathForSelectedRow]];
    NSString * message = [NSString stringWithFormat:@"How would you like to vote on %@",proposal.identifier];
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"Vote" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"YES" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self vote:DSGovernanceVoteOutcome_Yes];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"NO" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self vote:DSGovernanceVoteOutcome_No];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Abstain" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self vote:DSGovernanceVoteOutcome_Abstain];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [self presentViewController:alertController animated:TRUE completion:nil];
}

@end
