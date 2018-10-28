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

#define IDEO_SP   @"\xE3\x80\x80" // ideographic space (utf-8)

#define SHOWED_WARNING_FOR_INCOMPLETE_PASSPHRASE @"SHOWED_WARNING_FOR_INCOMPLETE_PASSPHRASE"

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
- (void)upgradeExtendedKeysForWallet:(DSWallet*)wallet withCompletion:(_Nullable UpgradeCompletionBlock)completion
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
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:(NSLocalizedString(@"please enter pin to upgrade wallet", nil)) andTouchId:NO alertIfLockout:NO completion:^(BOOL authenticated,BOOL cancelled) {
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

// There was an issue with passphrases not showing correctly on iPhone 5s and also on devices in Japanese
// (^CheckPassphraseCompletionBlock)(BOOL needsCheck,BOOL authenticated,BOOL cancelled,NSString * _Nullable seedPhrase)
-(void)checkPassphraseWasShownCorrectlyForWallet:(DSWallet*)wallet withCompletion:(CheckPassphraseCompletionBlock)completion
{
    DSAuthenticationManager * authenticationManager = [DSAuthenticationManager sharedInstance];
    NSTimeInterval seedCreationTime = wallet.walletCreationTime + NSTimeIntervalSince1970;
    NSError * error = nil;
    BOOL showedWarningForPassphrase = getKeychainInt(SHOWED_WARNING_FOR_INCOMPLETE_PASSPHRASE, &error);
    if (seedCreationTime < 1534266000 || showedWarningForPassphrase) {
        completion(NO,NO,NO,nil);
        return;
    }
    NSString *language = NSBundle.mainBundle.preferredLocalizations.firstObject;
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    [authenticationManager authenticateWithPrompt:(NSLocalizedString(@"Please enter pin to upgrade wallet", nil)) andTouchId:NO alertIfLockout:NO completion:^(BOOL authenticated,BOOL cancelled) {
        if (!authenticated) {
            completion(YES,NO,cancelled,nil);
            return;
        }
        @autoreleasepool {
            NSString * seedPhrase = wallet.seedPhraseIfAuthenticated;
            if (!seedPhrase) {
                setKeychainInt(1, SHOWED_WARNING_FOR_INCOMPLETE_PASSPHRASE, NO);
                completion(YES,YES,NO,seedPhrase);
                return;
            }
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineSpacing = 20;
            paragraphStyle.alignment = NSTextAlignmentCenter;
            NSInteger fontSize = 16;
            NSDictionary * attributes = @{NSFontAttributeName:[UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium],NSForegroundColorAttributeName:[UIColor whiteColor],NSParagraphStyleAttributeName:paragraphStyle};
            
            if (seedPhrase.length > 0 && [seedPhrase characterAtIndex:0] > 0x3000) { // ideographic language
                NSInteger lineCount = 1;
                NSMutableString *s,*l;
                
                CGRect r;
                s = CFBridgingRelease(CFStringCreateMutable(SecureAllocator(), 0)),
                l = CFBridgingRelease(CFStringCreateMutable(SecureAllocator(), 0));
                for (NSString *w in CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(),
                                                                                             (CFStringRef)seedPhrase, CFSTR(" ")))) {
                    if (l.length > 0) [l appendString:IDEO_SP];
                    [l appendString:w];
                    r = [l boundingRectWithSize:CGRectInfinite.size options:NSStringDrawingUsesLineFragmentOrigin
                                     attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium]} context:nil];
                    
                    if (r.size.width >= screenRect.size.width - 54*2 - 16) {
                        [s appendString:@"\n"];
                        l.string = w;
                        lineCount++;
                    }
                    else if (s.length > 0) [s appendString:IDEO_SP];
                    
                    [s appendString:w];
                }
                if (lineCount > 3) {
                    setKeychainInt(1, SHOWED_WARNING_FOR_INCOMPLETE_PASSPHRASE, NO);
                    completion(YES,YES,NO,seedPhrase);
                    return;
                }
            }
            
            else {
                NSInteger lineCount = 0;
                
                attributes = @{NSFontAttributeName:[UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium],NSForegroundColorAttributeName:[UIColor whiteColor],NSParagraphStyleAttributeName:paragraphStyle};
                CGSize labelSize = (CGSize){screenRect.size.width - 54*2 - 16, MAXFLOAT};
                CGRect requiredSize = [seedPhrase boundingRectWithSize:labelSize  options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil];
                long charSize = lroundf(((UIFont*)attributes[NSFontAttributeName]).lineHeight + 12);
                long rHeight = lroundf(requiredSize.size.height);
                lineCount = rHeight/charSize;
                
                if (lineCount > 3) {
                    setKeychainInt(1, SHOWED_WARNING_FOR_INCOMPLETE_PASSPHRASE, NO);
                    completion(YES,YES,NO,seedPhrase);
                    return;
                    
                }
                
            }
            setKeychainInt(1, SHOWED_WARNING_FOR_INCOMPLETE_PASSPHRASE, NO);
            completion(NO,YES,NO,seedPhrase);
            
        }
    }];
    
}

@end
