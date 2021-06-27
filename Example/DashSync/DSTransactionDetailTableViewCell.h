//
//  DSTransactionDetailTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 7/22/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "BRCopyLabel.h"
#import <UIKit/UIKit.h>

@interface DSTransactionDetailTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet BRCopyLabel *addressLabel;
@property (strong, nonatomic) IBOutlet UILabel *typeInfoLabel;
@property (strong, nonatomic) IBOutlet UILabel *amountLabel;
@property (strong, nonatomic) IBOutlet UILabel *fiatAmountLabel;

@end
