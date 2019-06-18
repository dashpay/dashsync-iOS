//
//  DSMasternodeListTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/19/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *heightLabel;
@property (strong, nonatomic) IBOutlet UILabel *countLabel;

@end

NS_ASSUME_NONNULL_END
