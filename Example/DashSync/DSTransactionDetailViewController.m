//
//  DSTransactionDetailViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/8/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSTransactionDetailViewController.h"
#import <DashSync/DashSync.h>
#import "BRCopyLabel.h"
#import "DSTransactionAmountTableViewCell.h"
#import "DSTransactionDetailTableViewCell.h"
#import "DSTransactionIdentifierTableViewCell.h"
#import "DSTransactionStatusTableViewCell.h"

#define TRANSACTION_CELL_HEIGHT 75

@interface DSTransactionDetailViewController ()

@property (nonatomic, strong) NSArray *inputAddresses, *outputText, *outputDetail, *outputAmount, *outputIsBitcoin;
@property (nonatomic, assign) int64_t sent, received;
@property (nonatomic, strong) id txStatusObserver;

@end

@implementation DSTransactionDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (! self.txStatusObserver) {
        self.txStatusObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil
                                                           queue:nil usingBlock:^(NSNotification *note) {
                                                               DSTransaction *tx = [self.transaction.chain
                                                                                    transactionForHash:self.transaction.txHash];
                                                               
                                                               if (tx) self.transaction = tx;
                                                               [self.tableView reloadData];
                                                           }];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
    self.txStatusObserver = nil;
    
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
}

- (void)setTransaction:(DSTransaction *)transaction
{
    DSPriceManager *manager = [DSPriceManager sharedInstance];
    NSMutableArray *mutableInputAddresses = [NSMutableArray array], *text = [NSMutableArray array], *detail = [NSMutableArray array], *amount = [NSMutableArray array], *currencyIsBitcoinInstead = [NSMutableArray array];
    DSAccount * account = transaction.account;
    uint64_t fee = [account feeForTransaction:transaction];
    NSUInteger outputAmountIndex = 0;
    
    _transaction = transaction;
    self.sent = [account amountSentByTransaction:transaction];
    self.received = [account amountReceivedFromTransaction:transaction];
    
    for (NSString *inputAddress in transaction.inputAddresses) {
        if (![mutableInputAddresses containsObject:inputAddress]) {
            [mutableInputAddresses addObject:inputAddress];
        }
    }
    
    for (NSString *address in transaction.outputAddresses) {
        NSData * script = transaction.outputScripts[outputAmountIndex];
        uint64_t amt = [transaction.outputAmounts[outputAmountIndex++] unsignedLongLongValue];
        
        if (address == (id)[NSNull null]) {
            if (self.sent > 0) {
                if ([script UInt8AtOffset:0] == OP_RETURN) {
                    UInt8 length = [script UInt8AtOffset:1];
                    if ([script UInt8AtOffset:2] == OP_SHAPESHIFT) {
                        NSMutableData * data = [NSMutableData data];
                        uint8_t v = BITCOIN_PUBKEY_ADDRESS;
                        [data appendBytes:&v length:1];
                        NSData * addressData = [script subdataWithRange:NSMakeRange(3, length - 1)];
                        
                        [data appendData:addressData];
                        [text addObject:[NSString base58checkWithData:data]];
                        [detail addObject:NSLocalizedString(@"Bitcoin address (shapeshift)", nil)];
                        if (transaction.associatedShapeshift.outputCoinAmount) {
                            [amount addObject:@([manager amountForUnknownCurrencyString:[transaction.associatedShapeshift.outputCoinAmount stringValue]])];
                        } else {
                            [amount addObject:@(UINT64_MAX)];
                        }
                        [currencyIsBitcoinInstead addObject:@TRUE];
                    }
                } else {
                    [currencyIsBitcoinInstead addObject:@FALSE];
                    [text addObject:NSLocalizedString(@"unknown address", nil)];
                    [detail addObject:NSLocalizedString(@"payment output", nil)];
                    [amount addObject:@(-amt)];
                }
                
            }
        }
        else if ([account containsAddress:address]) {
            if (self.sent == 0 || self.received == self.sent) {
                [text addObject:address];
                [detail addObject:NSLocalizedString(@"wallet address", nil)];
                [amount addObject:@(amt)];
                [currencyIsBitcoinInstead addObject:@FALSE];
            }
        }
        else if (self.sent > 0) {
            [text addObject:address];
            [detail addObject:NSLocalizedString(@"payment address", nil)];
            [amount addObject:@(-amt)];
            [currencyIsBitcoinInstead addObject:@FALSE];
        }
    }
    
    if (self.sent > 0 && fee > 0 && fee != UINT64_MAX) {
        [text addObject:@""];
        [detail addObject:NSLocalizedString(@"dash network fee", nil)];
        [amount addObject:@(-fee)];
        [currencyIsBitcoinInstead addObject:@FALSE];
    }
    
    self.inputAddresses = mutableInputAddresses;
    self.outputText = text;
    self.outputDetail = detail;
    self.outputAmount = amount;
    self.outputIsBitcoin = currencyIsBitcoinInstead;
}

- (void)setBackgroundForCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)path
{
    [cell viewWithTag:100].hidden = (path.row > 0);
    [cell viewWithTag:101].hidden = (path.row + 1 < [self tableView:self.tableView numberOfRowsInSection:path.section]);
}

// MARK: - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return ([self.transaction type] == DSTransactionType_Classic)?3:4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    switch (section) {
        case 0: return self.transaction.associatedShapeshift?(([self.transaction.associatedShapeshift.shapeshiftStatus integerValue]| eShapeshiftAddressStatus_Finished)?6:5):4;
        case 1: return (self.sent > 0) ? self.outputText.count : self.inputAddresses.count;
        case 2: return (self.sent > 0) ? self.inputAddresses.count : self.outputText.count;
        case 3: {
            switch ([self.transaction type]) {
                case DSTransactionType_SubscriptionRegistration:
                    return 4;
                    break;
                case DSTransactionType_SubscriptionResetKey:
                    return 3;
                    break;
                case DSTransactionType_SubscriptionTopUp:
                    return 3;
                    break;
                    
                default:
                    return 0;
                    break;
            }
        }
    }
    
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DSPriceManager * walletManager = [DSPriceManager sharedInstance];
    DSChainManager * chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:self.transaction.chain];
    NSUInteger peerCount = chainManager.peerManager.connectedPeerCount;
    NSUInteger relayCount = [chainManager.transactionManager relayCountForTransaction:self.transaction.txHash];
    DSAccount * account = self.transaction.account;
    NSString *s;
    
    NSInteger indexPathRow = indexPath.row;
    
    // Configure the cell...
    switch (indexPath.section) {
        case 0:
            if (!self.transaction.associatedShapeshift) {
                if (indexPathRow > 1) indexPathRow += 2; // no assoc
            } else if (!([self.transaction.associatedShapeshift.shapeshiftStatus integerValue] | eShapeshiftAddressStatus_Finished)) {
                if (indexPathRow > 1) indexPathRow += 1;
            }
            switch (indexPathRow) {
                case 0:
                {
                    DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                    
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"type:", nil);
                    if ([self.transaction isMemberOfClass:[DSBlockchainUserRegistrationTransaction class]]) {
                        cell.statusLabel.text = @"BU Registration Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSBlockchainUserTopupTransaction class]]) {
                        cell.statusLabel.text = @"BU Topup Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSBlockchainUserResetTransaction class]]) {
                        cell.statusLabel.text = @"BU Reset Transaction";
                    } else {
                        cell.statusLabel.text = @"Classical Transaction";
                    }
                    cell.moreInfoLabel.text = nil;
                    return cell;
                    break;
                }
                case 1:
                {
                    DSTransactionIdentifierTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"id:", nil);
                    s = [NSString hexWithData:[NSData dataWithBytes:self.transaction.txHash.u8
                                                             length:sizeof(UInt256)].reverse];
                    cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length/2],
                                                 [s substringFromIndex:s.length/2]];
                    cell.identifierLabel.copyableText = s;
                    return cell;
                }
                case 2:
                {
                    DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"shapeshift bitcoin id:", nil);
                    cell.statusLabel.text = [self.transaction.associatedShapeshift outputTransactionId];
                    cell.moreInfoLabel.text = nil;
                    return cell;
                }
                case 3:
                {
                    DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                    
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"shapeshift status:", nil);
                    cell.statusLabel.text = [self.transaction.associatedShapeshift shapeshiftStatusString];
                    cell.moreInfoLabel.text = nil;
                    return cell;
                }
                case 4:
                {
                    DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"status:", nil);
                    cell.moreInfoLabel.text = nil;
                    
                    if (self.transaction.blockHeight != TX_UNCONFIRMED) {
                        cell.statusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"confirmed in block #%d", nil),
                                                 self.transaction.blockHeight, self.txDateString];
                        cell.moreInfoLabel.text = self.txDateString;
                    }
                    else if (! [account transactionIsValid:self.transaction]) {
                        cell.statusLabel.text = NSLocalizedString(@"double spend", nil);
                    }
                    else if ([account transactionIsPending:self.transaction]) {
                        cell.statusLabel.text = NSLocalizedString(@"pending", nil);
                    }
                    else if (! [account transactionIsVerified:self.transaction]) {
                        cell.statusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"seen by %d of %d peers", nil),
                                                 relayCount, peerCount];
                    }
                    else cell.statusLabel.text = NSLocalizedString(@"verified, waiting for confirmation", nil);
                    
                    return cell;
                }
                case 5:
                {
                    DSTransactionAmountTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TransactionCellIdentifier"];
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    if (self.sent > 0 && self.sent == self.received) {
                        cell.amountLabel.attributedText = [walletManager attributedStringForDashAmount:self.sent];
                        cell.fiatAmountLabel.text = [NSString stringWithFormat:@"(%@)",
                                                     [walletManager localCurrencyStringForDashAmount:self.sent]];
                    }
                    else {
                        cell.amountLabel.attributedText = [walletManager attributedStringForDashAmount:self.received - self.sent];
                        cell.fiatAmountLabel.text = [NSString stringWithFormat:@"(%@)",
                                                     [walletManager localCurrencyStringForDashAmount:self.received - self.sent]];
                    }
                    
                    return cell;
                }
                default:
                    break;
            }
            
            break;
            
        case 1: // drop through
        case 2:
            if ((self.sent > 0 && indexPath.section == 1) || (self.sent == 0 && indexPath.section == 2)) {
                DSTransactionDetailTableViewCell * cell;
                if ([self.outputText[indexPath.row] length] > 0) {
                    cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                }
                else cell = [tableView dequeueReusableCellWithIdentifier:@"SubtitleCellIdentifier" forIndexPath:indexPath];
                [self setBackgroundForCell:cell indexPath:indexPath];
                cell.addressLabel.text = self.outputText[indexPath.row];
                cell.typeInfoLabel.text = self.outputDetail[indexPath.row];
                cell.amountLabel.textColor = (self.sent > 0) ? [UIColor colorWithRed:1.0 green:0.33 blue:0.33 alpha:1.0] :
                [UIColor colorWithRed:0.0 green:0.75 blue:0.0 alpha:1.0];
                
                
                long long outputAmount = [self.outputAmount[indexPath.row] longLongValue];
                if (outputAmount == UINT64_MAX) {
                    UIFont * font = [UIFont systemFontOfSize:17 weight:UIFontWeightLight];
                    UIFontDescriptor * fontD = [font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
                    NSAttributedString * attributedString = [[NSAttributedString alloc] initWithString:@"fetching amount" attributes:@{NSFontAttributeName: [UIFont fontWithDescriptor:fontD size:0]}];
                    
                    cell.amountLabel.attributedText = attributedString;
                    cell.fiatAmountLabel.textColor = cell.amountLabel.textColor;
                    cell.fiatAmountLabel.text = @"";
                } else {
                    
                    
                    BOOL isBitcoinInstead = [self.outputIsBitcoin[indexPath.row] boolValue];
                    if (isBitcoinInstead) {
                        cell.amountLabel.text = [walletManager stringForBitcoinAmount:[self.outputAmount[indexPath.row] longLongValue]];
                        cell.amountLabel.textColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.0 alpha:1.0];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                        cell.fiatAmountLabel.text = [NSString stringWithFormat:@"(%@)",
                                                     [walletManager localCurrencyStringForBitcoinAmount:[self.outputAmount[indexPath.row]
#pragma clang diagnostic pop
                                                                                                         longLongValue]]];
                    } else {
                        cell.amountLabel.attributedText = [walletManager attributedStringForDashAmount:[self.outputAmount[indexPath.row] longLongValue] withTintColor:cell.amountLabel.textColor dashSymbolSize:CGSizeMake(9, 9)];
                        cell.fiatAmountLabel.text = [NSString stringWithFormat:@"(%@)",
                                                     [walletManager localCurrencyStringForDashAmount:[self.outputAmount[indexPath.row]
                                                                                                      longLongValue]]];
                    }
                    cell.fiatAmountLabel.textColor = cell.amountLabel.textColor;
                }
                return cell;
            }
            else if (self.inputAddresses[indexPath.row] != (id)[NSNull null]) {
                DSTransactionDetailTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCellIdentifier" forIndexPath:indexPath];
                [self setBackgroundForCell:cell indexPath:indexPath];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.addressLabel.text = self.inputAddresses[indexPath.row];
                cell.amountLabel.text = nil;
                cell.fiatAmountLabel.text = nil;
                if ([account containsAddress:self.inputAddresses[indexPath.row]]) {
                    cell.typeInfoLabel.text = NSLocalizedString(@"wallet address", nil);
                }
                else cell.typeInfoLabel.text = NSLocalizedString(@"spent address", nil);
                return cell;
            }
            else {
                DSTransactionDetailTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCellIdentifier" forIndexPath:indexPath];
                [self setBackgroundForCell:cell indexPath:indexPath];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                
                cell.addressLabel.text = NSLocalizedString(@"unknown address", nil);
                cell.typeInfoLabel.text = NSLocalizedString(@"spent input", nil);
                cell.amountLabel.text = nil;
                cell.fiatAmountLabel.text = nil;
                return cell;
            }
            
            
            break;
        case 3:
        {
            
            if ([self.transaction isMemberOfClass:[DSBlockchainUserRegistrationTransaction class]]) {
                DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = (DSBlockchainUserRegistrationTransaction *)self.transaction;
                switch (indexPath.row) {
                    case 0:
                    {
                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"BU version", nil);
                        cell.statusLabel.text = [NSString stringWithFormat:@"%d",blockchainUserRegistrationTransaction.blockchainUserRegistrationTransactionVersion];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 1:
                    {
                        DSTransactionIdentifierTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.titleLabel.text = NSLocalizedString(@"public key hash:", nil);
                        s = [NSData dataWithUInt160:blockchainUserRegistrationTransaction.pubkeyHash].hexString;
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length/2],
                                                     [s substringFromIndex:s.length/2]];
                        cell.identifierLabel.copyableText = s;
                        return cell;
                        break;
                    }
                    case 2:
                    {
                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"username:", nil);
                        cell.statusLabel.text = blockchainUserRegistrationTransaction.username;
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 3:
                    {
                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"topup amount:", nil);
                        cell.statusLabel.text = [[DSPriceManager sharedInstance] stringForDashAmount:blockchainUserRegistrationTransaction.topupAmount];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                        
                }
            } else if ([self.transaction isMemberOfClass:[DSBlockchainUserTopupTransaction class]]) {
                DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction = (DSBlockchainUserTopupTransaction *)self.transaction;
                switch (indexPath.row) {
                    case 0:
                    {
                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"BU version", nil);
                        cell.statusLabel.text = [NSString stringWithFormat:@"%d",blockchainUserTopupTransaction.blockchainUserTopupTransactionVersion];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 1:
                    {
                        DSTransactionIdentifierTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.titleLabel.text = NSLocalizedString(@"subregtx:", nil);
                        s = [NSData dataWithUInt256:blockchainUserTopupTransaction.registrationTransactionHash].hexString;
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length/2],
                                                     [s substringFromIndex:s.length/2]];
                        cell.identifierLabel.copyableText = s;
                        return cell;
                        break;
                    }
                    case 2:
                    {
                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"topup amount:", nil);
                        cell.statusLabel.text = [[DSPriceManager sharedInstance] stringForDashAmount:blockchainUserTopupTransaction.topupAmount];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                        
                }
            } else if ([self.transaction isMemberOfClass:[DSBlockchainUserResetTransaction class]]) {
                DSBlockchainUserResetTransaction * blockchainUserResetTransaction = (DSBlockchainUserResetTransaction *)self.transaction;
                switch (indexPath.row) {
                    case 0:
                    {
                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"BU version", nil);
                        cell.statusLabel.text = [NSString stringWithFormat:@"%d",blockchainUserResetTransaction.blockchainUserResetTransactionVersion];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 1:
                    {
                        DSTransactionIdentifierTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.titleLabel.text = NSLocalizedString(@"subregtx:", nil);
                        s = [NSData dataWithUInt256:blockchainUserResetTransaction.registrationTransactionHash].hexString;
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length/2],
                                                     [s substringFromIndex:s.length/2]];
                        cell.identifierLabel.copyableText = s;
                        return cell;
                        break;
                    }
                    case 2:
                    {
                        DSTransactionIdentifierTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.titleLabel.text = NSLocalizedString(@"new pubkeyhash:", nil);
                        s = [NSData dataWithUInt160:blockchainUserResetTransaction.replacementPublicKeyHash].hexString;
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length/2],
                                                     [s substringFromIndex:s.length/2]];
                        cell.identifierLabel.copyableText = s;
                        return cell;
                        break;
                    }
                        
                }
            }
            
        }
            break;
    }
    NSAssert(NO, @"Unknown cell");
    return [[UITableViewCell alloc] init];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0: return nil;
        case 1: return (self.sent > 0) ? NSLocalizedString(@"to:", nil) : NSLocalizedString(@"from:", nil);
        case 2: return (self.sent > 0) ? NSLocalizedString(@"from:", nil) : NSLocalizedString(@"to:", nil);
        case 3: return @"payload:";
    }
    
    return nil;
}

// MARK: - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0: return 44.0;
        case 1: return (self.sent > 0 && [self.outputText[indexPath.row] length] == 0) ? 40 : 60.0;
        case 2: return 60.0;
    }
    
    return 44.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *sectionTitle = [self tableView:tableView titleForHeaderInSection:section];
    
    if (sectionTitle.length == 0) return 22.0;
    
    CGRect textRect = [sectionTitle boundingRectWithSize:CGSizeMake(self.view.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17 weight:UIFontWeightLight]} context:nil];
    
    return textRect.size.height + 12.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *headerview = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                                  [self tableView:tableView heightForHeaderInSection:section])];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.0, 10.0, headerview.frame.size.width - 30.0,
                                                                    headerview.frame.size.height - 12.0)];
    
    titleLabel.text = [self tableView:tableView titleForHeaderInSection:section];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightLight];
    titleLabel.textColor = [UIColor darkTextColor];
    titleLabel.numberOfLines = 0;
    headerview.backgroundColor = [UIColor clearColor];
    [headerview addSubview:titleLabel];
    
    return headerview;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger i = [self.tableView.indexPathsForVisibleRows indexOfObject:indexPath];
    UITableViewCell *cell = (i < self.tableView.visibleCells.count) ? self.tableView.visibleCells[i] : nil;
    BRCopyLabel *copyLabel = (id)[cell viewWithTag:2];
    
    copyLabel.selectedColor = [UIColor clearColor];
    if (cell.selectionStyle != UITableViewCellSelectionStyleNone) [copyLabel toggleCopyMenu];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
