//
//  DSBlockchainUser.m
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import "DSBlockchainUser.h"
#import "DSChain.h"

@interface DSBlockchainUser()

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) NSString * username;

@end

@implementation DSBlockchainUser

-(instancetype)initWithUsername:(NSString*)username onChain:(DSChain*)chain {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.chain = chain;
    return self;
}

@end
