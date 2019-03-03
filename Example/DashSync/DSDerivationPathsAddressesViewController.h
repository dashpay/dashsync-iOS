//
//  DSDerivationPathsAddressesViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/3/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>
#import <CoreData/CoreData.h>

@interface DSDerivationPathsAddressesViewController : UITableViewController <NSFetchedResultsControllerDelegate,UISearchBarDelegate>

@property(nonatomic,strong) DSFundsDerivationPath * derivationPath;

@end
