//
//  DSRegisterMasternodeViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 2/9/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSAccountChooserViewController.h"
#import "DSSignPayloadViewController.h"
#import "DSWalletChooserViewController.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSRegisterMasternodeViewController : UITableViewController <DSAccountChooserDelegate, DSWalletChooserDelegate, DSSignPayloadDelegate>

@property (nonatomic, strong) DSChain *chain;

@end

NS_ASSUME_NONNULL_END
