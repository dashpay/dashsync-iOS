//
//  DSPeersViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/31/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSPeersViewController.h"
#import "DSClaimMasternodeViewController.h"
#import "DSPeerTableViewCell.h"
#import <DashSync/DashSync.h>
#import <arpa/inet.h>
#import <asl.h>
#import <netdb.h>
#import <sys/socket.h>

@interface DSPeersViewController ()
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) NSString *searchString;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *trustedNodeButton;
- (IBAction)trustSelectedNode:(id)sender;

@end

@implementation DSPeersViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.trustedNodeButton.enabled = FALSE;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (DSPeerManager *)peerManager {
    return self.chainManager.peerManager;
}

#pragma mark - Automation KVO

- (NSManagedObjectContext *)managedObjectContext {
    return [NSManagedObjectContext viewContext];
}

- (NSPredicate *)searchPredicate {
    // Get all shapeshifts that have been received by shapeshift.io or all shapeshifts that have no deposits but where we can verify a transaction has been pushed on the blockchain

    if (self.searchString && ![self.searchString isEqualToString:@""]) {
        if ([self.searchString isEqualToString:@"0"] || [self.searchString longLongValue]) {
            NSArray *ipArray = [self.searchString componentsSeparatedByString:@"."];
            NSMutableArray *partPredicates = [NSMutableArray array];
            NSPredicate *chainPredicate = [NSPredicate predicateWithFormat:@"chain == %@", [self.chainManager.chain chainEntityInContext:self.managedObjectContext]];
            [partPredicates addObject:chainPredicate];
            for (int i = 0; i < MIN(ipArray.count, 4); i++) {
                if ([ipArray[i] isEqualToString:@""]) break;
                NSPredicate *currentPartPredicate = [NSPredicate predicateWithFormat:@"(((address >> %@) & 255) == %@)", @(i * 8), @([ipArray[i] integerValue])];
                [partPredicates addObject:currentPartPredicate];
            }

            return [NSCompoundPredicate andPredicateWithSubpredicates:partPredicates];
        } else {
            return [NSPredicate predicateWithFormat:@"chain == %@", [self.chainManager.chain chainEntityInContext:self.managedObjectContext]];
        }
    } else {
        return [NSPredicate predicateWithFormat:@"chain == %@", [self.chainManager.chain chainEntityInContext:self.managedObjectContext]];
    }
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSPeerEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];

    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];

    // Edit the sort key as appropriate.
    NSSortDescriptor *claimSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"priority" ascending:NO];
    NSSortDescriptor *heightSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"address" ascending:YES];
    NSArray *sortDescriptors = @[claimSortDescriptor, heightSortDescriptor];

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
    id<NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    __unused id<NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:indexPath.section];
    [self.trustedNodeButton setEnabled:TRUE];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.trustedNodeButton setEnabled:FALSE];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSPeerTableViewCell *cell = (DSPeerTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"PeerCellIdentifier" forIndexPath:indexPath];

    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


- (void)configureCell:(DSPeerTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    DSPeerEntity *peerEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
    char s[INET6_ADDRSTRLEN];
    uint32_t ipAddress = CFSwapInt32HostToBig(peerEntity.address);

    cell.addressLabel.text = [NSString stringWithFormat:@"%s", inet_ntop(AF_INET, &ipAddress, s, sizeof(s))];
    cell.priorityLabel.text = [NSString stringWithFormat:@"%u", peerEntity.priority];

    UInt128 address = (UInt128){.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), ipAddress}};

    DSPeerStatus status = [self.chainManager.peerManager statusForLocation:address port:peerEntity.port];
    NSString *statusString;
    switch (status) {
        case DSPeerStatus_Unknown:
            statusString = @"Unknown";
            break;
        case DSPeerStatus_Banned:
            statusString = @"Banned";
            break;
        case DSPeerStatus_Connected:
            statusString = @"Connected";
            break;
        case DSPeerStatus_Connecting:
            statusString = @"Connecting";
            break;
        case DSPeerStatus_Disconnected:
            statusString = @"Disconnected";
            break;
        default:
            break;
    }
    cell.statusLabel.text = statusString;
    DSPeerType type = [self.chainManager.peerManager typeForLocation:address port:peerEntity.port];
    NSString *typeString;
    switch (type) {
        case DSPeerType_Unknown:
            typeString = @"Unknown";
            break;
        case DSPeerType_MasterNode:
            typeString = @"Masternode";
            break;
        case DSPeerType_FullNode:
            typeString = @"Full Node";
            break;
        default:
            break;
    }
    cell.nodeTypeLabel.text = typeString;
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

- (IBAction)trustSelectedNode:(id)sender {
    NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
    DSPeerEntity *peerEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];

    uint32_t ipAddress = CFSwapInt32HostToBig(peerEntity.address);
    char s[INET6_ADDRSTRLEN];
    NSString *trustedPeerHost = [NSString stringWithFormat:@"%s:%d", inet_ntop(AF_INET, &ipAddress, s, sizeof(s)), peerEntity.port];
    if ([[self.peerManager trustedPeerHost] isEqualToString:trustedPeerHost]) {
        [self.peerManager removeTrustedPeerHost];
    } else {
        [self.peerManager setTrustedPeerHost:trustedPeerHost];
        if (self.peerManager.connected) {
            [self.peerManager disconnect:DSDisconnectReason_TrustedPeerSet];
            [self.peerManager connect];
        }
    }
}

@end
