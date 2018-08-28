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
#import "NSMutableData+Dash.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSBlockchainUserCloseTransaction.h"
#import "DSAuthenticationManager.h"

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"

@interface DSBlockchainUser()

@property (nonatomic,strong) DSWallet * wallet;
@property (nonatomic,strong) NSString * username;
@property (nonatomic,strong) NSString * uniqueIdentifier;
@property (nonatomic,assign) uint32_t index;
@property (nonatomic,assign) UInt256 registrationTransactionHash;

@end

@implementation DSBlockchainUser

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.uniqueIdentifier = [NSString stringWithFormat:@"%@_%@",BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY,username];
    self.wallet = wallet;
    self.registrationTransactionHash = UINT256_ZERO;
    self.index = index;
    return self;
}

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet createdWithTransactionHash:(UInt256)registrationTransactionHash {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.uniqueIdentifier = [NSString stringWithFormat:@"%@_%@",BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY,username];
    self.wallet = wallet;
    self.registrationTransactionHash = registrationTransactionHash;
    self.index = index;
    return self;
}

-(void)generateBlockchainUserExtendedPublicKey:(void (^ _Nullable)(BOOL registered))completion {
    __block DSDerivationPath * derivationPath = [DSDerivationPath blockchainUsersDerivationPathForWallet:self.wallet];
    if (derivationPath.extendedPublicKey) {
        completion(YES);
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:@"Generate Blockchain User" forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData * _Nullable seed) {
        if (!seed) {
            completion(NO);
            return;
        }
        [derivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
        completion(YES);
    }];
}

-(void)registerInWallet {
    [self.wallet registerBlockchainUser:self];
}

-(void)registrationTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction))completion {
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:@"Topup Blockchain User" forWallet:self.wallet forAmount:topupAmount forceAuthentication:NO completion:^(NSData * _Nullable seed) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSDerivationPath * derivationPath = [DSDerivationPath blockchainUsersDerivationPathForWallet:self.wallet];
        DSKey * privateKey = [derivationPath privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];

        DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = [[DSBlockchainUserRegistrationTransaction alloc] initWithBlockchainUserRegistrationTransactionVersion:1 username:self.username pubkeyHash:[privateKey.publicKey hash160] onChain:self.wallet.chain];
        [blockchainUserRegistrationTransaction signPayloadWithKey:privateKey];
        NSMutableData * opReturnScript = [NSMutableData data];
        [opReturnScript appendUInt8:OP_RETURN];
        [fundingAccount updateTransaction:blockchainUserRegistrationTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO toShapeshiftAddress:nil];
        
        completion(blockchainUserRegistrationTransaction);
    }];
    
}

-(void)topupTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction))completion {
    self.wallet.seedRequestBlock(@"Topup Blockchain User", topupAmount,^void (NSData * _Nullable seed) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction = [[DSBlockchainUserTopupTransaction alloc] initWithBlockchainUserTopupTransactionVersion:1 registrationTransactionHash:self.registrationTransactionHash onChain:self.wallet.chain];
        
        NSMutableData * opReturnScript = [NSMutableData data];
        [opReturnScript appendUInt8:OP_RETURN];
        [fundingAccount updateTransaction:blockchainUserTopupTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO toShapeshiftAddress:nil];

        completion(blockchainUserTopupTransaction);
    });
    
}


@end
