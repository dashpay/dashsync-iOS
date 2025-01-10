//
//  DSMasternodeDetailViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 2/21/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSKeyManager.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSLocalMasternode, DSChain;

@interface DSMasternodeDetailViewController : UITableViewController

@property (nonatomic, strong) DSLocalMasternode *localMasternode;
@property (nonatomic, assign) DMasternodeEntry *simplifiedMasternodeEntry;
@property (nonatomic, strong) DSChain *chain;


@end

NS_ASSUME_NONNULL_END
