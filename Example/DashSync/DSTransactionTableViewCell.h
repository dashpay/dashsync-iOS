//
//  DSTransactionTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/22/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSTransactionTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *transactionLabel;
@property (strong, nonatomic) IBOutlet UILabel *directionLabel;
@property (strong, nonatomic) IBOutlet UILabel *amountLabel;
@property (strong, nonatomic) IBOutlet UILabel *dateLabel;

@end
