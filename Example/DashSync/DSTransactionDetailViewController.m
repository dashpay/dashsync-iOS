//
//  DSTransactionDetailViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/8/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSAssetLockTransaction.h"
#import "DSAssetUnlockTransaction.h"
#import "DSTransactionDetailViewController.h"
#import "BRCopyLabel.h"
#import "DSTransactionAmountTableViewCell.h"
#import "DSTransactionDetailTableViewCell.h"
#import "DSTransactionIdentifierTableViewCell.h"
#import "DSTransactionOutput.h"
#import "DSTransactionStatusTableViewCell.h"
#import <DashSync/DashSync.h>
#include <arpa/inet.h>

#define TRANSACTION_CELL_HEIGHT 75

@interface DSTransactionDetailViewController ()

@property (nonatomic, strong) NSArray *inputAddresses, *outputText, *outputDetail, *outputAmount, *outputIsBitcoin;
@property (nonatomic, assign) int64_t sent, received;
@property (nonatomic, strong) id txStatusObserver;

@end

@implementation DSTransactionDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!self.txStatusObserver) {
        self.txStatusObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                              object:nil
                                                               queue:nil
                                                          usingBlock:^(NSNotification *note) {
                                                              DSTransaction *tx = [self.transaction.chain
                                                                  transactionForHash:self.transaction.txHash];

                                                              if (tx) self.transaction = tx;
                                                              [self.tableView reloadData];
                                                          }];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
    self.txStatusObserver = nil;

    [super viewWillDisappear:animated];
}

- (void)dealloc {
    if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
}

- (void)setTransaction:(DSTransaction *)transaction {
    DSPriceManager *manager = [DSPriceManager sharedInstance];
    NSMutableArray *mutableInputAddresses = [NSMutableArray array], *text = [NSMutableArray array], *detail = [NSMutableArray array], *amount = [NSMutableArray array], *currencyIsBitcoinInstead = [NSMutableArray array];
    NSArray<DSAccount *> *accounts = transaction.accounts;
    _transaction = transaction;
    uint64_t fee = 0;
    BOOL isExternalTransaction = TRUE;
    if (accounts.count) {
        fee = [accounts[0] feeForTransaction:transaction];
        self.sent = [transaction.chain amountSentByTransaction:transaction];
        self.received = [transaction.chain amountReceivedFromTransaction:transaction];
        isExternalTransaction = FALSE;
    }

    //if (![transaction isKindOfClass:[DSCoinbaseTransaction class]]) {
    for (NSString *inputAddress in transaction.inputAddresses) {
        if (![mutableInputAddresses containsObject:inputAddress]) {
            [mutableInputAddresses addObject:inputAddress];
        }
    }
    //}
    NSManagedObjectContext *context = [NSManagedObjectContext viewContext];

    for (DSTransactionOutput *output in transaction.outputs) {
        NSData *script = output.outScript;
        uint64_t amt = output.amount;
        NSString *address = output.address;
        DSAccount *account = nil;
        if (address == (id)[NSNull null]) {
            if (self.sent > 0) {
                if ([script UInt8AtOffset:0] == OP_RETURN) {
                    UInt8 length = [script UInt8AtOffset:1];
                    if ([script UInt8AtOffset:2] == OP_SHAPESHIFT) {
                        NSMutableData *data = [NSMutableData data];
                        uint8_t v = BITCOIN_PUBKEY_ADDRESS;
                        [data appendBytes:&v length:1];
                        NSData *addressData = [script subdataWithRange:NSMakeRange(3, length - 1)];

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
        } else if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]] && [((DSProviderRegistrationTransaction *)transaction).masternodeHoldingWallet containsHoldingAddress:address]) {
            if (self.sent == 0 || self.received + MASTERNODE_COST + fee == self.sent) {
                [text addObject:address];
                [detail addObject:NSLocalizedString(@"masternode holding address", nil)];
                [amount addObject:@(amt)];
                [currencyIsBitcoinInstead addObject:@FALSE];
            }
        } else if ((account = [transaction.chain accountContainingAddress:address])) {
            if ([account baseDerivationPathsContainAddress:address]) {
                [detail addObject:NSLocalizedString(@"wallet address", nil)];
            } else {
                DSDerivationPath *derivationPath = [account derivationPathContainingAddress:address];
                if ([derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
                    UInt256 destinationBlockchainIdentityUniqueId = [((DSIncomingFundsDerivationPath *)derivationPath) contactDestinationBlockchainIdentityUniqueId];
                    UInt256 sourceBlockchainIdentityUniqueId = [((DSIncomingFundsDerivationPath *)derivationPath) contactSourceBlockchainIdentityUniqueId];
                    DSBlockchainIdentityUsernameEntity *destination = [DSBlockchainIdentityUsernameEntity anyObjectInContext:context matching:@"blockchainIdentity.uniqueID == %@", uint256_data(destinationBlockchainIdentityUniqueId)];
                    DSBlockchainIdentityUsernameEntity *source = [DSBlockchainIdentityUsernameEntity anyObjectInContext:context matching:@"blockchainIdentity.uniqueID == %@", uint256_data(sourceBlockchainIdentityUniqueId)];

                    [detail addObject:[NSString stringWithFormat:NSLocalizedString(@"%@'s address from %@", nil), source.stringValue, destination.stringValue]];
                } else {
                    [detail addObject:NSLocalizedString(@"wallet address", nil)];
                }
            }

            [text addObject:address];
            [amount addObject:@(amt)];
            [currencyIsBitcoinInstead addObject:@FALSE];
        } else if ((account = [transaction.chain accountContainingDashpayExternalDerivationPathAddress:address])) {
            DSIncomingFundsDerivationPath *incomingFundsDerivationPath = [account externalDerivationPathContainingAddress:address];
            DSBlockchainIdentityUsernameEntity *contact = [DSBlockchainIdentityUsernameEntity anyObjectInContext:context matching:@"blockchainIdentity.uniqueID == %@", uint256_data(incomingFundsDerivationPath.contactSourceBlockchainIdentityUniqueId)];
            [detail addObject:[NSString stringWithFormat:NSLocalizedString(@"%@'s address", nil), contact.stringValue]];
            [text addObject:address];
            [amount addObject:@(-amt)];
            [currencyIsBitcoinInstead addObject:@FALSE];
        } else if (self.sent > 0) {
            [text addObject:address?address:@"unknown address"];
            [detail addObject:NSLocalizedString(@"payment address", nil)];
            [amount addObject:@(-amt)];
            [currencyIsBitcoinInstead addObject:@FALSE];
        } else if (isExternalTransaction) {
            [text addObject:address];
            [detail addObject:NSLocalizedString(@"address", nil)];
            [amount addObject:@(amt)];
            [currencyIsBitcoinInstead addObject:@FALSE];
        }
    }

    if ((self.sent > 0 && fee > 0 && fee != UINT64_MAX) || isExternalTransaction) {
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

- (void)setBackgroundForCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)path {
    [cell viewWithTag:100].hidden = (path.row > 0);
    [cell viewWithTag:101].hidden = (path.row + 1 < [self tableView:self.tableView numberOfRowsInSection:path.section]);
}

// MARK: - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    switch ([self.transaction type]) {
        case DSTransactionType_Classic:
            return 3;
            break;
        case DSTransactionType_Coinbase:
            return 2;
            break;
        default:
            return 4;
            break;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    NSInteger realSection = section;
    if ([self.transaction type] == DSTransactionType_Coinbase && section == 1) realSection++;
    switch (section) {
        case 0:
            return self.transaction.associatedShapeshift ? (([self.transaction.associatedShapeshift.shapeshiftStatus integerValue] | eShapeshiftAddressStatus_Finished) ? 9 : 8) : 7;
        case 1:
            return (self.sent > 0) ? self.outputText.count : self.inputAddresses.count;
        case 2:
            return (self.sent > 0) ? self.inputAddresses.count : self.outputText.count;
        case 3: {
            switch ([self.transaction type]) {
                    //                case DSTransactionType_SubscriptionRegistration:
                    //                    return 4;
                    //                    break;
                    //                case DSTransactionType_SubscriptionResetKey:
                    //                    return 3;
                    //                    break;
                    //                case DSTransactionType_SubscriptionTopUp:
                    //                    return 3;
                    //                    break;
                case DSTransactionType_ProviderRegistration:
                    return 10;
                    break;
                case DSTransactionType_ProviderUpdateService:
                    return 3;
                    break;
                case DSTransactionType_ProviderUpdateRegistrar:
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSPriceManager *walletManager = [DSPriceManager sharedInstance];
    DSChainManager *chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:self.transaction.chain];
    NSUInteger peerCount = chainManager.peerManager.connectedPeerCount;
    NSUInteger relayCount = [chainManager.transactionManager relayCountForTransaction:self.transaction.txHash];
    DSAccount *account = self.transaction.firstAccount;
    NSString *s;

    NSInteger indexPathRow = indexPath.row;
    NSInteger realSection = indexPath.section;
    if ([self.transaction type] == DSTransactionType_Coinbase && indexPath.section == 1) realSection++;
    NSManagedObjectContext *context = [NSManagedObjectContext viewContext];
    // Configure the cell...
    switch (realSection) {
        case 0:
            if (!self.transaction.associatedShapeshift) {
                if (indexPathRow > 1) indexPathRow += 2; // no assoc
            } else if (!([self.transaction.associatedShapeshift.shapeshiftStatus integerValue] | eShapeshiftAddressStatus_Finished)) {
                if (indexPathRow > 1) indexPathRow += 1;
            }
            switch (indexPathRow) {
                case 0: {
                    DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"type:", nil);
                    if ([self.transaction isMemberOfClass:[DSBlockchainIdentityRegistrationTransition class]]) {
                        cell.statusLabel.text = @"BU Registration Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSBlockchainIdentityTopupTransition class]]) {
                        cell.statusLabel.text = @"BU Topup Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSBlockchainIdentityUpdateTransition class]]) {
                        cell.statusLabel.text = @"BU Reset Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSProviderRegistrationTransaction class]]) {
                        cell.statusLabel.text = @"Masternode Registration Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSProviderUpdateServiceTransaction class]]) {
                        cell.statusLabel.text = @"Masternode Update Service Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
                        cell.statusLabel.text = @"Masternode Update Registrar Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSCoinbaseTransaction class]]) {
                        cell.statusLabel.text = @"Coinbase Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSCreditFundingTransaction class]]) {
                        cell.statusLabel.text = @"Classical Credit Funding Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSAssetLockTransaction class]]) {
                        cell.statusLabel.text = @"Asset Lock Transaction";
                    } else if ([self.transaction isMemberOfClass:[DSAssetUnlockTransaction class]]) {
                        cell.statusLabel.text = @"Asset Unlock Transaction";
                    } else {
                        cell.statusLabel.text = @"Classical Transaction";
                    }
                    cell.moreInfoLabel.text = nil;
                    return cell;
                    break;
                }
                case 1: {
                    DSTransactionIdentifierTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"id:", nil);
                    s = [NSString hexWithData:[NSData dataWithBytes:self.transaction.txHash.u8
                                                             length:sizeof(UInt256)]
                                                  .reverse];
                    cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length / 2],
                                                          [s substringFromIndex:s.length / 2]];
                    cell.identifierLabel.copyableText = s;
                    return cell;
                }
                case 2: {
                    DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"shapeshift bitcoin id:", nil);
                    cell.statusLabel.text = [self.transaction.associatedShapeshift outputTransactionId];
                    cell.moreInfoLabel.text = nil;
                    return cell;
                }
                case 3: {
                    DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"shapeshift status:", nil);
                    cell.statusLabel.text = [self.transaction.associatedShapeshift shapeshiftStatusString];
                    cell.moreInfoLabel.text = nil;
                    return cell;
                }
                case 4: {
                    DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;

                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"status:", nil);
                    cell.moreInfoLabel.text = nil;

                    if (!account) {
                        cell.statusLabel.text = NSLocalizedString(@"external transaction", nil);
                    } else if ([account transactionOutputsAreLocked:self.transaction]) {
                        cell.statusLabel.text = NSLocalizedString(@"recently mined (locked)", nil);
                    } else if (self.transaction.blockHeight != TX_UNCONFIRMED) {
                        cell.statusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"mined in block #%d (%@)", nil),
                                                          self.transaction.blockHeight, self.txDateString];
                        cell.moreInfoLabel.text = self.txDateString;
                    } else if (![account transactionIsValid:self.transaction]) {
                        cell.statusLabel.text = NSLocalizedString(@"double spend", nil);
                    } else if ([account transactionIsPending:self.transaction]) {
                        cell.statusLabel.text = NSLocalizedString(@"pending", nil);
                    } else if (![account transactionIsVerified:self.transaction]) {
                        cell.statusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"seen by %d of %d peers", nil),
                                                          (int)relayCount, (int)peerCount];
                    } else
                        cell.statusLabel.text = NSLocalizedString(@"verified, waiting for confirmation", nil);

                    return cell;
                }
                case 5: {
                    DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;

                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"confirmed:", nil);
                    cell.statusLabel.text = self.transaction.confirmed ? @"Yes" : @"No";
                    if (self.transaction.confirmations < 6) {
                        BOOL chainLocked = [self.transaction.chain blockHeightChainLocked:self.transaction.blockHeight];
                        if (chainLocked) {
                            cell.moreInfoLabel.text = @"Using chain lock";
                        } else {
                            cell.moreInfoLabel.text = nil;
                        }
                    } else {
                        cell.moreInfoLabel.text = @"More than 6 confirmations";
                    }


                    return cell;
                }
                case 6: {
                    DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;

                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = @"IS received/locked/memory:";
                    cell.statusLabel.text = [NSString stringWithFormat:@"%@/%@/%@", self.transaction.instantSendLockAwaitingProcessing || self.transaction.instantSendReceived ? @"YES" : @"NO",
                                                      self.transaction.instantSendReceived ? @"YES" : @"NO", self.transaction.instantSendLockAwaitingProcessing ? @"YES" : @"NO"];
                    if (self.transaction.confirmations < 6) {
                        BOOL chainLocked = [self.transaction.chain blockHeightChainLocked:self.transaction.blockHeight];
                        if (chainLocked) {
                            cell.moreInfoLabel.text = @"Using chain lock";
                        } else {
                            cell.moreInfoLabel.text = nil;
                        }
                    } else {
                        cell.moreInfoLabel.text = @"More than 6 confirmations";
                    }


                    return cell;
                }
                case 7: {
                    DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    cell.titleLabel.text = NSLocalizedString(@"size:", nil);
                    uint64_t roundedFeeCostPerByte = self.transaction.roundedFeeCostPerByte;
                    if (roundedFeeCostPerByte != UINT64_MAX) { //otherwise it's being received and can't know.
                        cell.statusLabel.text = roundedFeeCostPerByte == 1 ? NSLocalizedString(@"1 duff/byte", nil) : [NSString stringWithFormat:NSLocalizedString(@"%d duffs/byte", nil), (int)roundedFeeCostPerByte];
                    } else {
                        cell.statusLabel.text = nil;
                    }
                    cell.moreInfoLabel.text = [@(self.transaction.size) stringValue];

                    return cell;
                }
                case 8: {
                    DSTransactionAmountTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TransactionCellIdentifier"];
                    [self setBackgroundForCell:cell indexPath:indexPath];
                    if (self.sent > 0 && self.sent == self.received) {
                        cell.amountLabel.attributedText = [walletManager attributedStringForDashAmount:self.sent];
                        cell.fiatAmountLabel.text = [NSString stringWithFormat:@"(%@)",
                                                              [walletManager localCurrencyStringForDashAmount:self.sent]];
                    } else {
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
            if ((self.sent > 0 && realSection == 1) || (self.sent == 0 && realSection == 2)) {
                DSTransactionDetailTableViewCell *cell;
                if ([self.outputText[indexPath.row] length] > 0) {
                    cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCellIdentifier" forIndexPath:indexPath];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                } else
                    cell = [tableView dequeueReusableCellWithIdentifier:@"SubtitleCellIdentifier" forIndexPath:indexPath];
                [self setBackgroundForCell:cell indexPath:indexPath];
                cell.addressLabel.text = self.outputText[indexPath.row];
                cell.typeInfoLabel.text = self.outputDetail[indexPath.row];
                cell.amountLabel.textColor = (self.sent > 0) ? [UIColor colorWithRed:1.0 green:0.33 blue:0.33 alpha:1.0] : [UIColor colorWithRed:0.0 green:0.75 blue:0.0 alpha:1.0];


                long long outputAmount = [self.outputAmount[indexPath.row] longLongValue];
                if (outputAmount == UINT64_MAX) {
                    UIFont *font = [UIFont systemFontOfSize:17 weight:UIFontWeightLight];
                    UIFontDescriptor *fontD = [font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
                    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:@"fetching amount" attributes:@{NSFontAttributeName: [UIFont fontWithDescriptor:fontD size:0]}];

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
            } else if (self.inputAddresses[indexPath.row] != (id)[NSNull null]) {
                DSTransactionDetailTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCellIdentifier" forIndexPath:indexPath];
                [self setBackgroundForCell:cell indexPath:indexPath];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.addressLabel.text = self.inputAddresses[indexPath.row];
                cell.amountLabel.text = nil;
                cell.fiatAmountLabel.text = nil;
                if ([account containsAddress:self.inputAddresses[indexPath.row]]) {
                    if ([account baseDerivationPathsContainAddress:self.inputAddresses[indexPath.row]]) {
                        cell.typeInfoLabel.text = NSLocalizedString(@"wallet address", nil);
                    } else {
                        DSDerivationPath *derivationPath = [account derivationPathContainingAddress:self.inputAddresses[indexPath.row]];
                        if ([derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
                            DSBlockchainIdentityUsernameEntity *contact = [DSBlockchainIdentityUsernameEntity anyObjectInContext:context matching:@"blockchainIdentity.uniqueID == %@", uint256_data(((DSIncomingFundsDerivationPath *)derivationPath).contactSourceBlockchainIdentityUniqueId)];
                            cell.typeInfoLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@'s address", nil), contact.stringValue];
                        } else {
                            cell.typeInfoLabel.text = NSLocalizedString(@"wallet address", nil);
                        }
                    }
                } else
                    cell.typeInfoLabel.text = NSLocalizedString(@"spent address", nil);
                return cell;
            } else {
                DSTransactionDetailTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCellIdentifier" forIndexPath:indexPath];
                [self setBackgroundForCell:cell indexPath:indexPath];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;

                cell.addressLabel.text = NSLocalizedString(@"unknown address", nil);
                cell.typeInfoLabel.text = NSLocalizedString(@"spent input", nil);
                cell.amountLabel.text = nil;
                cell.fiatAmountLabel.text = nil;
                return cell;
            }


            break;
        case 3: {
            //            if ([self.transaction isMemberOfClass:[DSBlockchainIdentityRegistrationTransition class]]) {
            //                DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction = (DSBlockchainIdentityRegistrationTransition *)self.transaction;
            //                switch (indexPath.row) {
            //                    case 0:
            //                    {
            //                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
            //                        cell.titleLabel.text = NSLocalizedString(@"BU version", nil);
            //                        cell.statusLabel.text = [NSString stringWithFormat:@"%d",blockchainIdentityRegistrationTransaction.blockchainIdentityRegistrationTransactionVersion];
            //                        cell.moreInfoLabel.text = nil;
            //                        return cell;
            //                        break;
            //                    }
            //                    case 1:
            //                    {
            //                        DSTransactionIdentifierTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.titleLabel.text = NSLocalizedString(@"public key address:", nil);
            //                        s = [[NSData dataWithUInt160:blockchainIdentityRegistrationTransaction.pubkeyHash] addressFromHash160DataForChain:self.transaction.chain];
            //                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length/2],
            //                                                     [s substringFromIndex:s.length/2]];
            //                        cell.identifierLabel.copyableText = s;
            //                        return cell;
            //                        break;
            //                    }
            //                    case 2:
            //                    {
            //                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
            //                        cell.titleLabel.text = NSLocalizedString(@"username:", nil);
            //                        cell.statusLabel.text = blockchainIdentityRegistrationTransaction.username;
            //                        cell.moreInfoLabel.text = nil;
            //                        return cell;
            //                        break;
            //                    }
            //                    case 3:
            //                    {
            //                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
            //                        cell.titleLabel.text = NSLocalizedString(@"topup amount:", nil);
            //                        cell.statusLabel.text = [[DSPriceManager sharedInstance] stringForDashAmount:blockchainIdentityRegistrationTransaction.topupAmount];
            //                        cell.moreInfoLabel.text = nil;
            //                        return cell;
            //                        break;
            //                    }
            //
            //                }
            //            } else if ([self.transaction isMemberOfClass:[DSBlockchainIdentityTopupTransition class]]) {
            //                DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction = (DSBlockchainIdentityTopupTransition *)self.transaction;
            //                switch (indexPath.row) {
            //                    case 0:
            //                    {
            //                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
            //                        cell.titleLabel.text = NSLocalizedString(@"BU version", nil);
            //                        cell.statusLabel.text = [NSString stringWithFormat:@"%d",blockchainIdentityTopupTransaction.blockchainIdentityTopupTransactionVersion];
            //                        cell.moreInfoLabel.text = nil;
            //                        return cell;
            //                        break;
            //                    }
            //                    case 1:
            //                    {
            //                        DSTransactionIdentifierTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.titleLabel.text = NSLocalizedString(@"subregtx:", nil);
            //                        s = [NSData dataWithUInt256:blockchainIdentityTopupTransaction.registrationTransactionHash].hexString;
            //                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length/2],
            //                                                     [s substringFromIndex:s.length/2]];
            //                        cell.identifierLabel.copyableText = s;
            //                        return cell;
            //                        break;
            //                    }
            //                    case 2:
            //                    {
            //                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
            //                        cell.titleLabel.text = NSLocalizedString(@"topup amount:", nil);
            //                        cell.statusLabel.text = [[DSPriceManager sharedInstance] stringForDashAmount:blockchainIdentityTopupTransaction.topupAmount];
            //                        cell.moreInfoLabel.text = nil;
            //                        return cell;
            //                        break;
            //                    }
            //
            //                }
            //            } else if ([self.transaction isMemberOfClass:[DSBlockchainIdentityUpdateTransition class]]) {
            //                DSBlockchainIdentityUpdateTransition * blockchainIdentityResetTransaction = (DSBlockchainIdentityUpdateTransition *)self.transaction;
            //                switch (indexPath.row) {
            //                    case 0:
            //                    {
            //                        DSTransactionStatusTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
            //                        cell.titleLabel.text = NSLocalizedString(@"BU version", nil);
            //                        cell.statusLabel.text = [NSString stringWithFormat:@"%d",blockchainIdentityResetTransaction.blockchainIdentityResetTransactionVersion];
            //                        cell.moreInfoLabel.text = nil;
            //                        return cell;
            //                        break;
            //                    }
            //                    case 1:
            //                    {
            //                        DSTransactionIdentifierTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.titleLabel.text = NSLocalizedString(@"subregtx:", nil);
            //                        s = [NSData dataWithUInt256:blockchainIdentityResetTransaction.registrationTransactionHash].hexString;
            //                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length/2],
            //                                                     [s substringFromIndex:s.length/2]];
            //                        cell.identifierLabel.copyableText = s;
            //                        return cell;
            //                        break;
            //                    }
            //                    case 2:
            //                    {
            //                        DSTransactionIdentifierTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
            //                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            //                        [self setBackgroundForCell:cell indexPath:indexPath];
            //                        cell.titleLabel.text = NSLocalizedString(@"new pubkeyhash:", nil);
            //                        s = [NSData dataWithUInt160:blockchainIdentityResetTransaction.replacementPublicKeyHash].hexString;
            //                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length/2],
            //                                                     [s substringFromIndex:s.length/2]];
            //                        cell.identifierLabel.copyableText = s;
            //                        return cell;
            //                        break;
            //                    }
            //
            //                }
            //            } else
            if ([self.transaction isMemberOfClass:[DSProviderRegistrationTransaction class]]) {
                DSProviderRegistrationTransaction *providerRegistrationTransaction = (DSProviderRegistrationTransaction *)self.transaction;
                switch (indexPath.row) {
                    case 0: {
                        DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"Provider registration version", nil);
                        cell.statusLabel.text = [NSString stringWithFormat:@"%d", providerRegistrationTransaction.providerRegistrationTransactionVersion];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 1: {
                        DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"IP Address/Port", nil);
                        char s[INET6_ADDRSTRLEN];
                        NSString *ipAddressString = @(inet_ntop(AF_INET, &providerRegistrationTransaction.ipAddress.u32[3], s, sizeof(s)));
                        cell.statusLabel.text = [NSString stringWithFormat:@"%@:%d", ipAddressString, providerRegistrationTransaction.port];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 2: {
                        DSTransactionIdentifierTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.titleLabel.text = NSLocalizedString(@"owner key hash:", nil);
                        s = [NSData dataWithUInt160:providerRegistrationTransaction.ownerKeyHash].hexString;
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length / 2],
                                                              [s substringFromIndex:s.length / 2]];
                        cell.identifierLabel.copyableText = s;
                        return cell;
                        break;
                    }
                    case 3: {
                        DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"owner key wallet:", nil);
                        DSLocalMasternode *localMasternode = providerRegistrationTransaction.localMasternode;
                        cell.statusLabel.text = localMasternode.ownerKeysWallet ? [NSString stringWithFormat:@"%@/%d", localMasternode.ownerKeysWallet.uniqueIDString, localMasternode.ownerWalletIndex] : @"Not Owner";
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 4: {
                        DSTransactionIdentifierTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.titleLabel.text = NSLocalizedString(@"operator key:", nil);
                        s = [NSData dataWithUInt384:providerRegistrationTransaction.operatorKey].hexString;
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length / 2],
                                                              [s substringFromIndex:s.length / 2]];
                        cell.identifierLabel.copyableText = s;
                        return cell;
                        break;
                    }
                    case 5: {
                        DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"operator key wallet:", nil);
                        DSLocalMasternode *localMasternode = providerRegistrationTransaction.localMasternode;
                        cell.statusLabel.text = localMasternode.operatorKeysWallet ? [NSString stringWithFormat:@"%@/%d", localMasternode.operatorKeysWallet.uniqueIDString, localMasternode.operatorWalletIndex] : @"Not Operator";
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 6: {
                        DSTransactionIdentifierTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.titleLabel.text = NSLocalizedString(@"voting key hash:", nil);
                        s = [NSData dataWithUInt160:providerRegistrationTransaction.votingKeyHash].hexString;
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length / 2],
                                                              [s substringFromIndex:s.length / 2]];
                        cell.identifierLabel.copyableText = s;
                        return cell;
                        break;
                    }
                    case 7: {
                        DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"voting key wallet:", nil);
                        DSLocalMasternode *localMasternode = providerRegistrationTransaction.localMasternode;
                        cell.statusLabel.text = localMasternode.votingKeysWallet ? [NSString stringWithFormat:@"%@/%d", localMasternode.votingKeysWallet.uniqueIDString, localMasternode.votingWalletIndex] : @"Not Voter";
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 8: {
                        DSTransactionIdentifierTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"Payout Address", nil);
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@", [DSKeyManager addressWithScriptPubKey:providerRegistrationTransaction.scriptPayout forChain:providerRegistrationTransaction.chain]];
                        return cell;
                        break;
                    }
                    case 9: {
                        DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"Holding funds wallet:", nil);
                        DSLocalMasternode *localMasternode = providerRegistrationTransaction.localMasternode;
                        cell.statusLabel.text = localMasternode.holdingKeysWallet ? [NSString stringWithFormat:@"%@/%d", localMasternode.holdingKeysWallet.uniqueIDString, localMasternode.holdingWalletIndex] : @"Not Holding";
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                }
            } else if ([self.transaction isMemberOfClass:[DSProviderUpdateServiceTransaction class]]) {
                DSProviderUpdateServiceTransaction *providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction *)self.transaction;
                switch (indexPath.row) {
                    case 0: {
                        DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"Provider update service version", nil);
                        cell.statusLabel.text = [NSString stringWithFormat:@"%d", providerUpdateServiceTransaction.providerUpdateServiceTransactionVersion];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 1: {
                        DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"IP Address/Port", nil);
                        char s[INET6_ADDRSTRLEN];
                        NSString *ipAddressString = @(inet_ntop(AF_INET, &providerUpdateServiceTransaction.ipAddress.u32[3], s, sizeof(s)));
                        cell.statusLabel.text = [NSString stringWithFormat:@"%@:%d", ipAddressString, providerUpdateServiceTransaction.port];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 2: {
                        DSTransactionIdentifierTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.titleLabel.text = NSLocalizedString(@"provider registration hash:", nil);
                        s = [NSData dataWithUInt256:providerUpdateServiceTransaction.providerRegistrationTransactionHash].hexString;
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length / 2],
                                                              [s substringFromIndex:s.length / 2]];
                        cell.identifierLabel.copyableText = s;
                        return cell;
                        break;
                    }
                }
            } else if ([self.transaction isMemberOfClass:[DSProviderUpdateRegistrarTransaction class]]) {
                DSProviderUpdateRegistrarTransaction *providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction *)self.transaction;
                switch (indexPath.row) {
                    case 0: {
                        DSTransactionStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TitleCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"Provider update service version", nil);
                        cell.statusLabel.text = [NSString stringWithFormat:@"%d", providerUpdateRegistrarTransaction.providerUpdateRegistrarTransactionVersion];
                        cell.moreInfoLabel.text = nil;
                        return cell;
                        break;
                    }
                    case 1: {
                        DSTransactionIdentifierTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.titleLabel.text = NSLocalizedString(@"Payout Address", nil);
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@", [DSKeyManager addressWithScriptPubKey:providerUpdateRegistrarTransaction.scriptPayout forChain:providerUpdateRegistrarTransaction.chain]];

                        return cell;
                        break;
                    }
                    case 2: {
                        DSTransactionIdentifierTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IdCellIdentifier" forIndexPath:indexPath];
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        [self setBackgroundForCell:cell indexPath:indexPath];
                        cell.titleLabel.text = NSLocalizedString(@"provider registration hash:", nil);
                        s = [NSData dataWithUInt256:providerUpdateRegistrarTransaction.providerRegistrationTransactionHash].hexString;
                        cell.identifierLabel.text = [NSString stringWithFormat:@"%@\n%@", [s substringToIndex:s.length / 2],
                                                              [s substringFromIndex:s.length / 2]];
                        cell.identifierLabel.copyableText = s;
                        return cell;
                        break;
                    }
                }
            }

        } break;
    }
    NSAssert(NO, @"Unknown cell");
    return [[UITableViewCell alloc] init];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSUInteger realSection = section;
    if ([self.transaction type] == DSTransactionType_Coinbase && section == 1) realSection++;
    switch (realSection) {
        case 0:
            return nil;
        case 1:
            return (self.sent > 0) ? NSLocalizedString(@"to:", nil) : NSLocalizedString(@"from:", nil);
        case 2:
            return (self.sent > 0) ? NSLocalizedString(@"from:", nil) : NSLocalizedString(@"to:", nil);
        case 3:
            return @"payload:";
    }

    return nil;
}

// MARK: - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
            return 44.0;
        case 1:
            return (self.sent > 0 && [self.outputText[indexPath.row] length] == 0) ? 40 : 60.0;
        case 2:
            return 60.0;
    }

    return 44.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSString *sectionTitle = [self tableView:tableView titleForHeaderInSection:section];

    if (sectionTitle.length == 0) return 22.0;

    CGRect textRect = [sectionTitle boundingRectWithSize:CGSizeMake(self.view.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightLight]}
                                                 context:nil];

    return textRect.size.height + 12.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerview = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                           [self tableView:tableView
                                                               heightForHeaderInSection:section])];
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger i = [self.tableView.indexPathsForVisibleRows indexOfObject:indexPath];
    UITableViewCell *cell = (i < self.tableView.visibleCells.count) ? self.tableView.visibleCells[i] : nil;
    BRCopyLabel *copyLabel = (id)[cell viewWithTag:2];

    copyLabel.selectedColor = [UIColor clearColor];
    if (cell.selectionStyle != UITableViewCellSelectionStyleNone) [copyLabel toggleCopyMenu];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
