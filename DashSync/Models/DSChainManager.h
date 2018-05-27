//
//  DSChainManager.h
//  DashSync
//
//  Created by Sam Westrich on 5/6/18.
//

#import <Foundation/Foundation.h>
#import "DSChainPeerManager.h"

@interface DSChainManager : NSObject

@property (nonatomic,strong) DSChainPeerManager * mainnetManager;
@property (nonatomic,strong) DSChainPeerManager * testnetManager;
@property (nonatomic,strong) NSArray * devnetManagers;
@property (nonatomic,readonly) NSArray * chains;
@property (nonatomic,readonly) NSArray * devnetChains;

-(DSChainPeerManager*)peerManagerForChain:(DSChain*)chain;

+ (instancetype _Nullable)sharedInstance;

-(void)resetSpendingLimits;

@end
