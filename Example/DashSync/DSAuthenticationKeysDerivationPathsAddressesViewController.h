//
//  DSAuthenticationKeysDerivationPathsAddressesViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 3/11/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSAuthenticationKeysDerivationPathsAddressesViewController : UITableViewController <NSFetchedResultsControllerDelegate,UISearchBarDelegate>

@property(nonatomic,strong) DSSimpleIndexedDerivationPath * derivationPath;

@end


NS_ASSUME_NONNULL_END
