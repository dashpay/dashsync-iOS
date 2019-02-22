//
//  DSUpdateMasternodeRegistrarViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 2/22/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DSAccountChooserViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSUpdateMasternodeRegistrarViewController : UITableViewController <DSAccountChooserDelegate>

@property (nonatomic,strong) DSLocalMasternode * localMasternode;

@end

NS_ASSUME_NONNULL_END
