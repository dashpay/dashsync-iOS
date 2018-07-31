//
//  DSPeerTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 7/31/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSPeerTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *addressLabel;
@property (strong, nonatomic) IBOutlet UILabel *priorityLabel;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UILabel *nodeTypeLabel;

@end
