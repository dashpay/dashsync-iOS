//
//  DSWalletViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 4/20/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSWalletTableViewCell.h"
#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSWalletViewController : UITableViewController <DSWalletTableViewCellDelegate>

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) DSChain *chain;

@end
