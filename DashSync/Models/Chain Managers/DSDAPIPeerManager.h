//
//  DSDAPIPeerManager.h
//  DashSync
//
//  Created by Sam Westrich on 9/12/18.
//

#import <Foundation/Foundation.h>
#import "DSDAPIProtocol.h"

@class DSPeerManager;

@interface DSDAPIPeerManager : NSObject <DSDAPIProtocol>

@property (nonatomic,weak) DSPeerManager * chainPeerManager; //owned by chainPeerManager

-(instancetype)initWithChainPeerManager:(DSPeerManager*)chainPeerManager;

@end
