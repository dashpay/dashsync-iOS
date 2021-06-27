//
//  DSProposalCreatorViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 7/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSAccountChooserViewController.h"
#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSProposalCreatorViewController : UITableViewController <UITextFieldDelegate, DSAccountChooserDelegate>

@property (nonatomic, strong) DSChainManager *chainManager;

@end
