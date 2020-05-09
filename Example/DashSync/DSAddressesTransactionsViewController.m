//
//  DSAddressesTransactionsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/22/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSAddressesTransactionsViewController.h"
#import <DashSync/DashSync.h>
#import "DSTransactionTableViewCell.h"
#import "BRBubbleView.h"
#import "BRCopyLabel.h"

@interface DSAddressesTransactionsViewController ()

@property (nonatomic,strong) NSFetchedResultsController * fetchedResultsController;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;
@property (strong, nonatomic) IBOutlet BRCopyLabel *privateKeyLabel;

@end

@implementation DSAddressesTransactionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.wallet seedWithPrompt:@"" forAmount:0 completion:^(NSData * _Nullable seed, BOOL cancelled) {
        DSKey * key = [self.wallet privateKeyForAddress:self.address fromSeed:seed];
        if (key) {
            self.privateKeyLabel.text = [key serializedPrivateKeyForChain:self.wallet.chain];
        }
    }];
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
    return [NSPredicate predicateWithFormat:@"(ANY outputs.address == %@) || (ANY inputs.localAddress.address = %@)",self.address,self.address];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DSTransactionEntity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:12];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *timeDescriptor = [[NSSortDescriptor alloc] initWithKey:@"transactionHash.timestamp" ascending:NO];
    NSArray *sortDescriptors = @[timeDescriptor];
    
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
    DSTransactionTableViewCell *cell = (DSTransactionTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"TransactionCellIdentifier" forIndexPath:indexPath];
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(IBAction)copyTransactionHash:(id)sender {
    for (UITableViewCell * cell in self.tableView.visibleCells) {
        if ([sender isDescendantOfView:cell]) {
            NSIndexPath * indexPath = [self.tableView indexPathForCell:cell];
            DSTransactionEntity *transactionEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = transactionEntity.transactionHash.txHash.reverse.hexString;
            [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"copied", nil)
                                                        center:CGPointMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0 - 130.0)] popIn]
                                   popOutAfterDelay:2.0]];
            break;
        }
    }
    
}



-(void)configureCell:(DSTransactionTableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    DSTransactionEntity *transactionEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
    BOOL outwards = FALSE;
    for (DSTxOutputEntity * output in transactionEntity.outputs) {
        if ([output.address isEqualToString:self.address]) {
            outwards = TRUE;
            cell.amountLabel.text = [[DSPriceManager sharedInstance] stringForDashAmount:output.value];
            break;
        }
    }
    if (outwards) {
        cell.directionLabel.text = @"Received";
        cell.directionLabel.textColor = [UIColor greenColor];
    } else {
        cell.directionLabel.text = @"Sent";
        cell.directionLabel.textColor = [UIColor redColor];
        for (DSTxInputEntity * input in transactionEntity.inputs) {
            if ([input.localAddress.address isEqualToString:self.address]) {
                cell.amountLabel.text = [[DSPriceManager sharedInstance] stringForDashAmount:input.prevOutput.value];
                break;
            }
        }
    }
    static NSDateFormatter * dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    });
    NSDate * date = [NSDate dateWithTimeIntervalSince1970:transactionEntity.transactionHash.timestamp];
    cell.dateLabel.text = [dateFormatter stringFromDate:date];
    cell.transactionLabel.text = transactionEntity.transactionHash.txHash.reverse.hexString;
}

@end
