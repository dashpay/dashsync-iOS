//
//  DSWalletConstants.m
//  DashSync
//
//  Created by Samuel Sutch on 6/3/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* const DSChainPeerManagerSyncStartedNotification =      @"DSChainPeerManagerSyncStartedNotification";
NSString* const DSChainPeerManagerSyncFinishedNotification =     @"DSChainPeerManagerSyncFinishedNotification";
NSString* const DSChainPeerManagerSyncFailedNotification =       @"DSChainPeerManagerSyncFailedNotification";
NSString* const DSChainPeerManagerTxStatusNotification =         @"DSChainPeerManagerTxStatusNotification";
NSString* const DSChainPeerManagerNotificationChainKey =         @"DSChainPeerManagerNotificationChainKey";
NSString* const DSChainWalletAddedNotification =    @"DSChainWalletAddedNotification";
NSString* const DSWalletBalanceChangedNotification =        @"DSWalletBalanceChangedNotification";
NSString* const DSSporkManagerSporkUpdateNotification =     @"DSSporkManagerSporkUpdateNotification";
NSString* const DSMasternodeListChangedNotification = @"DSMasternodeListChangedNotification";
NSString* const DSMasternodeListCountUpdateNotification = @"DSMasternodeListCountUpdateNotification";
