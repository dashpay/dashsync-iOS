//
//  DSMasternodeListsViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/18/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>
#import "DSMasternodeListTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListsViewController : UITableViewController<NSFetchedResultsControllerDelegate,DSMasternodeListTableViewCellDelegate>

@property (nonatomic,strong) DSChain * chain;

@end

NS_ASSUME_NONNULL_END
