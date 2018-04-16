//
//  DSDashSync.h
//  dashsync
//
//  Created by Sam Westrich on 3/4/18.
//  Copyright © 2018 dashcore. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DSPeerManager.h"
#import "DSWalletManager.h"
#import "DSEventManager.h"
#import "DSShapeshiftManager.h"

//! Project version number for dashsync.
FOUNDATION_EXPORT double DashSyncVersionNumber;

//! Project version string for dashsync.
FOUNDATION_EXPORT const unsigned char DashSyncVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <dashsync/PublicHeader.h>

typedef NS_ENUM(NSUInteger, DSSyncType) {
    DSSyncTypeNone = 0,
    DSSyncTypeSPV = 1,
    DSSyncTypeFullBlocks = 1 << 1,
    DSSyncTypeGovernance = 1 << 2,
    DSSyncTypeSporks = 1 << 3,
    DSSyncTypeDefault = DSSyncTypeSPV | DSSyncTypeGovernance | DSSyncTypeSporks,
};

@interface DashSync : NSObject

@property (nonatomic,assign) BOOL deviceIsJailbroken;
@property (nonatomic,assign) DSSyncType syncType;

+ (instancetype _Nullable)sharedSyncController;

-(void)startSync;
-(void)stopSync;

-(void)addSyncType:(DSSyncType)syncType;
-(void)clearSyncType:(DSSyncType)syncType;

-(void)wipeBlockchainData;

-(uint64_t)dbSize;


@end
