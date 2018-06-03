//
//  DSAddressTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 4/20/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSAddressTableViewCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *balanceLabel;
@property (strong, nonatomic) IBOutlet UILabel *inLabel;
@property (strong, nonatomic) IBOutlet UILabel *outLabel;
@property (strong, nonatomic) IBOutlet UILabel *derivationPathLabel;
@property (strong, nonatomic) IBOutlet UILabel *addressLabel;

@end
