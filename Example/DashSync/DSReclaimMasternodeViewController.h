//
//  DSReclaimMasternodeViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 2/28/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSAccountChooserViewController.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSLocalMasternode;

@interface DSReclaimMasternodeViewController : UITableViewController

@property (nonatomic, strong) DSLocalMasternode *localMasternode;

@end

NS_ASSUME_NONNULL_END
