//
//  DSMasternodeViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/10/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSMasternodeViewController : UITableViewController <NSFetchedResultsControllerDelegate, UISearchBarDelegate>

@property (nonatomic, strong) DSChain *chain;
// could be moved into rust lib [blockHash, masternodeMerkleRoot,]
@property (nonatomic, strong) DSMasternodeList *masternodeList;

@end
