//
//  DSContactsViewController.h
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 08/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSFetchedResultsTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChainManager;
@class DSBlockchainIdentity;

@interface DSContactsViewController : DSFetchedResultsTableViewController

@property (nonatomic,strong) DSChainManager *chainManager;
@property (strong, nonatomic) DSBlockchainIdentity *blockchainIdentity;

@end

NS_ASSUME_NONNULL_END
