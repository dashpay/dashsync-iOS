//
//  DSClaimMasternodeViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 6/15/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DashSync/DashSync.h>

@interface DSClaimMasternodeViewController : UIViewController

@property (nonatomic,strong) DSMasternodeBroadcast * masternode;
@property (nonatomic,strong) DSChain * chain;

@end
