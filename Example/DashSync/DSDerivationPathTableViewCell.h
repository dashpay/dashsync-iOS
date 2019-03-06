//
//  DSDerivationPathTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSDerivationPathTableViewCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *xPublicKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *balanceLabel;
@property (strong, nonatomic) IBOutlet UILabel *derivationPathLabel;
@property (strong, nonatomic) IBOutlet UILabel *signingMechanismLabel;
@property (strong, nonatomic) IBOutlet UILabel *referenceNameLabel;
@property (strong, nonatomic) IBOutlet UILabel *usedAddressesLabel;
@property (strong, nonatomic) IBOutlet UILabel *knownAddressesLabel;
@property (strong, nonatomic) IBOutlet UILabel *transactionsCountLabel;

@end
