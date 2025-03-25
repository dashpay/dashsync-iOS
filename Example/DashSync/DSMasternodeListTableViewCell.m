//
//  DSMasternodeListTableViewCell.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/19/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSMasternodeListTableViewCell.h"

@implementation DSMasternodeListTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)requestingValidation:(id)sender {
    //[self.masternodeListCellDelegate masternodeListTableViewCellRequestsValidation:self];
}

@end
