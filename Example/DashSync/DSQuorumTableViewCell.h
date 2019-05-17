//
//  DSQuorumTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 5/15/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *quorumHashLabel;
@property (strong, nonatomic) IBOutlet UILabel *heightLabel;

@end

NS_ASSUME_NONNULL_END
