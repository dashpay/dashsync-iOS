//
//  DSUpdateMasternodeServiceViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 2/21/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSAccountChooserViewController.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSLocalMasternode;

@interface DSUpdateMasternodeServiceViewController : UITableViewController <DSAccountChooserDelegate>

@property (nonatomic, strong) DSLocalMasternode *localMasternode;

@end

NS_ASSUME_NONNULL_END
