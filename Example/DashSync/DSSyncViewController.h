//
//  DSExampleViewController.h
//  DashSync
//
//  Created by Andrew Podkovyrin on 03/19/2018.
//  Copyright (c) 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>

@import UIKit;

@interface DSSyncViewController : UITableViewController

@property (nonatomic,strong) DSPeerManager * chainPeerManager;

@end
