//
//  DSQuorumListViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 5/15/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSQuorumListViewController.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSQuorumTableViewCell.h"
#import <DashSync/DashSync.h>
#import <arpa/inet.h>

@interface DSQuorumListViewController ()
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) NSString *searchString;

@end

@implementation DSQuorumListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
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
    if (self.searchString && ![self.searchString isEqualToString:@""]) {
        return [NSPredicate predicateWithFormat:@"chain == %@ && block.height == %@", [self.chain chainEntityInContext:self.managedObjectContext], self.searchString];
    } else {
        return [NSPredicate predicateWithFormat:@"chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]];
    }
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSQuorumEntryEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];

    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];

    // Edit the sort key as appropriate.
    NSSortDescriptor *quorumTypeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"llmqType" ascending:NO];
    NSSortDescriptor *quorumIndexSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"quorumIndex" ascending:YES];
    NSSortDescriptor *quorumHeightSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"block.height" ascending:NO];
    NSSortDescriptor *quorumHashDataSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"quorumHashData" ascending:NO];
//    NSSortDescriptor *quorumHashDataSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"quorumHashData" ascending:NO comparator:^NSComparisonResult(NSData *obj1, NSData *obj2) {
//        return uint256_compare(obj1.UInt256, obj2.UInt256);
//    }];
//
    
    NSArray *sortDescriptors = @[quorumTypeSortDescriptor, quorumIndexSortDescriptor, quorumHeightSortDescriptor, quorumHashDataSortDescriptor];

    [fetchRequest setSortDescriptors:sortDescriptors];

    NSPredicate *filterPredicate = [self searchPredicate];
    [fetchRequest setPredicate:filterPredicate];

    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:@"llmqType" cacheName:nil];
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id<NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    NSInteger quorumType = [[sectionInfo name] integerValue];
    switch (quorumType) {
        case dash_spv_crypto_network_llmq_type_LLMQType_LlmqtypeUnknown:
            return @"Unknown Quorums (0)";
        case dash_spv_crypto_network_llmq_type_LLMQType_Llmqtype50_60:
            return @"1 Hour Quorums (1)";
        case dash_spv_crypto_network_llmq_type_LLMQType_Llmqtype400_60:
            return @"Day Quorums (2)";
        case dash_spv_crypto_network_llmq_type_LLMQType_Llmqtype400_85:
            return @"2 Day Quorums (3)";
        case dash_spv_crypto_network_llmq_type_LLMQType_Llmqtype100_67:
            return @"1 Hour Platform Quorums (4)";
        case dash_spv_crypto_network_llmq_type_LLMQType_Llmqtype60_75:
            return @"1 Hour Rotated Quorums (v0.18) (5)";
        case dash_spv_crypto_network_llmq_type_LLMQType_Llmqtype25_67:
            return @"1 Hour Platform Quorums (v0.19) (6)";
        case dash_spv_crypto_network_llmq_type_LLMQType_LlmqtypeTest:
            return @"Test Quorums (100)";
        case dash_spv_crypto_network_llmq_type_LLMQType_LlmqtypeDevnet:
            return @"10 Member Devnet Quorums (101)";
        case dash_spv_crypto_network_llmq_type_LLMQType_LlmqtypeTestV17:
            return @"Test V17 Quorums (102)";
        case dash_spv_crypto_network_llmq_type_LLMQType_LlmqtypeTestDIP0024:
        case dash_spv_crypto_network_llmq_type_LLMQType_LlmqtypeDevnetDIP0024:
        case dash_spv_crypto_network_llmq_type_LLMQType_LlmqtypeTestnetPlatform:
        case dash_spv_crypto_network_llmq_type_LLMQType_LlmqtypeDevnetPlatform:
            return [NSString stringWithFormat:@"Test DIP-0024 & DIP-0027 Quorums (%ld)", quorumType] ;
        default:
            return [NSString stringWithFormat:@"Unknown Quorum Type (%ld)", quorumType];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id<NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSQuorumTableViewCell *cell = (DSQuorumTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"QuorumTableViewCellIdentifier" forIndexPath:indexPath];

    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


- (void)configureCell:(DSQuorumTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    DSQuorumEntryEntity *quorumEntryEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];

    cell.quorumHashLabel.text = uint256_hex(quorumEntryEntity.quorumHash);
    cell.indexLabel.text = [NSString stringWithFormat:@"%d", quorumEntryEntity.quorumIndex];
    cell.verifiedLabel.text = quorumEntryEntity.verified ? @"Yes" : @"No";
    if (quorumEntryEntity.block) {
        cell.heightLabel.text = [NSString stringWithFormat:@"%d", quorumEntryEntity.block.height];
    } else {
        cell.heightLabel.text = @"?";
    }
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"QuorumDetailSegue"]) {
        //        NSIndexPath * indexPath = self.tableView.indexPathForSelectedRow;
        //        DSQuorumEntryEntity *quorumEntryEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
        //        DSMasternodeDetailViewController * masternodeDetailViewController = (DSMasternodeDetailViewController*)segue.destinationViewController;
        //        masternodeDetailViewController.simplifiedMasternodeEntry = simplifiedMasternodeEntryEntity.simplifiedMasternodeEntry;
        //        masternodeDetailViewController.localMasternode = simplifiedMasternodeEntryEntity.localMasternode?[simplifiedMasternodeEntryEntity.localMasternode loadLocalMasternode]:nil;
        //        masternodeDetailViewController.chain = self.chain;
    }
}
@end
