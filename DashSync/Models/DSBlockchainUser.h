//
//  DSBlockchainUser.h
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import <Foundation/Foundation.h>

@class DSChain;

@interface DSBlockchainUser : NSObject

@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSString * username;

-(instancetype)initWithUsername:(NSString*)username onChain:(DSChain*)chain;

@end
