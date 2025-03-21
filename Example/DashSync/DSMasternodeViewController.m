//
//  DSMasternodeViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/10/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSMasternodeViewController.h"
#import "DSClaimMasternodeViewController.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSMasternodeDetailViewController.h"
#import "DSMasternodeTableViewCell.h"
#import "DSRegisterMasternodeViewController.h"
#import <DashSync/DashSync.h>
#import <arpa/inet.h>

@interface DSMasternodeViewController ()
//@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
//@property (nonatomic, assign) std_collections_Map_keys_dashcore_hash_types_ProTxHash_values_dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry *entries;
//@property (nonatomic, assign) std_collections_Map_keys_dashcore_prelude_CoreBlockHeight_values_dashcore_sml_masternode_list_MasternodeList *lists;
@property (nonatomic, strong) NSString *searchString;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *registerButton;

@end

@implementation DSMasternodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//    [self updateLists];
////    self.lists = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_masternode_lists(self.chain.sharedProcessorObj);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//    [self updateLists];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateLists {
//    if (self.entries)
//        std_collections_Map_keys_dashcore_hash_types_ProTxHash_values_dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry(self.entries);
//    masternodes
//    self.entries = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_masternode_lists(self.chain.sharedProcessorObj);
}

#pragma mark - Automation KVO

//- (NSManagedObjectContext *)managedObjectContext {
//    return [NSManagedObjectContext viewContext];
//}
//
//- (NSPredicate *)searchPredicate {
//    if (!self.masternodeList) {
//        return [self mainSearchPredicate];
//    } else {
//        
//        
//        NSPredicate *masternodeListPredicate = [NSPredicate predicateWithFormat:@"ANY masternodeLists.block.height == %@", @(self.masternodeList->known_height)];
//        return [NSCompoundPredicate andPredicateWithSubpredicates:@[[self mainSearchPredicate], masternodeListPredicate]];
//    }
//}
//
//- (NSPredicate *)mainSearchPredicate {
//    // Get all shapeshifts that have been received by shapeshift.io or all shapeshifts that have no deposits but where we can verify a transaction has been pushed on the blockchain
//    if (self.searchString && ![self.searchString isEqualToString:@""]) {
//        if ([self.searchString isEqualToString:@"0"] || [self.searchString longLongValue]) {
//            NSArray *ipArray = [self.searchString componentsSeparatedByString:@"."];
//            NSMutableArray *partPredicates = [NSMutableArray array];
//            NSPredicate *chainPredicate = [NSPredicate predicateWithFormat:@"chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]];
//            [partPredicates addObject:chainPredicate];
//            for (int i = 0; i < MIN(ipArray.count, 4); i++) {
//                if ([ipArray[i] isEqualToString:@""]) break;
//                NSPredicate *currentPartPredicate = [NSPredicate predicateWithFormat:@"(((address >> %@) & 255) == %@)", @(24 - i * 8), @([ipArray[i] integerValue])];
//                [partPredicates addObject:currentPartPredicate];
//            }
//
//            return [NSCompoundPredicate andPredicateWithSubpredicates:partPredicates];
//        } else {
//            return [NSPredicate predicateWithFormat:@"chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]];
//        }
//    } else {
//        return [NSPredicate predicateWithFormat:@"chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]];
//    }
//}

//- (NSFetchedResultsController *)fetchedResultsController {
//    if (_fetchedResultsController) return _fetchedResultsController;
//    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
//    // Edit the entity name as appropriate.
//    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSSimplifiedMasternodeEntryEntity" inManagedObjectContext:self.managedObjectContext];
//    [fetchRequest setEntity:entity];
//
//    // Set the batch size to a suitable number.
//    [fetchRequest setFetchBatchSize:20];
//
//    // Edit the sort key as appropriate.
//    NSSortDescriptor *claimSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"localMasternode" ascending:NO];
//    NSSortDescriptor *validDescriptor = [[NSSortDescriptor alloc] initWithKey:@"isValid" ascending:NO];
//    NSSortDescriptor *addressSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"address" ascending:YES];
//    NSSortDescriptor *portSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"port" ascending:YES];
//    NSArray *sortDescriptors = @[claimSortDescriptor, validDescriptor, addressSortDescriptor, portSortDescriptor];
//
//    [fetchRequest setSortDescriptors:sortDescriptors];
//
//    NSPredicate *filterPredicate = [self searchPredicate];
//    [fetchRequest setPredicate:filterPredicate];
//
//    // Edit the section name key path and cache name if appropriate.
//    // nil for section name key path means "no sections".
//    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:@"localMasternode" cacheName:nil];
//    _fetchedResultsController = aFetchedResultsController;
//    aFetchedResultsController.delegate = self;
//    NSError *error = nil;
//    if (![aFetchedResultsController performFetch:&error]) {
//        // Replace this implementation with code to handle the error appropriately.
//        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
//        abort();
//    }
//
//    return aFetchedResultsController;
//}

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
    
    
    
//    id<NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
//    if ([[sectionInfo name] integerValue]) {
//        return @"My Masternodes";
//    } else {
        return @"Masternodes";
//    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
//    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.masternodeList ? self.masternodeList->masternodes->count : 0;
//    dashcore_sml_masternode_list_MasternodeList *list = self.lists->values;
//
//    id<NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
//    return [sectionInfo numberOfObjects];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.registerButton setEnabled:FALSE];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSMasternodeTableViewCell *cell = (DSMasternodeTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"MasternodeTableViewCellIdentifier" forIndexPath:indexPath];

    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


- (void)configureCell:(DSMasternodeTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
//    if (!self.lists) return;
    dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry *qualified_entry = self.masternodeList->masternodes->values[indexPath.row];
    
    dashcore_sml_masternode_list_entry_MasternodeListEntry *entry = qualified_entry->masternode_list_entry;
    u128 *ip_address = DSocketAddrIp(entry->service_address);
    uint16_t port = DSocketAddrPort(entry->service_address);
    UInt128 ipAddress = u128_cast(ip_address);

    char s[INET6_ADDRSTRLEN];
    uint32_t ipAddressu32 = ipAddress.u32[3];
    u256 *pro_reg_tx_hash = dashcore_hash_types_ProTxHash_inner(entry->pro_reg_tx_hash);
    cell.masternodeLocationLabel.text = [NSString stringWithFormat:@"%s:%d %@", inet_ntop(AF_INET, &ipAddressu32, s, sizeof(s)), port, (entry->is_valid ? @"" : @"(Not Valid)")];
    cell.outputLabel.text = u256_hex(pro_reg_tx_hash);
    u256_dtor(pro_reg_tx_hash);
//    cell.ping.text = [NSString stringWithFormat:@"%llu ms", simplifiedMasternodeEntryEntity.platformPing];
//        NSString *dateString = [NSDateFormatter localizedStringFromDate:simplifiedMasternodeEntryEntity.platformPingDate
//                                                              dateStyle:NSDateFormatterShortStyle
//                                                              timeStyle:NSDateFormatterMediumStyle];
//        cell.pingDate.text = dateString;
//        cell.protocolLabel.text = [NSString stringWithFormat:@"%llu", simplifiedMasternodeEntryEntity.coreProtocol];
    
//    char *voting_address = DMasternodeEntryVotingAddress(self.simplifiedMasternodeEntry->masternode_list_entry->key_id_voting, self.chain.chainType);
//    self.locationLabel.text = [NSString stringWithFormat:@"%s:%d", inet_ntop(AF_INET, &ipAddressu32, s, sizeof(s)), port];

//    DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
//    char s[INET6_ADDRSTRLEN];
//    uint32_t ipAddress = CFSwapInt32BigToHost((uint32_t)simplifiedMasternodeEntryEntity.address);
//    cell.masternodeLocationLabel.text = [NSString stringWithFormat:@"%s:%d %@", inet_ntop(AF_INET, &ipAddress, s, sizeof(s)), simplifiedMasternodeEntryEntity.port, (simplifiedMasternodeEntryEntity.isValid ? @"" : @"(Not Valid)")];
//    cell.ping.text = [NSString stringWithFormat:@"%llu ms", simplifiedMasternodeEntryEntity.platformPing];
//    NSString *dateString = [NSDateFormatter localizedStringFromDate:simplifiedMasternodeEntryEntity.platformPingDate
//                                                          dateStyle:NSDateFormatterShortStyle
//                                                          timeStyle:NSDateFormatterMediumStyle];
//    cell.pingDate.text = dateString;
//    cell.protocolLabel.text = [NSString stringWithFormat:@"%llu", simplifiedMasternodeEntryEntity.coreProtocol];
//    cell.outputLabel.text = simplifiedMasternodeEntryEntity.providerRegistrationTransactionHash.hexString;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.searchString = @"0";
//    _fetchedResultsController = nil;
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    self.searchString = searchBar.text;
//    _fetchedResultsController = nil;
    [self.tableView reloadData];
}

- (void)showAlertForPingTimes:(NSMutableDictionary<NSData *, NSNumber *> *)pingTimes errors:(NSMutableDictionary<NSData *, NSError *> *)errors {
    NSString *report = [NSString stringWithFormat:@"success : %lu | errors : %lu", (unsigned long)pingTimes.count, errors.count];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Report" message:report preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert
                       animated:YES
                     completion:^{

                     }];
}

- (void)pingPlatform {
    [self.chain.chainManager.masternodeManager checkPingTimesForCurrentMasternodeListInContext:[NSManagedObjectContext viewContext]
                                                                                withCompletion:^(NSMutableDictionary<NSData *, NSNumber *> *_Nonnull pingTimes, NSMutableDictionary<NSData *, NSError *> *_Nonnull errors) {
                                                                                    [self.tableView reloadData];
                                                                                    [self showAlertForPingTimes:pingTimes errors:errors];
                                                                                }];
}

- (IBAction)showAvailableActions:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Actions"
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Register"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *_Nonnull action) {
                                                          [self performSegueWithIdentifier:@"RegisterMasternodeSegue" sender:self];
                                                      }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Ping Platform"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *_Nonnull action) {
                                                          [self pingPlatform];
                                                      }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    BlockHeightFinder finder = ^uint32_t(UInt256 blockHash) {
        return [self.chain heightForBlockHash:blockHash];
    };
    if ([segue.identifier isEqualToString:@"MasternodeDetailSegue"]) {
        NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
        dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry *qualified_entry = self.masternodeList->masternodes->values[indexPath.row];

        
//        DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
        DSMasternodeDetailViewController *masternodeDetailViewController = (DSMasternodeDetailViewController *)segue.destinationViewController;
        masternodeDetailViewController.simplifiedMasternodeEntry = qualified_entry;
//        masternodeDetailViewController.simplifiedMasternodeEntry = [simplifiedMasternodeEntryEntity simplifiedMasternodeEntryWithBlockHeightLookup:finder];
//        masternodeDetailViewController.localMasternode = simplifiedMasternodeEntryEntity.localMasternode ? [simplifiedMasternodeEntryEntity.localMasternode loadLocalMasternode] : nil;
        masternodeDetailViewController.chain = self.chain;
    } else if ([segue.identifier isEqualToString:@"ClaimMasternodeSegue"]) {
        NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
        dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry *qualified_entry = self.masternodeList->masternodes->values[indexPath.row];

//        DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
        DSClaimMasternodeViewController *claimMasternodeViewController = (DSClaimMasternodeViewController *)segue.destinationViewController;
        claimMasternodeViewController.masternode = qualified_entry;
//        claimMasternodeViewController.masternode = [simplifiedMasternodeEntryEntity simplifiedMasternodeEntryWithBlockHeightLookup:finder];
        claimMasternodeViewController.chain = self.chain;
    } else if ([segue.identifier isEqualToString:@"RegisterMasternodeSegue"]) {
        UINavigationController *navigationController = (UINavigationController *)segue.destinationViewController;
        DSRegisterMasternodeViewController *registerMasternodeViewController = (DSRegisterMasternodeViewController *)navigationController.topViewController;
        registerMasternodeViewController.chain = self.chain;
    }
}

@end
