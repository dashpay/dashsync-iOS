//
//  DSDAPIPeerManager.h
//  DashSync
//
//  Created by Sam Westrich on 9/12/18.
//

#import <Foundation/Foundation.h>
#import "DSDAPIProtocol.h"

@class DSChainPeerManager;

@interface DSDAPIPeerManager : NSObject <DSDAPIProtocol>

@property (nonatomic,weak) DSChainPeerManager * chainPeerManager; //owned by chainPeerManager

-(instancetype)initWithChainPeerManager:(DSChainPeerManager*)chainPeerManager;

@end
