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
#import "DSAuthenticationManager+Private.h"
#import "DSBIP39Mnemonic.h"
#import "DSChainsManager.h"
#import "NSMutableData+Dash.h"
#import "DSChainManager.h"
#import "DSPeerManager.h"

#define COMPATIBILITY_MNEMONIC_KEY        @"mnemonic"
#define COMPATIBILITY_CREATION_TIME_KEY   @"creationtime"


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

- (BOOL)noOldWallet
{
    NSError *error = nil;
    if (hasKeychainData(EXTENDED_0_PUBKEY_KEY_BIP44_V1, &error) || error) return NO;
    if (hasKeychainData(EXTENDED_0_PUBKEY_KEY_BIP32_V1, &error) || error) return NO;
    if (hasKeychainData(EXTENDED_0_PUBKEY_KEY_BIP44_V0, &error) || error) return NO;
    if (hasKeychainData(EXTENDED_0_PUBKEY_KEY_BIP32_V0, &error) || error) return NO;
    return YES;
}

- (BOOL)clearKeychainWalletData {
    BOOL failed = NO;
    for (DSChain * chain in [[DSChainsManager sharedInstance] chains]) {
        [chain unregisterAllWallets];
    }
    failed = failed | [self clearKeychainWalletOldData];
    return failed;
}

- (BOOL)clearKeychainWalletOldData {
    BOOL failed = NO;
    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP44_V1, NO); //new keys
    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP32_V1, NO); //new keys
    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP44_V0, NO); //old keys
    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP32_V0, NO); //old keys
    return failed;
}

-(NSArray<DSWallet*>*)allWallets {
    NSMutableArray * wallets = [NSMutableArray array];
    for (DSChain * chain in [[DSChainsManager sharedInstance] chains]) {
        if ([chain hasAWallet]) {
            [wallets addObjectsFromArray:chain.wallets];
        }
    }
    return [wallets copy];
}


//there was an issue with extended public keys on version 0.7.6 and before, this fixes that
- (void)upgradeExtendedKeysForWallet:(DSWallet*)wallet chain:(DSChain *)chain withMessage:(NSString*)message withCompletion:(_Nullable UpgradeCompletionBlock)completion
{
    DSAccount * account = [wallet accountWithNumber:0];
    NSString * keyString = [[account bip44DerivationPath] walletBasedExtendedPublicKeyLocationString];
    NSError * error = nil;
    BOOL hasV2BIP44Data = keyString ? hasKeychainData(keyString, &error) : NO;
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
        DSDLog(@"fixing public key");
        //upgrade scenario
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:message andTouchId:NO alertIfLockout:NO completion:^(BOOL authenticated,BOOL cancelled) {
            if (!authenticated) {
                completion(NO,YES,NO,cancelled);
                return;
            }
            @autoreleasepool {
                NSString *seedPhraseKey = wallet.mnemonicUniqueID ?: COMPATIBILITY_MNEMONIC_KEY;
                NSString * seedPhrase = authenticated?getKeychainString(seedPhraseKey, nil):nil;
                if (!seedPhrase) {
                    completion(NO,YES,YES,NO);
                    return;
                }
                BOOL failed = NO;
                
                DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:seedPhrase setCreationDate:[self compatibleSeedCreationTime] forChain:chain storeSeedPhrase:YES isTransient:NO];
                NSParameterAssert(wallet);
                if (!wallet) {
                    failed = YES;
                }
                
                if (hasV0BIP44Data) {
                    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP44_V0, NO); //old keys
                    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP32_V0, NO); //old keys
                }
                if (hasV1BIP44Data) {
                    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP44_V1, NO); //old keys
                    failed = failed | !setKeychainData(nil, EXTENDED_0_PUBKEY_KEY_BIP32_V1, NO); //old keys
                }
                
                //update pin unlock time
                
                NSTimeInterval pinUnlockTimeSinceReferenceDate = [[NSUserDefaults standardUserDefaults] doubleForKey:PIN_UNLOCK_TIME_KEY];
                
                NSTimeInterval pinUnlockTimeSince1970 = [[NSDate dateWithTimeIntervalSinceReferenceDate:pinUnlockTimeSinceReferenceDate] timeIntervalSince1970];
                
                [[NSUserDefaults standardUserDefaults] setDouble:pinUnlockTimeSince1970
                                                          forKey:PIN_UNLOCK_TIME_KEY];
                
                //secure time
                
                NSTimeInterval secureTimeSinceReferenceDate = [DSAuthenticationManager sharedInstance].secureTime;
                
                NSTimeInterval secureTimeSince1970 = [[NSDate dateWithTimeIntervalSinceReferenceDate:secureTimeSinceReferenceDate] timeIntervalSince1970];
                
                [[DSAuthenticationManager sharedInstance] updateSecureTime:secureTimeSince1970];
                
                if ([[NSUserDefaults standardUserDefaults] objectForKey:SETTINGS_FIXED_PEER_KEY]) {
                    [wallet.chain.chainManager.peerManager setTrustedPeerHost:[[NSUserDefaults standardUserDefaults] objectForKey:SETTINGS_FIXED_PEER_KEY]];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SETTINGS_FIXED_PEER_KEY];
                }
                
                completion(!failed,YES,YES,NO);
                
            }
        }];
        
    } else {
        completion(YES,NO,NO,NO);
    }
}

- (NSTimeInterval)compatibleSeedCreationTime {
    NSData *d = getKeychainData(COMPATIBILITY_CREATION_TIME_KEY, nil);
    
    if (d.length == sizeof(NSTimeInterval)) {
        NSTimeInterval possibleCreationTime = *(const NSTimeInterval *)d.bytes;
        if (possibleCreationTime < BIP39_CREATION_TIME) {
            NSDate * date = [NSDate dateWithTimeIntervalSinceReferenceDate:possibleCreationTime];
            return [date timeIntervalSince1970];
        } else {
            return possibleCreationTime;
        }
    }
    return BIP39_CREATION_TIME;
}

@end
