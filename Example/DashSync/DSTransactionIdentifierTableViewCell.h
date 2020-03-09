//
//  DSTransactionIdentifierTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 7/22/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "BRCopyLabel.h"
#import <UIKit/UIKit.h>

@interface DSTransactionIdentifierTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet BRCopyLabel *identifierLabel;
@property (strong, nonatomic) IBOutlet BRCopyLabel *titleLabel;

@end
