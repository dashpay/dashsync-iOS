//
//  DSMerkleBlockTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSMerkleBlockTableViewCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *blockHeightLabel;
@property (strong, nonatomic) IBOutlet UILabel *blockHashLabel;
@property (strong, nonatomic) IBOutlet UILabel *chainLockedLabel;
@property (strong, nonatomic) IBOutlet UILabel *chainWorkLabel;
@property (strong, nonatomic) IBOutlet UILabel *timestampLabel;

@end
