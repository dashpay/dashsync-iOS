//
//  DSBlockchainUser.m
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import "DSBlockchainUser.h"
#import "DSChain.h"
#import "DSKey.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSCoder+Dash.h"
#import "DSBlockchainUserRegistrationTransaction.h"

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

-(void)registerBlockchainUser:(void (^ _Nullable)(BOOL registered))completion {
    self.wallet.seedRequestBlock(@"Generate Blockchain User", 0,^void (NSData * _Nullable seed) {
        if (!seed) {
            completion(NO);
            return;
        }
        DSDerivationPath * derivationPath = [DSDerivationPath blockchainUsersDerivationPathForWallet:self.wallet];
        [derivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
        [self.wallet registerBlockchainUser:self];
        completion(YES);
    });
}

-(void)registrationTransactionFundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction))completion {
    self.wallet.seedRequestBlock(@"Generate Blockchain User", 0,^void (NSData * _Nullable seed) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSDerivationPath * derivationPath = [DSDerivationPath blockchainUsersDerivationPathForWallet:self.wallet];
        DSKey * privateKey = [derivationPath privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];

        DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = [[DSBlockchainUserRegistrationTransaction alloc] initWithBlockchainUserRegistrationTransactionVersion:1 username:self.username pubkeyHash:[privateKey.publicKey hash160] onChain:self.wallet.chain];
        [fundingAccount fundSpecialTransaction:blockchainUserRegistrationTransaction isInstant:FALSE];
        [blockchainUserRegistrationTransaction signPayloadWithKey:privateKey];
        completion(blockchainUserRegistrationTransaction);
    });
    
}

@end
