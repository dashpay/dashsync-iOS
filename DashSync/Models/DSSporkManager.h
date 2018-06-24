//
//  DSSporkManager.h
//  dashwallet
//
//  Created by Sam Westrich on 10/18/17.
//  Copyright © 2017 Aaron Voisine. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DSSpork.h"

FOUNDATION_EXPORT NSString* _Nonnull const DSSporkListDidUpdateNotification;

@class DSPeer,DSChain;

@interface DSSporkManager : NSObject
    
@property (nonatomic,readonly) BOOL instantSendActive;

@property (nonatomic,readonly) NSDictionary * sporkDictionary;
@property (nonatomic,readonly) DSChain * chain;

-(instancetype)initWithChain:(DSChain*)chain;

- (void)peer:(DSPeer * _Nullable)peer relayedSpork:(DSSpork * _Nonnull)spork;

-(void)wipeSporkInfo;

@end
