//
//  DSBlockchainExplorerViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>

typedef NS_ENUM(uint16_t, DSBlockchainExplorerType) {
    DSBlockchainExplorerType_All,
    DSBlockchainExplorerType_Headers,
    DSBlockchainExplorerType_Blocks,
};

@interface DSBlockchainExplorerViewController : UITableViewController <NSFetchedResultsControllerDelegate,UISearchBarDelegate>

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,assign) DSBlockchainExplorerType type;

@end
