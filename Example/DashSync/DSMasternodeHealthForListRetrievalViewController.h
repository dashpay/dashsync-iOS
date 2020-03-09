//
//  DSMasternodeHealthForListRetrievalViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/19/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeHealthForListRetrievalViewController : UITableViewController

@property (nonatomic, strong) DSChainManager *chainManager;

@end

NS_ASSUME_NONNULL_END
