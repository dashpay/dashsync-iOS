//
//  DSTransactionFloodingViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 12/6/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import "DSAccountChooserViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSTransactionFloodingViewController : UITableViewController <DSAccountChooserDelegate>

@property (nonatomic,strong) DSChainManager * chainManager;

@end

NS_ASSUME_NONNULL_END
