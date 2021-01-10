//
//  DSAuthenticationKeysDerivationPathsAddressesViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 3/11/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSAuthenticationKeysDerivationPathsAddressesViewController : UITableViewController <NSFetchedResultsControllerDelegate, UISearchBarDelegate>

@property (nonatomic, strong) DSSimpleIndexedDerivationPath *derivationPath;

@end


NS_ASSUME_NONNULL_END
