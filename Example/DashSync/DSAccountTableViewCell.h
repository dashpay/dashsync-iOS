//
//  DSAccountTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSAccountTableViewCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *accountNumberLabel;
@property (strong, nonatomic) IBOutlet UILabel *balanceLabel;

@end
