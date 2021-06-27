//
//  DSClaimMasternodeViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/15/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSClaimMasternodeViewController : UIViewController

@property (nonatomic, strong) DSSimplifiedMasternodeEntry *masternode;
@property (nonatomic, strong) DSChain *chain;

@end
