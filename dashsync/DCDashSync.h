//
//  DCDashSync.h
//  dashsync
//
//  Created by Sam Westrich on 3/4/18.
//  Copyright © 2018 dashcore. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BRPeerManager.h"
#import "BRWalletManager.h"
#import "BREventManager.h"
#import "DSShapeshiftManager.h"

//! Project version number for dashsync.
FOUNDATION_EXPORT double DashSyncVersionNumber;

//! Project version string for dashsync.
FOUNDATION_EXPORT const unsigned char DashSyncVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <dashsync/PublicHeader.h>

@interface DCDashSync : NSObject

+ (instancetype _Nullable)syncController;

@end
