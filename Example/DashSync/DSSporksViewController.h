//
//  DSSporksViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 5/29/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSSporksViewController : UITableViewController

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) NSMutableArray *sporksArray;

@end
