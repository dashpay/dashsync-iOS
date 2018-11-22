//
//  DSTransactionsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/8/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSTransactionsViewController.h"
#import "DSTransactionDetailViewController.h"
#import "DSTransactionTableViewCell.h"
#import <DashSync/DashSync.h>
#import <WebKit/WebKit.h>

#define TRANSACTION_CELL_HEIGHT 75

static NSString *dateFormat(NSString *template)
{
    NSString *format = [NSDateFormatter dateFormatFromTemplate:template options:0 locale:[NSLocale currentLocale]];
    
    format = [format stringByReplacingOccurrencesOfString:@", " withString:@" "];
    format = [format stringByReplacingOccurrencesOfString:@" a" withString:@"a"];
    format = [format stringByReplacingOccurrencesOfString:@"hh" withString:@"h"];
    format = [format stringByReplacingOccurrencesOfString:@" ha" withString:@"@ha"];
    format = [format stringByReplacingOccurrencesOfString:@"HH" withString:@"H"];
    format = [format stringByReplacingOccurrencesOfString:@"H '" withString:@"H'"];
    format = [format stringByReplacingOccurrencesOfString:@"H " withString:@"H'h' "];
    format = [format stringByReplacingOccurrencesOfString:@"H" withString:@"H'h'"
                                                  options:NSBackwardsSearch|NSAnchoredSearch range:NSMakeRange(0, format.length)];
    return format;
}

@interface DSTransactionsViewController ()

@property (nonatomic, strong) IBOutlet UIView *logo;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *lock;

@property (nonatomic, strong) NSMutableDictionary *transactions;
@property (nonatomic, strong) NSMutableDictionary *txDates;
@property (nonatomic, strong) id txStatusObserver;
@property (nonatomic, strong) id syncStartedObserver, syncFinishedObserver, syncFailedObserver;

@property (nonatomic,strong) NSFetchedResultsController * fetchedResultsController;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSTransactionsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.transactions = [NSMutableDictionary dictionary];
    
    self.txDates = [NSMutableDictionary dictionary];
    //self.moreTx = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    
    DSAuthenticationManager * authenticationManager = [DSAuthenticationManager sharedInstance];
    
    if (! self.txStatusObserver) {
        self.txStatusObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerTxStatusNotification object:nil
                                                           queue:nil usingBlock:^(NSNotification *note) {
                                                               [self.tableView reloadData];
                                                           }];
    }
    
    if (! self.syncStartedObserver) {
        self.syncStartedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerSyncStartedNotification object:nil
                                                           queue:nil usingBlock:^(NSNotification *note) {
                                                               if ([self.chainManager.chain
                                                                    timestampForBlockHeight:self.chainManager.chain.lastBlockHeight] + WEEK_TIME_INTERVAL <
                                                                   [NSDate timeIntervalSinceReferenceDate] &&
                                                                   self.chainManager.chain.earliestWalletCreationTime + DAY_TIME_INTERVAL < [NSDate timeIntervalSinceReferenceDate]) {
                                                                   self.navigationItem.titleView = nil;
                                                                   self.navigationItem.title = NSLocalizedString(@"Syncing:", nil);
                                                               }
                                                           }];
    }
    
    if (! self.syncFinishedObserver) {
        self.syncFinishedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerSyncFinishedNotification object:nil
                                                           queue:nil usingBlock:^(NSNotification *note) {
                                                               if (! authenticationManager.didAuthenticate) self.navigationItem.titleView = self.logo;
                                                               else [self updateTitleView];
                                                           }];
    }
    
    if (! self.syncFailedObserver) {
        self.syncFailedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerSyncFailedNotification object:nil
                                                           queue:nil usingBlock:^(NSNotification *note) {
                                                               if (! authenticationManager.didAuthenticate) self.navigationItem.titleView = self.logo;
                                                               [self updateTitleView];
                                                           }];
    }
}


-(UILabel*)titleLabel {
    DSPriceManager *manager = [DSPriceManager sharedInstance];
    UILabel * titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 100)];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [titleLabel setBackgroundColor:[UIColor clearColor]];
    
    NSMutableAttributedString * attributedDashString = [[manager attributedStringForDashAmount:self.chainManager.chain.balance withTintColor:[UIColor whiteColor]] mutableCopy];
    NSString * titleString = [NSString stringWithFormat:@" (%@)",
                              [manager localCurrencyStringForDashAmount:self.chainManager.chain.balance]];
    [attributedDashString appendAttributedString:[[NSAttributedString alloc] initWithString:titleString attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}]];
    titleLabel.attributedText = attributedDashString;
    return titleLabel;
}

-(void)updateTitleView {
    if (self.navigationItem.titleView && [self.navigationItem.titleView isKindOfClass:[UILabel class]]) {
        DSPriceManager *manager = [DSPriceManager sharedInstance];
        NSMutableAttributedString * attributedDashString = [[manager attributedStringForDashAmount:self.chainManager.chain.balance withTintColor:[UIColor whiteColor]] mutableCopy];
        NSString * titleString = [NSString stringWithFormat:@" (%@)",
                                  [manager localCurrencyStringForDashAmount:self.chainManager.chain.balance]];
        [attributedDashString appendAttributedString:[[NSAttributedString alloc] initWithString:titleString attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}]];
        ((UILabel*)self.navigationItem.titleView).attributedText = attributedDashString;
        [((UILabel*)self.navigationItem.titleView) sizeToFit];
    } else {
        self.navigationItem.titleView = [self titleLabel];
    }
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.isMovingFromParentViewController || self.navigationController.isBeingDismissed) {
        if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
        self.txStatusObserver = nil;
        if (self.syncStartedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncStartedObserver];
        self.syncStartedObserver = nil;
        if (self.syncFinishedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFinishedObserver];
        self.syncFinishedObserver = nil;
        if (self.syncFailedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFailedObserver];
        self.syncFailedObserver = nil;
    }
    
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
    if (self.syncStartedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncStartedObserver];
    if (self.syncFinishedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFinishedObserver];
    if (self.syncFailedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFailedObserver];
}

- (uint32_t)blockHeight
{
    static uint32_t height = 0;
    uint32_t h = self.chainManager.chain.lastBlockHeight;
    
    if (h > height) height = h;
    return height;
}

#pragma mark - Automation KVO

-(NSManagedObjectContext*)managedObjectContext {
    if (!_managedObjectContext) self.managedObjectContext = [NSManagedObject context];
    return _managedObjectContext;
}

-(NSPredicate*)searchPredicate {
    return [NSPredicate predicateWithFormat:@"transactionHash.chain = %@",self.chainManager.chain.chainEntity];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView beginUpdates];
    });
    
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)changeType
      newIndexPath:(NSIndexPath *)newIndexPath {
    dispatch_async(dispatch_get_main_queue(), ^{
    switch (changeType) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
        case NSFetchedResultsChangeMove:
            [self.tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
            break;
        default:
            break;
    }
    });
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    dispatch_async(dispatch_get_main_queue(), ^{
    [self.tableView endUpdates];
    });
}

- (void)setBackgroundForCell:(UITableViewCell *)cell tableView:(UITableView *)tableView indexPath:(NSIndexPath *)path
{
    [cell viewWithTag:100].hidden = (path.row > 0);
    [cell viewWithTag:101].hidden = (path.row + 1 < [self tableView:tableView numberOfRowsInSection:path.section]);
}

- (NSString *)dateForTx:(DSTransaction *)tx
{
    static NSDateFormatter *monthDayHourFormatter = nil;
    static NSDateFormatter *yearMonthDayHourFormatter = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{ // BUG: need to watch for NSCurrentLocaleDidChangeNotification
        monthDayHourFormatter = [NSDateFormatter new];
        monthDayHourFormatter.dateFormat = dateFormat(@"Mdjmma");
        yearMonthDayHourFormatter = [NSDateFormatter new];
        yearMonthDayHourFormatter.dateFormat = dateFormat(@"yyMdja");
    });
    
    NSString *date = self.txDates[uint256_obj(tx.txHash)];
    NSTimeInterval now = [self.chainManager.chain timestampForBlockHeight:TX_UNCONFIRMED];
    NSTimeInterval year = [NSDate timeIntervalSinceReferenceDate] - 364*24*60*60;
    
    if (date) return date;
    
    NSTimeInterval txTime = (tx.timestamp > 1) ? tx.timestamp : now;
    NSDateFormatter *desiredFormatter = (txTime > year) ? monthDayHourFormatter : yearMonthDayHourFormatter;
    
    date = [desiredFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:txTime]];
    if (tx.blockHeight != TX_UNCONFIRMED) self.txDates[uint256_obj(tx.txHash)] = date;
    return date;
}

// MARK: - IBAction

- (IBAction)done:(id)sender
{
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self.fetchedResultsController fetchedObjects] count];
}

-(void)configureCell:(DSTransactionTableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath {
    DSPriceManager *priceManager = [DSPriceManager sharedInstance];
    DSAuthenticationManager * authenticationManager = [DSAuthenticationManager sharedInstance];
    DSTransactionEntity * transactionEntity = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSLog(@"%u",transactionEntity.transactionHash.blockHeight);
    DSTransaction *tx = [transactionEntity transactionForChain:self.chainManager.chain];
    [self.transactions setObject:tx forKey:uint256_data(tx.txHash)];
    DSAccount * account = [self.chainManager.chain accountContainingTransaction:tx];
    uint64_t received = [account amountReceivedFromTransaction:tx],
    sent = [account amountSentByTransaction:tx],
    balance = [account balanceAfterTransaction:tx];
    uint32_t blockHeight = self.blockHeight;
    uint32_t confirms = (tx.blockHeight > blockHeight) ? 0 : (blockHeight - tx.blockHeight) + 1;
    
    cell.amountLabel.textColor = [UIColor darkTextColor];
    cell.directionLabel.hidden = YES;
    cell.confirmationsLabel.hidden = NO;
    cell.confirmationsLabel.backgroundColor = [UIColor lightGrayColor];
    cell.dateLabel.text = [self dateForTx:tx];
    cell.remainingAmountLabel.attributedText = (authenticationManager.didAuthenticate) ? [priceManager attributedStringForDashAmount:balance withTintColor:cell.remainingAmountLabel.textColor dashSymbolSize:CGSizeMake(9, 9)] : nil;
    cell.remainingFiatAmountLabel.text = (authenticationManager.didAuthenticate) ? [NSString stringWithFormat:@"(%@)", [priceManager localCurrencyStringForDashAmount:balance]] : nil;
    cell.shapeshiftImageView.hidden = !tx.associatedShapeshift;
    
    if (confirms == 0 && ! [account transactionIsValid:tx]) {
        cell.confirmationsLabel.text = NSLocalizedString(@"INVALID", nil);
        cell.confirmationsLabel.backgroundColor = [UIColor redColor];
        cell.remainingAmountLabel.text = cell.remainingFiatAmountLabel.text = nil;
    }
    else if (confirms == 0 && [account transactionIsPending:tx]) {
        cell.confirmationsLabel.text = NSLocalizedString(@"pending", nil);
        cell.confirmationsLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.2];
        cell.amountLabel.textColor = [UIColor grayColor];
        cell.remainingAmountLabel.text = cell.remainingFiatAmountLabel.text = nil;
    }
    else if (confirms == 0 && ! [account transactionIsVerified:tx]) {
        cell.confirmationsLabel.text = NSLocalizedString(@"unverified", nil);
    }
    else if (confirms < 6) {
        if (confirms == 0) cell.confirmationsLabel.text = NSLocalizedString(@"0 confirmations", nil);
        else if (confirms == 1) cell.confirmationsLabel.text = NSLocalizedString(@"1 confirmation", nil);
        else cell.confirmationsLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d confirmations", nil),
                                             (int)confirms];
    }
    else {
        cell.confirmationsLabel.text = nil;
        cell.confirmationsLabel.hidden = YES;
        cell.directionLabel.hidden = NO;
    }
    
    if (sent > 0 && received == sent) {
        cell.amountLabel.attributedText = [priceManager attributedStringForDashAmount:sent];
        cell.fiatAmountLabel.text = [NSString stringWithFormat:@"(%@)",
                                     [priceManager localCurrencyStringForDashAmount:sent]];
        cell.directionLabel.text = NSLocalizedString(@"moved", nil);
        cell.directionLabel.textColor = [UIColor blackColor];
    }
    else if (sent > 0) {
        cell.amountLabel.attributedText = [priceManager attributedStringForDashAmount:received - sent];
        cell.fiatAmountLabel.text = [NSString stringWithFormat:@"(%@)",
                                     [priceManager localCurrencyStringForDashAmount:received - sent]];
        cell.directionLabel.text = NSLocalizedString(@"sent", nil);
        cell.directionLabel.textColor = [UIColor colorWithRed:1.0 green:0.33 blue:0.33 alpha:1.0];
    }
    else {
        cell.amountLabel.attributedText = [priceManager attributedStringForDashAmount:received];
        cell.fiatAmountLabel.text = [NSString stringWithFormat:@"(%@)",
                                     [priceManager localCurrencyStringForDashAmount:received]];
        cell.directionLabel.text = NSLocalizedString(@"received", nil);
        cell.directionLabel.textColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.0 alpha:1.0];
    }
    
    if (! cell.confirmationsLabel.hidden) {
        cell.confirmationsLabel.layer.cornerRadius = 3.0;
        cell.confirmationsLabel.text = [cell.confirmationsLabel.text stringByAppendingString:@"  "];
    }
    else {
        cell.directionLabel.layer.cornerRadius = 3.0;
        cell.directionLabel.layer.borderWidth = 0.5;
        cell.directionLabel.text = [cell.directionLabel.text stringByAppendingString:@"  "];
        cell.directionLabel.layer.borderColor = cell.directionLabel.textColor.CGColor;
        cell.directionLabel.highlightedTextColor = cell.directionLabel.textColor;
    }
    
    [self setBackgroundForCell:cell tableView:self.tableView indexPath:indexPath];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *transactionIdent = @"TransactionCellIdentifier";
    
    DSTransactionTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:transactionIdent];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

// MARK: - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return TRANSACTION_CELL_HEIGHT;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *sectionTitle = [self tableView:tableView titleForHeaderInSection:section];
    
    if (sectionTitle.length == 0) return 22.0;
    
    CGRect r = [sectionTitle boundingRectWithSize:CGSizeMake(self.view.frame.size.width - 20.0, CGFLOAT_MAX)
                                          options:NSStringDrawingUsesLineFragmentOrigin
                                       attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13]} context:nil];
    
    return r.size.height + 22.0 + 10.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                         [self tableView:tableView heightForHeaderInSection:section])];
    UILabel *l = [UILabel new];
    CGRect r = CGRectMake(15.0, 0.0, v.frame.size.width - 20.0, v.frame.size.height - 22.0);
    
    l.text = [self tableView:tableView titleForHeaderInSection:section];
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont systemFontOfSize:13];
    l.textColor = [UIColor grayColor];
    l.shadowColor = [UIColor whiteColor];
    l.shadowOffset = CGSizeMake(0.0, 1.0);
    l.numberOfLines = 0;
    r.size.width = [l sizeThatFits:r.size].width;
    r.origin.x = (self.view.frame.size.width - r.size.width)/2;
    if (r.origin.x < 15.0) r.origin.x = 15.0;
    l.frame = r;
    v.backgroundColor = [UIColor clearColor];
    [v addSubview:l];
    
    return v;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return (section + 1 == [self numberOfSectionsInTableView:tableView]) ? 22.0 : 0.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                         [self tableView:tableView heightForFooterInSection:section])];
    v.backgroundColor = [UIColor clearColor];
    return v;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    UITableViewCell * cell = (UITableViewCell*)sender;
    if ([segue.identifier isEqualToString:@"TransactionDetailSegue"]) {
        DSTransactionDetailViewController * transactionDetailViewController = (DSTransactionDetailViewController *)segue.destinationViewController;
        DSTransactionEntity *transactionEntity = [self.fetchedResultsController objectAtIndexPath:[self.tableView indexPathForCell:cell]];
        DSTransaction * transaction = self.transactions[transactionEntity.transactionHash.txHash];
        transactionDetailViewController.transaction = transaction;
        transactionDetailViewController.txDateString = [self dateForTx:transaction];
    }
}

@end
