//
//  DSBlockchainUser.m
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import "DSBlockchainUser.h"
#import "DSChain.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSCoder+Dash.h"

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"

@interface DSBlockchainUser()

@property (nonatomic,strong) DSWallet * wallet;
@property (nonatomic,strong) NSString * username;
@property (nonatomic,strong) NSString * uniqueIdentifier;
@property (nonatomic,assign) uint32_t index;

@end

@implementation DSBlockchainUser

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet; {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.uniqueIdentifier = [NSString stringWithFormat:@"%@_%@",BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY,username];
    self.wallet = wallet;
    self.index = index;
    return self;
}

-(void)registerBlockchainUserAtIndex:(uint32_t)index {
    [self.wallet registerBlockchainUser:self];
    self.wallet.seedRequestBlock(@"Generate Blockchain User", 0,^void (NSData * _Nullable seed) {
        DSDerivationPath * derivationPath = [DSDerivationPath blockchainUsersDerivationPathForWallet:self.wallet];
        [derivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
    });

}

@end
