//
//  DSIncomingContactsTableViewController.h
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 15/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSBlockchainUser;

@interface DSIncomingContactsTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) DSBlockchainUser *blockchainUser;

@end

NS_ASSUME_NONNULL_END
