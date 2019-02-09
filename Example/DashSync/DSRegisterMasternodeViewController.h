//
//  DSRegisterMasternodeViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 2/9/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DSAccountChooserViewController.h"
#import "DSWalletChooserViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSRegisterMasternodeViewController : UITableViewController <DSAccountChooserDelegate,DSWalletChooserDelegate>

@property (nonatomic,strong) DSChain * chain;

@end

NS_ASSUME_NONNULL_END
