//
//  DSSporkTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 5/29/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSSporkTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *sporkNameLabel;
@property (strong, nonatomic) IBOutlet UILabel *sporkValueLabel;
@property (strong, nonatomic) IBOutlet UILabel *sporkIdentifierLabel;
@property (strong, nonatomic) IBOutlet UILabel *sporkTimeSignedLabel;

@end
