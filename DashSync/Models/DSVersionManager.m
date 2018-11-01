//
//  DSVersionManager.m
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import "DSVersionManager.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "DSWallet.h"
#import "DSAccount.h"
#import "DSAuthenticationManager.h"
#import "DSBIP39Mnemonic.h"
#import "DSChainManager.h"
#import "NSMutableData+Dash.h"

@implementation DSVersionManager

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

- (BOOL)hasAOldWallet
{
    NSError *error = nil;
    if (getKeychainData(EXTENDED_0_PUBKEY_KEY_BIP44_V1, &error) || error) return NO;
    if (getKeychainData(EXTENDED_0_PUBKEY_KEY_BIP32_V1, &error) || error) return NO;
    if (getKeychainData(EXTENDED_0_PUBKEY_KEY_BIP44_V0, &error) || error) return NO;
    if (getKeychainData(EXTENDED_0_PUBKEY_KEY_BIP32_V0, &error) || error) return NO;
    return YES;
}

- (void)clearKeychainWalletData {
    BOOL failed = NO;
    for (DSWallet * wallet in [self allWallets]) {
        for (DSAccount * account in wallet.accounts) {
            for (DSDerivationPath * derivationPath in account.derivationPaths) {
                failed = failed | !setKeychainData(nil, [derivationPath walletBasedExtendedPublicKeyLocationString], NO);
            }
        }
    }
    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP44_V1, NO); //new keys
    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP32_V1, NO); //new keys
    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP44_V0, NO); //old keys
    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP32_V0, NO); //old keys
}

-(NSArray<DSWallet*>*)allWallets {
    NSMutableArray * wallets = [NSMutableArray array];
    for (DSChain * chain in [[DSChainManager sharedInstance] chains]) {
        if ([chain hasAWallet]) {
            [wallets addObjectsFromArray:chain.wallets];
        }
    }
    return [wallets copy];
}


//there was an issue with extended public keys on version 0.7.6 and before, this fixes that
- (void)upgradeExtendedKeysForWallet:(DSWallet*)wallet withMessage:(NSString*)message withCompletion:(_Nullable UpgradeCompletionBlock)completion
{
    DSAccount * account = [wallet accountWithNumber:0];
    NSString * keyString = [[account bip44DerivationPath] walletBasedExtendedPublicKeyLocationString];
    NSError * error = nil;
    BOOL hasV2BIP44Data = hasKeychainData(keyString, &error);
    if (error) {
        completion(NO,NO,NO,NO);
        return;
    }
    error = nil;
    BOOL hasV1BIP44Data = (hasV2BIP44Data)?NO:hasKeychainData(EXTENDED_0_PUBKEY_KEY_BIP44_V1, &error);
    if (error) {
        completion(NO,NO,NO,NO);
        return;
    }
    BOOL hasV0BIP44Data = (hasV2BIP44Data)?NO:hasKeychainData(EXTENDED_0_PUBKEY_KEY_BIP44_V0, nil);
    if (!hasV2BIP44Data && (hasV1BIP44Data || hasV0BIP44Data)) {
        NSLog(@"fixing public key");
        //upgrade scenario
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:message andTouchId:NO alertIfLockout:NO completion:^(BOOL authenticated,BOOL cancelled) {
            if (!authenticated) {
                completion(NO,YES,NO,cancelled);
                return;
            }
            @autoreleasepool {
                NSString * seedPhrase = authenticated?getKeychainString(wallet.mnemonicUniqueID, nil):nil;
                if (!seedPhrase) {
                    completion(NO,YES,YES,NO);
                    return;
                }
                NSData * derivedKeyData = (seedPhrase) ?[[DSBIP39Mnemonic sharedInstance]
                                                         deriveKeyFromPhrase:seedPhrase withPassphrase:nil]:nil;
                BOOL failed = NO;
                for (DSAccount * account in wallet.accounts) {
                    for (DSDerivationPath * derivationPath in account.derivationPaths) {
                        NSData * data = [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:wallet.uniqueID];
                        failed = failed | !setKeychainData(data, [derivationPath walletBasedExtendedPublicKeyLocationString], NO);
                    }
                }
                if (hasV0BIP44Data) {
                    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP44_V1, NO); //old keys
                    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP32_V1, NO); //old keys
                }
                if (hasV1BIP44Data) {
                    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP44_V0, NO); //old keys
                    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP32_V0, NO); //old keys
                }
                
                completion(!failed,YES,YES,NO);
                
            }
        }];
        
    } else {
        completion(YES,NO,NO,NO);
    }
}

@end
