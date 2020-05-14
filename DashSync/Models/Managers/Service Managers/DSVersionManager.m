//
//  DSVersionManager.m
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import "DSVersionManager.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "DSWallet+Protected.h"
#import "DSAccount.h"
#import "DSAuthenticationManager+UpdateSecureTime.h"
#import "DSBIP39Mnemonic.h"
#import "DSChainsManager.h"
#import "NSMutableData+Dash.h"
#import "DSChainManager.h"
#import "DSPeerManager.h"
#import "DSDerivationPathFactory.h"

#define COMPATIBILITY_MNEMONIC_KEY        @"mnemonic"
#define COMPATIBILITY_CREATION_TIME_KEY   @"creationtime"

#define AUTHENTICATION_TIME_VALUES_MIGRATED @"AUTHENTICATION_TIME_VALUES_MIGRATED_V2"

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
- (void)upgradeVersion1ExtendedKeysForWallet:(nullable DSWallet*)wallet chain:(DSChain *)chain withMessage:(NSString*)message withCompletion:(UpgradeCompletionBlock)completion
{
    NSParameterAssert(chain);
    NSParameterAssert(message);
    NSParameterAssert(completion);
    
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
        
        BOOL authTimeMigrated = getKeychainInt(AUTHENTICATION_TIME_VALUES_MIGRATED, nil);
        if (!authTimeMigrated) {
            //update pin unlock time
            
            NSTimeInterval pinUnlockTimeSinceReferenceDate = [[NSUserDefaults standardUserDefaults] doubleForKey:PIN_UNLOCK_TIME_KEY];
            
            NSTimeInterval pinUnlockTimeSince1970 = [[NSDate dateWithTimeIntervalSinceReferenceDate:pinUnlockTimeSinceReferenceDate] timeIntervalSince1970];
            
            [[NSUserDefaults standardUserDefaults] setDouble:pinUnlockTimeSince1970
                                                      forKey:PIN_UNLOCK_TIME_KEY];
            
            //secure time
            
            if (![DSAuthenticationManager sharedInstance].secureTimeUpdated) {
                NSTimeInterval secureTimeSinceReferenceDate = [DSAuthenticationManager sharedInstance].secureTime;
                
                NSTimeInterval secureTimeSince1970 = [[NSDate dateWithTimeIntervalSinceReferenceDate:secureTimeSinceReferenceDate] timeIntervalSince1970];
                
                [[DSAuthenticationManager sharedInstance] updateSecureTime:secureTimeSince1970];
            }
            
            setKeychainInt(1, AUTHENTICATION_TIME_VALUES_MIGRATED, NO);
        }
        
        //upgrade scenario
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:message usingBiometricAuthentication:NO alertIfLockout:NO completion:^(BOOL authenticated, BOOL usedBiometrics, BOOL cancelled) {

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

// upgrades extended keys for new/existing derivation paths
- (void)upgradeExtendedKeysForWallets:(NSArray*)wallets withMessage:(NSString*)message withCompletion:(UpgradeCompletionBlock)completion
{
    NSParameterAssert(wallets);
    NSParameterAssert(message);
    NSParameterAssert(completion);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL upgradeNeeded = NO;
        __block BOOL success = YES;
        __block BOOL authenticated = NO;
        __block BOOL cancelledAuth = NO;
        for (DSWallet * wallet in wallets) {
            NSArray * derivationPaths = [[DSDerivationPathFactory sharedInstance] unloadedSpecializedDerivationPathsNeedingExtendedPublicKeyForWallet:wallet];
            if (derivationPaths.count) {
                //upgrade scenario
                upgradeNeeded = YES;
                
                dispatch_semaphore_t sem = dispatch_semaphore_create(0);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[DSAuthenticationManager sharedInstance] seedWithPrompt:message forWallet:wallet forAmount:0 forceAuthentication:NO completion:^(NSData * _Nullable seed, BOOL cancelled) {
                        if (!seed) {
                            success = NO;
                            cancelledAuth = YES;
                            dispatch_semaphore_signal(sem);
                            return;
                        }
                        authenticated = YES;
                        @autoreleasepool {
                            
                            for (DSDerivationPath * derivationPath in derivationPaths) {
                                success &= !![derivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:wallet.uniqueIDString];
                            }
                            
                        }
                        dispatch_semaphore_signal(sem);
                    }];
                });
                dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
                if (!success) break;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success,upgradeNeeded,authenticated,cancelledAuth);
        });
    });
    
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
