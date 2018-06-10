//
//  DSMasternodeTableViewCell.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/10/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSMasternodeTableViewCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *ipAddressLabel;
@property (strong, nonatomic) IBOutlet UILabel *protocolLabel;
@property (strong, nonatomic) IBOutlet UILabel *outputLabel;

@end
