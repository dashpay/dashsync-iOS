//
//  DSSporkManager.h
//  dashwallet
//
//  Created by Sam Westrich on 10/18/17.
//  Copyright © 2017 Aaron Voisine. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSSpork.h"

FOUNDATION_EXPORT NSString* _Nonnull const DSSporkManagerSporkUpdateNotification;

@class DSPeer;

@interface DSSporkManager : NSObject
    
@property (nonatomic,assign) BOOL instantSendActive;

+ (instancetype _Nullable)sharedInstance;

- (void)peer:(DSPeer * _Nullable)peer relayedSpork:(DSSpork * _Nonnull)spork;

@end
