//
//  DSFundsDerivationPathsAddressesViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>
#import <CoreData/CoreData.h>

@interface DSIdentityAuthenticationDerivationPathsAddressesViewController : UITableViewController <NSFetchedResultsControllerDelegate,UISearchBarDelegate>

@property(nonatomic,strong) DSAuthenticationKeysDerivationPath * derivationPath;

@end
