//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSContactBaseTransactionsTableViewController.h"

#import <DashSync/DashSync.h>

#import "DSContactTransactionTableViewCell.h"
#import "DSTransactionDetailViewController.h"
#import "DSTransactionsViewController.h"

NSString *const CELL_ID = @"DSContactTransactionTableViewCell";

NS_ASSUME_NONNULL_BEGIN

@interface DSContactBaseTransactionsTableViewController ()

@property (nonatomic, strong) NSMutableDictionary *txDates;

@end

@implementation DSContactBaseTransactionsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.txDates = [NSMutableDictionary dictionary];

    UINib *nib = [UINib nibWithNibName:CELL_ID bundle:nil];
    NSParameterAssert(nib);
    [self.tableView registerNib:nib forCellReuseIdentifier:CELL_ID];

    [[NSNotificationCenter defaultCenter] addObserver:self.tableView
                                             selector:@selector(reloadData)
                                                 name:DSTransactionManagerTransactionStatusDidChangeNotification
                                               object:nil];
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSContactTransactionTableViewCell *cell =
        (DSContactTransactionTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CELL_ID
                                                                             forIndexPath:indexPath];

    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(DSContactTransactionTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    [self configureCell:cell atIndexPath:indexPath direction:self.direction];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    DSTxOutputEntity *transactionOutput = [self.fetchedResultsController objectAtIndexPath:indexPath];
    DSTransactionEntity *transactionEntity = transactionOutput.transaction;

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    DSTransactionDetailViewController *controller = [storyboard instantiateViewControllerWithIdentifier:@"TransactionDetailViewController"];
    DSTransaction *transaction = [self.chainManager.chain transactionForHash:transactionEntity.transactionHash.txHash.UInt256];
    if (!transaction) {
        transaction = [transactionEntity transactionForChain:self.chainManager.chain];
    }
    controller.transaction = transaction;
    controller.txDateString = [self dateForTx:transactionEntity];
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Private

- (void)configureCell:(DSContactTransactionTableViewCell *)cell
          atIndexPath:(NSIndexPath *)indexPath
            direction:(DSContactTransactionDirection)direction {
    DSTxOutputEntity *transactionOutput = [self.fetchedResultsController objectAtIndexPath:indexPath];
    DSTransactionEntity *tx = transactionOutput.transaction;

    cell.transactionLabel.text = tx.transactionHash.txHash.hexString;
    cell.dateLabel.text = [self dateForTx:tx];

    DSPriceManager *priceManager = [DSPriceManager sharedInstance];
    int64_t amount = transactionOutput.value;
    cell.amountLabel.attributedText = [priceManager attributedStringForDashAmount:amount];

    uint32_t blockHeight = self.blockHeight;
    uint32_t confirms = (tx.transactionHash.blockHeight > blockHeight) ? 0 : (blockHeight - tx.transactionHash.blockHeight) + 1;

    // Simplified tx state handling

    if (confirms < 6) {
        cell.confirmationsLabel.hidden = NO;
        cell.directionLabel.hidden = YES;

        if (confirms == 0)
            cell.confirmationsLabel.text = NSLocalizedString(@"0 confirmations", nil);
        else if (confirms == 1)
            cell.confirmationsLabel.text = NSLocalizedString(@"1 confirmation", nil);
        else
            cell.confirmationsLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d confirmations", nil),
                                                     (int)confirms];
    } else {
        cell.confirmationsLabel.hidden = YES;
        cell.directionLabel.hidden = NO;

        if (direction == DSContactTransactionDirectionReceived) {
            cell.directionLabel.text = NSLocalizedString(@"received", nil);
            cell.directionLabel.textColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.0 alpha:1.0];
        } else {
            cell.directionLabel.text = NSLocalizedString(@"sent", nil);
            cell.directionLabel.textColor = [UIColor colorWithRed:1.0 green:0.33 blue:0.33 alpha:1.0];
        }
    }

    if (!cell.confirmationsLabel.hidden) {
        cell.confirmationsLabel.layer.cornerRadius = 3.0;
        cell.confirmationsLabel.text = [cell.confirmationsLabel.text stringByAppendingString:@"  "];
    } else {
        cell.directionLabel.layer.cornerRadius = 3.0;
        cell.directionLabel.layer.borderWidth = 0.5;
        cell.directionLabel.text = [cell.directionLabel.text stringByAppendingString:@"  "];
        cell.directionLabel.layer.borderColor = cell.directionLabel.textColor.CGColor;
        cell.directionLabel.highlightedTextColor = cell.directionLabel.textColor;
    }
}

- (uint32_t)blockHeight {
    static uint32_t height = 0;
    uint32_t h = self.chainManager.chain.lastSyncBlockHeight;

    if (h > height) height = h;
    return height;
}

- (NSString *)dateForTx:(DSTransactionEntity *)tx {
    static NSDateFormatter *monthDayHourFormatter = nil;
    static NSDateFormatter *yearMonthDayHourFormatter = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{ // BUG: need to watch for NSCurrentLocaleDidChangeNotification
        monthDayHourFormatter = [NSDateFormatter new];
        monthDayHourFormatter.dateFormat = dateFormat(@"Mdjmma");
        yearMonthDayHourFormatter = [NSDateFormatter new];
        yearMonthDayHourFormatter.dateFormat = dateFormat(@"yyMdja");
    });

    NSString *date = self.txDates[tx.transactionHash.txHash];
    NSTimeInterval now = [self.chainManager.chain timestampForBlockHeight:TX_UNCONFIRMED];
    NSTimeInterval year = [NSDate timeIntervalSince1970] - 364 * 24 * 60 * 60;

    if (date) return date;

    NSTimeInterval txTime = (tx.transactionHash.timestamp > 1) ? tx.transactionHash.timestamp : now;
    NSDateFormatter *desiredFormatter = (txTime > year) ? monthDayHourFormatter : yearMonthDayHourFormatter;

    date = [desiredFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:txTime]];
    if (tx.transactionHash.blockHeight != TX_UNCONFIRMED) self.txDates[tx.transactionHash.txHash] = date;
    return date;
}

@end

NS_ASSUME_NONNULL_END
