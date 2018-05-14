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

-(DSChainPeerManager*)peerManagerForChain:(DSChain*)chain;

-(void)removeAllWalletsFromChains;

+ (instancetype _Nullable)sharedInstance;

@end
