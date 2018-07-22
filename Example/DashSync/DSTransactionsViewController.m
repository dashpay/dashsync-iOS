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

@property (nonatomic, strong) NSArray *transactions;
@property (nonatomic, assign) BOOL moreTx;
@property (nonatomic, strong) NSMutableDictionary *txDates;
@property (nonatomic, strong) id backgroundObserver, balanceObserver, txStatusObserver;
@property (nonatomic, strong) id syncStartedObserver, syncFinishedObserver, syncFailedObserver;

@end

@implementation DSTransactionsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.txDates = [NSMutableDictionary dictionary];
    self.moreTx = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    DSAuthenticationManager * authenticationManager = [DSAuthenticationManager sharedInstance];
    
    if (! authenticationManager.didAuthenticate) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.transactions = self.chainPeerManager.chain.allTransactions;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        });
    }
    else [self unlock:nil];
    
    if (! self.backgroundObserver) {
        self.backgroundObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil queue:nil usingBlock:^(NSNotification *note) {
                                                              self.moreTx = YES;
                                                              self.transactions = self.chainPeerManager.chain.allTransactions;
                                                              [self.tableView reloadData];
                                                              self.navigationItem.titleView = self.logo;
                                                              self.navigationItem.rightBarButtonItem = self.lock;
                                                          }];
    }
    
    if (! self.balanceObserver) {
        self.balanceObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSWalletBalanceChangedNotification object:nil
                                                           queue:nil usingBlock:^(NSNotification *note) {
                                                               DSTransaction *tx = self.transactions.firstObject;
                                                               
                                                               self.transactions = self.chainPeerManager.chain.allTransactions;
                                                               
                                                               if (! [self.navigationItem.title isEqual:NSLocalizedString(@"Syncing:", nil)]) {
                                                                   if (! authenticationManager.didAuthenticate) self.navigationItem.titleView = self.logo;
                                                                   else [self updateTitleView];
                                                               }
                                                               
                                                               if (self.transactions.firstObject != tx) {
                                                                   [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                                                                                 withRowAnimation:UITableViewRowAnimationAutomatic];
                                                               }
                                                               else [self.tableView reloadData];
                                                           }];
    }
    
    if (! self.txStatusObserver) {
        self.txStatusObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerTxStatusNotification object:nil
                                                           queue:nil usingBlock:^(NSNotification *note) {
                                                               self.transactions = self.chainPeerManager.chain.allTransactions;
                                                               [self.tableView reloadData];
                                                           }];
    }
    
    if (! self.syncStartedObserver) {
        self.syncStartedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainPeerManagerSyncStartedNotification object:nil
                                                           queue:nil usingBlock:^(NSNotification *note) {
                                                               if ([self.chainPeerManager.chain
                                                                    timestampForBlockHeight:self.chainPeerManager.chain.lastBlockHeight] + WEEK_TIME_INTERVAL <
                                                                   [NSDate timeIntervalSinceReferenceDate] &&
                                                                   self.chainPeerManager.chain.earliestWalletCreationTime + DAY_TIME_INTERVAL < [NSDate timeIntervalSinceReferenceDate]) {
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
    
    NSMutableAttributedString * attributedDashString = [[manager attributedStringForDashAmount:self.chainPeerManager.chain.balance withTintColor:[UIColor whiteColor]] mutableCopy];
    NSString * titleString = [NSString stringWithFormat:@" (%@)",
                              [manager localCurrencyStringForDashAmount:self.chainPeerManager.chain.balance]];
    [attributedDashString appendAttributedString:[[NSAttributedString alloc] initWithString:titleString attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}]];
    titleLabel.attributedText = attributedDashString;
    return titleLabel;
}

-(void)updateTitleView {
    if (self.navigationItem.titleView && [self.navigationItem.titleView isKindOfClass:[UILabel class]]) {
        DSPriceManager *manager = [DSPriceManager sharedInstance];
        NSMutableAttributedString * attributedDashString = [[manager attributedStringForDashAmount:self.chainPeerManager.chain.balance withTintColor:[UIColor whiteColor]] mutableCopy];
        NSString * titleString = [NSString stringWithFormat:@" (%@)",
                                  [manager localCurrencyStringForDashAmount:self.chainPeerManager.chain.balance]];
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
        //BUG: XXX this isn't triggered from start/recover new wallet
        if (self.backgroundObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserver];
        self.backgroundObserver = nil;
        if (self.balanceObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
        self.balanceObserver = nil;
        if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
        self.txStatusObserver = nil;
        if (self.syncStartedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncStartedObserver];
        self.syncStartedObserver = nil;
        if (self.syncFinishedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFinishedObserver];
        self.syncFinishedObserver = nil;
        if (self.syncFailedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFailedObserver];
        self.syncFailedObserver = nil;
        
        //self.buyController = nil;
    }
    
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    if (self.backgroundObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserver];
    if (self.balanceObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
    if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
    if (self.syncStartedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncStartedObserver];
    if (self.syncFinishedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFinishedObserver];
    if (self.syncFailedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFailedObserver];
}

- (uint32_t)blockHeight
{
    static uint32_t height = 0;
    uint32_t h = self.chainPeerManager.chain.lastBlockHeight;
    
    if (h > height) height = h;
    return height;
}

- (void)setTransactions:(NSArray *)transactions
{
    uint32_t height = self.blockHeight;
    
    DSAuthenticationManager *authenticationManager = [DSAuthenticationManager sharedInstance];
    
    if (!authenticationManager.didAuthenticate &&
        [self.navigationItem.title isEqual:NSLocalizedString(@"Syncing:", nil)]) {
        _transactions = @[];
        if (transactions.count > 0) self.moreTx = YES;
    }
    else {
        if (transactions.count <= 5) self.moreTx = NO;
        _transactions = (self.moreTx) ? [transactions subarrayWithRange:NSMakeRange(0, 5)] : [transactions copy];
        
        if (!authenticationManager.didAuthenticate) {
            for (DSTransaction *tx in _transactions) {
                if (tx.blockHeight == TX_UNCONFIRMED ||
                    (tx.blockHeight > height - 5 && tx.blockHeight <= height)) continue;
                _transactions = [_transactions subarrayWithRange:NSMakeRange(0, [_transactions indexOfObject:tx])];
                self.moreTx = YES;
                break;
            }
        }
    }
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
    NSTimeInterval now = [self.chainPeerManager.chain timestampForBlockHeight:TX_UNCONFIRMED];
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

- (IBAction)unlock:(id)sender
{
    DSAuthenticationManager *authenticationManager = [DSAuthenticationManager sharedInstance];
    
    if (!authenticationManager.didAuthenticate) {
        [authenticationManager authenticateWithPrompt:nil andTouchId:YES alertIfLockout:YES completion:^(BOOL authenticated, BOOL cancelled) {
            if (authenticated) {
                
                [self updateTitleView];
                [self.navigationItem setRightBarButtonItem:nil animated:(sender) ? YES : NO];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    self.transactions = self.chainPeerManager.chain.allTransactions;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (sender && self.transactions.count > 0) {
                            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
                        else [self.tableView reloadData];
                    });
                });
            }
        }];
    }
}

//- (IBAction)showTx:(id)sender
//{
//    DSTransactionDetailViewController *detailController = [self.storyboard instantiateViewControllerWithIdentifier:@"TxDetailViewController"];
//    detailController.transaction = sender;
//    detailController.txDateString = [self dateForTx:sender];
//    [self.navigationController pushViewController:detailController animated:YES];
//}

- (IBAction)moreHistory:(id)sender
{
    DSAuthenticationManager *authenticationManager = [DSAuthenticationManager sharedInstance];
    NSUInteger txCount = self.transactions.count;
    
    if (! authenticationManager.didAuthenticate) {
        [self unlock:sender];
        return;
    }
    
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:txCount inSection:0]]
                          withRowAnimation:UITableViewRowAnimationFade];
    self.moreTx = NO;
    self.transactions = self.chainPeerManager.chain.allTransactions;
    
    NSMutableArray *transactions = [NSMutableArray arrayWithCapacity:self.transactions.count];
    
    while (txCount == 0 || txCount < self.transactions.count) {
        [transactions addObject:[NSIndexPath indexPathForRow:txCount++ inSection:0]];
    }
    
    [self.tableView insertRowsAtIndexPaths:transactions withRowAnimation:UITableViewRowAnimationTop];
    [self.tableView endUpdates];
}

//- (void)showBuyAlert
//{
//    // grab a blurred image for the background
//    UIGraphicsBeginImageContext(self.navigationController.view.bounds.size);
//    [self.navigationController.view drawViewHierarchyInRect:self.navigationController.view.bounds
//                                         afterScreenUpdates:NO];
//    UIImage *bgImg = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    UIImage *blurredBgImg = [bgImg blurWithRadius:3];
//
//    // display the popup
//    __weak BREventConfirmView *view =
//        [[NSBundle mainBundle] loadNibNamed:@"BREventConfirmView" owner:nil options:nil][0];
//    view.titleLabel.text = NSLocalizedString(@"Buy dash in dashwallet!", nil);
//    view.descriptionLabel.text =
//        NSLocalizedString(@"You can now buy dash in\ndashwallet with cash or\nbank transfer.", nil);
//    [view.okBtn setTitle:NSLocalizedString(@"Try It!", nil) forState:UIControlStateNormal];
//
//    view.image = blurredBgImg;
//    view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
//    view.frame = self.navigationController.view.bounds;
//    view.alpha = 0;
//    [self.navigationController.view addSubview:view];
//
//    [UIView animateWithDuration:.5 animations:^{
//        view.alpha = 1;
//    }];
//
//    view.completionHandler = ^(BOOL didApprove) {
//        if (didApprove) [self showBuy];
//
//        [UIView animateWithDuration:.5 animations:^{
//            view.alpha = 0;
//        } completion:^(BOOL finished) {
//            [view removeFromSuperview];
//        }];
//    };
//}

// MARK: - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            if (self.transactions.count == 0) return 1;
            return (self.moreTx) ? self.transactions.count + 1 : self.transactions.count;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *noTxIdent = @"NoTxCellIdentifier", *transactionIdent = @"TransactionCellIdentifier", *actionIdent = @"ActionCellIdentifier";
    UIImageView * shapeshiftImageView;
    DSPriceManager *priceManager = [DSPriceManager sharedInstance];
    DSAuthenticationManager * authenticationManager = [DSAuthenticationManager sharedInstance];
    UITableViewCell * rCell = nil;
    switch (indexPath.section) {
        case 0:
            if (self.moreTx && indexPath.row >= self.transactions.count) {
                rCell = [tableView dequeueReusableCellWithIdentifier:actionIdent];
                rCell.textLabel.text = (indexPath.row > 0) ? NSLocalizedString(@"more...", nil) : NSLocalizedString(@"transaction history", nil);
                rCell.imageView.image = nil;
            }
            else if (self.transactions.count > 0) {
                DSTransactionTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:transactionIdent];
                
                DSTransaction *tx = self.transactions[indexPath.row];
                DSAccount * account = [self.chainPeerManager.chain accountContainingTransaction:tx];
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
                shapeshiftImageView.hidden = !tx.associatedShapeshift;
                
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
                rCell = cell;
            }
            else rCell = [tableView dequeueReusableCellWithIdentifier:noTxIdent];
            
            break;
    }
    
    [self setBackgroundForCell:rCell tableView:tableView indexPath:indexPath];
    NSAssert(rCell, @"A cell must be returned");
    return rCell;
}

// MARK: - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0: return (self.moreTx && indexPath.row >= self.transactions.count) ? 44.0 : TRANSACTION_CELL_HEIGHT;
    }
    
    return 44.0;
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0: // transaction
            if (self.moreTx && indexPath.row >= self.transactions.count) { // more...
                [self performSelector:@selector(moreHistory:) withObject:tableView afterDelay:0.0];
            }
            //else if (self.transactions.count > 0) [self performSegueWithIdentifier:@"TransactionDetailSegue" sender:self.transactions[indexPath.row]];
            
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            break;
            
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    UITableViewCell * cell = (UITableViewCell*)sender;
    NSInteger index = [self.tableView indexPathForCell:cell].row;
    if ([segue.identifier isEqualToString:@"TransactionDetailSegue"]) {
        DSTransactionDetailViewController * transactionDetailViewController = (DSTransactionDetailViewController *)segue.destinationViewController;
        DSTransaction * transaction = self.transactions[index];
        transactionDetailViewController.transaction = transaction;
    }
}

@end
