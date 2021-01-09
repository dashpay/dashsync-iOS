//
//  DSFundsDerivationPathsAddressesViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSIdentityAuthenticationDerivationPathsAddressesViewController : UITableViewController <NSFetchedResultsControllerDelegate, UISearchBarDelegate>

@property (nonatomic, strong) DSAuthenticationKeysDerivationPath *derivationPath;

@end
