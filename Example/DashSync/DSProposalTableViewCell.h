//
//  DSProposalTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/15/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSProposalTableViewCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *identifierLabel;
@property (strong, nonatomic) IBOutlet UILabel *amountLabel;
@property (strong, nonatomic) IBOutlet UILabel *startDateLabel;
@property (strong, nonatomic) IBOutlet UILabel *endDateLabel;
@property (strong, nonatomic) IBOutlet UILabel *paymentAddresLabel;
@property (strong, nonatomic) IBOutlet UILabel *urlLabel;
@property (strong, nonatomic) IBOutlet UILabel *isFundedLabel;
@property (strong, nonatomic) IBOutlet UILabel *paymentsCountLabel;
@property (strong, nonatomic) IBOutlet UILabel *voteTallyLabel;

@end
