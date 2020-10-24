//
//  DSBIP39Mnemonic.m
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 3/21/14.
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
//  Updated by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSBIP39Mnemonic.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSFundsDerivationPath.h"
#import "DSInsightManager.h"
#import "NSString+MDCDamerauLevenshteinDistance.h"

#define WORDS @"BIP39Words"

#define IDEO_SP @"\xE3\x80\x80" // ideographic space (utf-8)

DSBIP39RecoveryWordConfidence const DSBIP39RecoveryWordConfidence_Max = 0;

// BIP39 is method for generating a deterministic wallet seed from a mnemonic phrase
// https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki

@interface DSBIP39Mnemonic ()

@property (nonatomic, strong) NSArray *words;
@property (nonatomic, strong) NSSet *allWords;
@property (nonatomic, strong) NSMutableDictionary *wordsForLanguages;

@end

@implementation DSBIP39Mnemonic

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

-(instancetype)init {
    self = [super init];
    if (self) {
        self.wordsForLanguages = [NSMutableDictionary dictionary];
    }
    
    return self;
}

-(void)setDefaultLanguage:(DSBIP39Language)defaultLanguage {
    self.words = nil;
    _defaultLanguage = defaultLanguage;
    [self words];
}

+ (NSArray*)availableLanguages {
    return @[
             @(DSBIP39Language_English),
             @(DSBIP39Language_French),
             @(DSBIP39Language_Italian),
             @(DSBIP39Language_Spanish),
             @(DSBIP39Language_ChineseSimplified),
             @(DSBIP39Language_Korean),
             @(DSBIP39Language_Japanese)
             ];
}

+(NSString*)identifierForLanguage:(DSBIP39Language)language {
    switch (language) {
        case DSBIP39Language_English:
            return @"en";
            break;
        case DSBIP39Language_French:
            return @"fr";
            break;
        case DSBIP39Language_Spanish:
            return @"es";
            break;
        case DSBIP39Language_Korean:
            return @"ko";
            break;
        case DSBIP39Language_Japanese:
            return @"ja";
            break;
        case DSBIP39Language_ChineseSimplified:
            return @"zh-Hans";
            break;
        case DSBIP39Language_Italian:
            return @"it";
            break;
        default:
            return @"en"; //return english as default
            break;
    }
}

-(NSString*)languageIdentifier {
    return [DSBIP39Mnemonic identifierForLanguage:self.defaultLanguage];
}

- (NSArray *)words
{
    if (! _words) {
        NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        if (self.defaultLanguage == DSBIP39Language_Default) {
            _words = [NSArray arrayWithContentsOfFile:[bundle pathForResource:WORDS ofType:@"plist"]];
        } else {
            _words = [NSArray arrayWithContentsOfFile:[bundle pathForResource:WORDS ofType:@"plist" inDirectory:nil forLocalization:[self languageIdentifier]]];
        }
    }
    return _words;
}

- (NSArray *)wordsForLanguage:(DSBIP39Language)language
{
    if (!self.wordsForLanguages[@(language)]) {
        NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        if (language == DSBIP39Language_Default) {
            self.wordsForLanguages[@(language)] = [NSArray arrayWithContentsOfFile:[bundle pathForResource:WORDS ofType:@"plist"]];
        } else {
            self.wordsForLanguages[@(language)] = [NSArray arrayWithContentsOfFile:[bundle pathForResource:WORDS ofType:@"plist" inDirectory:nil forLocalization:[DSBIP39Mnemonic identifierForLanguage:language]]];
        }
    }
    return self.wordsForLanguages[@(language)];
}

- (DSBIP39Language)bestFittingLanguageForWords:(NSArray*)words {
    NSMutableDictionary * languageCountDictionary = [NSMutableDictionary dictionary];
    for (NSString * word in words) {
        for (NSNumber * languageNumber in [self languagesOfWord:word]) {
            if (languageCountDictionary[languageNumber]) {
                languageCountDictionary[languageNumber] = @([languageCountDictionary[languageNumber] integerValue] + 1);
            } else {
                languageCountDictionary[languageNumber] = @(1);
            }
        }
    }
    DSBIP39Language bestFittingLanguage = DSBIP39Language_Unknown;
    NSUInteger max = [[[languageCountDictionary allValues] valueForKeyPath:@"@max.intValue"] unsignedIntegerValue];
    for (NSNumber * language in languageCountDictionary) {
        if ([languageCountDictionary[language] unsignedIntValue] == max) {
            bestFittingLanguage = [language unsignedIntegerValue];
        }
    }
    return bestFittingLanguage;
}

- (NSSet *)allWords
{
    if (! _allWords) {
        NSMutableSet *allWords = [NSMutableSet set];
        
        NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        for (NSString *lang in bundle.localizations) {
            [allWords addObjectsFromArray:[NSArray arrayWithContentsOfFile:[bundle
             pathForResource:WORDS ofType:@"plist" inDirectory:nil forLocalization:lang]]];
        }
        _allWords = allWords;
    }
    return _allWords;
}

- (NSString * _Nullable)encodePhrase:(NSData * _Nullable)data
{
    if (! data || (data.length % 4) != 0) return nil; // data length must be a multiple of 32 bits

    uint32_t n = (uint32_t)self.words.count, x;
    NSMutableArray *a =
        CFBridgingRelease(CFArrayCreateMutable(SecureAllocator(), data.length*3/4, &kCFTypeArrayCallBacks));
    NSMutableData *d = [NSMutableData secureDataWithData:data];
    UInt256 sha256 = data.SHA256;

    [d appendBytes:&sha256 length:sizeof(sha256)]; // append SHA256 checksum

    for (int i = 0; i < data.length*3/4; i++) {
        x = CFSwapInt32BigToHost(*(const uint32_t *)((const uint8_t *)d.bytes + i*11/8));
        [a addObject:self.words[(x >> (sizeof(x)*8 - (11 + ((i*11) % 8)))) % n]];
    }

    memset(&x, 0, sizeof(x));
    return CFBridgingRelease(CFStringCreateByCombiningStrings(SecureAllocator(), (CFArrayRef)a, CFSTR(" ")));
}

- (NSData * _Nullable)decodePhrase:(NSString *)phrase {
    return [self decodePhrase:phrase inLanguage:self.defaultLanguage];
}

// phrase must be normalized
- (NSData * _Nullable)decodePhrase:(NSString *)phrase inLanguage:(DSBIP39Language)language {
    NSParameterAssert(phrase);
    NSArray *wordArray = CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(),
                                   (CFStringRef)[self normalizePhrase:phrase], CFSTR(" ")));
    return [self decodeWordArray:wordArray inLanguage:language];
    
}

- (NSData * _Nullable)decodeWordArray:(NSArray *)wordArray inLanguage:(DSBIP39Language)language
{
    NSParameterAssert(wordArray);
    
    NSArray * words = nil;
    if (language == self.defaultLanguage) {
        words = self.words;
    } else {
        words = [self wordsForLanguage:language];
    }
    
    NSMutableData *d = [NSMutableData secureDataWithCapacity:(wordArray.count*11 + 7)/8];
    uint32_t n = (uint32_t)self.words.count, x, y;
    uint8_t b;
    
    uint32_t wordArrayCount = (uint32_t)wordArray.count;

    if ((wordArrayCount % 3) != 0 || wordArrayCount > 24) {
        #if DEBUG
        DSDLog(@"phrase has wrong number of words");
        #endif
        return nil;
    }

    for (int i = 0; i < (wordArrayCount*11 + 7)/8; i++) {
        x = (uint32_t)[words indexOfObject:wordArray[i*8/11]];
        y = (i*8/11 + 1 < wordArrayCount) ? (uint32_t)[words indexOfObject:wordArray[i*8/11 + 1]] : 0;

        if (x == (uint32_t)NSNotFound || y == (uint32_t)NSNotFound) {
#if DEBUG
            DSDLog(@"phrase contained unknown word: %@ in %lu", wordArray[i*8/11 + (x == (uint32_t)NSNotFound ? 0 : 1)],(unsigned long)language);
#endif
            return nil;
        }

        b = ((x*n + y) >> ((i*8/11 + 2)*11 - (i + 1)*8)) & 0xff;
        [d appendBytes:&b length:1];
    }

    b = *((const uint8_t *)d.bytes + wordArrayCount*4/3) >> (8 - wordArrayCount/3);
    d.length = wordArrayCount*4/3;

    if (b != (d.SHA256.u8[0] >> (8 - wordArrayCount/3))) {
//        DSDLog(@"incorrect phrase, bad checksum");
        return nil;
    }

    memset(&x, 0, sizeof(x));
    memset(&y, 0, sizeof(y));
    memset(&b, 0, sizeof(b));
    return d;
}

// true if word is a member of any known word list
- (BOOL)wordIsValid:(NSString *)word
{
    NSParameterAssert(word);
    return [self.allWords containsObject:word];
}

// returns an array of languages this word belongs to
- (NSArray<NSNumber*>*)languagesOfWord:(NSString *)word
{
    NSParameterAssert(word);
    NSMutableArray * validLanguageNumbers = [NSMutableArray array];
    for (NSNumber * languageNumber in [DSBIP39Mnemonic availableLanguages]) {
        DSBIP39Language language = [languageNumber unsignedIntValue];
        if (language == self.defaultLanguage) continue;
        if ([self wordIsValid:word inLanguage:language]) {
            [validLanguageNumbers addObject:languageNumber];
        }
    }
    return [validLanguageNumbers copy];
}

// true if word is a member of the word list for the current locale
- (BOOL)wordIsLocal:(NSString *)word
{
    NSParameterAssert(word);
    return [self.words containsObject:word];
}

// true if all words and checksum are valid, phrase must be normalized
- (BOOL)phraseIsValid:(NSString *)phrase
{
    NSParameterAssert(phrase);
    BOOL phraseValid = ([self decodePhrase:phrase] == nil) ? NO : YES;
    if (phraseValid) {
        return TRUE;
    } else {
        for (NSNumber * languageNumber in [DSBIP39Mnemonic availableLanguages]) {
            DSBIP39Language language = [languageNumber unsignedIntValue];
            if (language == self.defaultLanguage) continue;
            phraseValid |= [self phraseIsValid:phrase inLanguage:language];
            if (phraseValid) return TRUE;
        }
    }
    return FALSE;
}

// true if all words and checksum are valid, phrase must be normalized
- (BOOL)phraseIsValid:(NSString *)phrase inLanguage:(DSBIP39Language)language
{
    NSParameterAssert(phrase);
    return ([self decodePhrase:phrase inLanguage:language] == nil) ? NO : YES;
}

// true if all words and checksum are valid, phrase must be normalized
- (BOOL)wordArrayIsValid:(NSArray *)wordArray inLanguage:(DSBIP39Language)language
{
    NSParameterAssert(wordArray);
    return ([self decodeWordArray:wordArray inLanguage:language] == nil) ? NO : YES;
}

- (BOOL)wordIsValid:(NSString *)word inLanguage:(DSBIP39Language)language
{
    NSParameterAssert(word);
    NSArray * words = nil;
    if (language == self.defaultLanguage) {
        words = self.words;
    } else {
        words = [self wordsForLanguage:language];
    }
    return [words containsObject:word];
}


// minimally cleans up user input phrase, suitable for display/editing
- (NSString *)cleanupPhrase:(NSString *)phrase
{
    NSParameterAssert(phrase);
    
    static NSCharacterSet *invalid = nil, *ws = nil;
    static dispatch_once_t onceToken = 0;
    NSMutableString *s = CFBridgingRelease(CFStringCreateMutableCopy(SecureAllocator(), 0,
                                                                     (CFStringRef)phrase));
    
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [NSMutableCharacterSet letterCharacterSet];
        
        ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        [set formUnionWithCharacterSet:ws];
        invalid = set.invertedSet;
    });
    
    while ([s rangeOfCharacterFromSet:invalid].location != NSNotFound) {
        [s deleteCharactersInRange:[s rangeOfCharacterFromSet:invalid]]; // remove invalid chars
    }
    
    [s replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, s.length)];
    while ([s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, s.length)] > 0);
    while ([s rangeOfCharacterFromSet:ws].location == 0) [s deleteCharactersInRange:NSMakeRange(0, 1)]; // trim lead ws
    phrase = [self normalizePhrase:s];
    
    if (! [self phraseIsValid:phrase]) {
        NSArray *a = CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(),
                                                                              (CFStringRef)phrase, CFSTR(" ")));
        
        for (NSString *word in a) { // add spaces between words for ideographic langauges
            if (word.length < 1 || [word characterAtIndex:0] < 0x3000 || [self wordIsValid:word]) continue;
            
            for (NSUInteger i = 0; i < word.length; i++) {
                for (NSUInteger j = (word.length - i > 8) ? 8 : word.length - i; j; j--) {
                    NSString *w  = [word substringWithRange:NSMakeRange(i, j)];
                    
                    if (! [self wordIsValid:w]) continue;
                    [s replaceOccurrencesOfString:w withString:[NSString stringWithFormat:IDEO_SP @"%@" IDEO_SP, w]
                                          options:0 range:NSMakeRange(0, s.length)];
                    while ([s replaceOccurrencesOfString:IDEO_SP IDEO_SP withString:IDEO_SP options:0
                                                   range:NSMakeRange(0, s.length)] > 0);
                    CFStringTrimWhitespace((CFMutableStringRef)s);
                    i += j - 1;
                    break;
                }
            }
        }
    }
    
    return s;
}

// normalizes phrase, suitable for decode/derivation
- (NSString * _Nullable)normalizePhrase:(NSString * _Nullable)phrase
{
    if (! phrase) return nil;

    NSMutableString *s = CFBridgingRelease(CFStringCreateMutableCopy(SecureAllocator(), 0, (CFStringRef)phrase));
    NSMutableCharacterSet *ws = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    CFRange r;

    CFStringNormalize((CFMutableStringRef)s, kCFStringNormalizationFormKD);
    CFStringLowercase((CFMutableStringRef)s, CFLocaleGetSystem());
    CFStringTrimWhitespace((CFMutableStringRef)s);
    [ws removeCharactersInString:@" "];
    
    while (CFStringFindCharacterFromSet((CFStringRef)s, (CFCharacterSetRef)ws, CFRangeMake(0, s.length), 0, &r)) {
        [s replaceCharactersInRange:NSMakeRange(r.location, r.length) withString:@" "];
    }
    
    while ([s rangeOfString:@"  "].location != NSNotFound) {
        [s replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, s.length)];
    }
        
    return s;
}

- (NSData *)deriveKeyFromWordArray:(NSArray *)wordArray withPassphrase:(NSString * _Nullable)passphrase
{
    NSString *phrase = CFBridgingRelease(CFStringCreateByCombiningStrings(SecureAllocator(), (CFArrayRef)wordArray, CFSTR(" ")));
    return [self deriveKeyFromPhrase:phrase withPassphrase:passphrase];
}

// phrase must be normalized
- (NSData *)deriveKeyFromPhrase:(NSString *)phrase withPassphrase:(NSString * _Nullable)passphrase
{
    if (! phrase) return nil;
    
    NSMutableData *key = [NSMutableData secureDataWithLength:sizeof(UInt512)];
    NSData *password, *salt;
    CFMutableStringRef pw = CFStringCreateMutableCopy(SecureAllocator(), 0, (CFStringRef)phrase);
    CFMutableStringRef s = CFStringCreateMutableCopy(SecureAllocator(), 0, CFSTR("mnemonic"));

    if (passphrase) CFStringAppend(s, (CFStringRef)passphrase);
    CFStringNormalize(pw, kCFStringNormalizationFormKD);
    CFStringNormalize(s, kCFStringNormalizationFormKD);
    password = CFBridgingRelease(CFStringCreateExternalRepresentation(SecureAllocator(), pw, kCFStringEncodingUTF8, 0));
    salt = CFBridgingRelease(CFStringCreateExternalRepresentation(SecureAllocator(), s, kCFStringEncodingUTF8, 0));
    CFRelease(pw);
    CFRelease(s);

    PBKDF2(key.mutableBytes, key.length, SHA512, 64, password.bytes, password.length, salt.bytes, salt.length, 2048);
    return key;
}

- (void)findPotentialWordsOfMnemonicForPassphrase:(NSString*)passphrase replacementString:(NSString*)replacementCharacter progressUpdate:(void (^)(float, bool *))progress completion:(void (^)(NSDictionary <NSString*,NSNumber*>* missingWords))completion {
    [self findPotentialWordsOfMnemonicForPassphrase:passphrase replacementString:replacementCharacter inLanguage:DSBIP39Language_Unknown useDistanceAsBackup:YES progressUpdate:progress completion:completion completeInQueue:dispatch_get_main_queue()];
}

- (void)findLastPotentialWordsOfMnemonicForPassphrase:(NSString*)partialPassphrase progressUpdate:(void (^)(float, bool *))progress completion:(void (^)(NSDictionary <NSString*,NSNumber*>* missingWords))completion {
    [self findLastPotentialWordsOfMnemonicForPassphrase:partialPassphrase inLanguage:DSBIP39Language_Unknown progressUpdate:progress completion:completion completeInQueue:dispatch_get_main_queue()];
}

- (void)findLastPotentialWordsOfMnemonicForPassphrase:(NSString*)partialPassphrase inLanguage:(DSBIP39Language)language progressUpdate:(void (^)(float, bool *))progressUpdate completion:(void (^)(NSDictionary <NSString*,NSNumber*>* missingWords))completion completeInQueue:(dispatch_queue_t)dispatchQueue
{
    NSArray *words = CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(), (CFStringRef)[self normalizePhrase:partialPassphrase], CFSTR(" ")));
    NSString * passphraseWithXs = nil;
    if (words.count == 10) {
        passphraseWithXs = [partialPassphrase stringByAppendingString:@" x x"];
    } else {
        passphraseWithXs = [partialPassphrase stringByAppendingString:@" x"];
    }
    [self findPotentialWordsOfMnemonicForPassphrase:passphraseWithXs replacementString:@"x" inLanguage:language useDistanceAsBackup:NO progressUpdate:progressUpdate completion:completion completeInQueue:dispatchQueue];
}

- (void)findPotentialWordsOfMnemonicForPassphrase:(NSString*)partialPassphrase replacementString:(NSString*)replacementString inLanguage:(DSBIP39Language)language useDistanceAsBackup:(BOOL)useDistanceAsBackup progressUpdate:(void (^)(float, bool *))progressUpdate completion:(void (^)(NSDictionary <NSString*,NSNumber*>* missingWords))completion completeInQueue:(dispatch_queue_t)dispatchQueue
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        DSBIP39Mnemonic *m = [DSBIP39Mnemonic sharedInstance];
        NSMutableArray *words = CFBridgingRelease(CFStringCreateArrayBySeparatingStrings(SecureAllocator(), (CFStringRef)[self normalizePhrase:partialPassphrase], CFSTR(" ")));
        NSIndexSet *indexes = [words indexesOfObjectsPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj isEqualToString:replacementString];
        }];
        [words removeObjectsAtIndexes:indexes];
        DSBIP39Language checkLanguage = (language == DSBIP39Language_Unknown)?[self bestFittingLanguageForWords:words]:language;
        NSUInteger count = words.count;
        if (count == 10) {
            __block NSMutableDictionary * possibleWordArrays = [NSMutableDictionary dictionary];
            uint32_t i = 0;
            __block uint32_t completed = 0;
            float totalWords = [m wordsForLanguage:checkLanguage].count;
            dispatch_group_t dispatchGroup = dispatch_group_create();
            NSUInteger processorCount = MAX(1,[[NSProcessInfo processInfo] activeProcessorCount]);
            dispatch_semaphore_t dispatchSemaphore = dispatch_semaphore_create(MAX(1,processorCount - 1));
            __block bool stop = false;
            for (NSString * word in [m wordsForLanguage:checkLanguage]) {
                if (stop) break;
                @autoreleasepool {
                    NSMutableArray * checkingWords = [words mutableCopy];
                    [checkingWords insertObject:word atIndex:[indexes firstIndex]];
                    [checkingWords insertObject:replacementString atIndex:[indexes lastIndex]];
                    NSString *passphrase = CFBridgingRelease(CFStringCreateByCombiningStrings(SecureAllocator(), (CFArrayRef)checkingWords, CFSTR(" ")));
                    dispatch_group_enter(dispatchGroup);
                    dispatch_semaphore_wait(dispatchSemaphore, DISPATCH_TIME_FOREVER);
                    [self findPotentialWordsOfMnemonicForPassphrase:passphrase replacementString:replacementString inLanguage:checkLanguage useDistanceAsBackup:NO progressUpdate:^(float incProgress, bool * stop) {
                    } completion:^(NSDictionary <NSString*,NSNumber*>* secondWords) {
                        for (NSString * secondWord in secondWords) {
                            [possibleWordArrays setObject:@(DSBIP39RecoveryWordConfidence_Max) forKey:[NSString stringWithFormat:@"%@ %@",word,secondWord]];
                            stop = YES;
                        }
                        completed++;
                        progressUpdate(completed/totalWords, &stop);
                        dispatch_group_leave(dispatchGroup);
                        dispatch_semaphore_signal(dispatchSemaphore);
                    } completeInQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
                }
                i++;
            }
            dispatch_group_notify(dispatchGroup, dispatchQueue, ^{
                completion(possibleWordArrays);
            });
            return;
        } else if (count != 11) {
            return;
        }
    
        NSMutableDictionary * possibleWordAddresses = [NSMutableDictionary dictionary];
        NSArray <NSString*>* allWordsForLanguage = [m wordsForLanguage:checkLanguage];
        uint32_t totalWordCount = (uint32_t)[allWordsForLanguage count];
        uint32_t currentWordCount = 0;
        
        for (NSString * word in allWordsForLanguage) {
            if (currentWordCount % 10 == 9) {
                BOOL stop = NO;
                progressUpdate(currentWordCount/(float)totalWordCount,&stop);
                if (stop) {
                    return;
                }
            }
            NSMutableArray * passphraseWordArray = [words mutableCopy];
            [passphraseWordArray insertObject:word atIndex:[indexes firstIndex]];
            if ([m wordArrayIsValid:passphraseWordArray inLanguage:checkLanguage]) {
                NSData * data = [m deriveKeyFromWordArray:passphraseWordArray withPassphrase:nil];
                DSDerivationPath * derivationPath = [DSFundsDerivationPath bip44DerivationPathForAccountNumber:0 onChain:[DSChain mainnet]];
                [derivationPath generateExtendedPublicKeyFromSeed:data storeUnderWalletUniqueId:nil];
                NSUInteger indexArr[] = {0,0};
                NSString * firstAddress = [derivationPath addressAtIndexPath:[NSIndexPath indexPathWithIndexes:indexArr length:2]];
                [possibleWordAddresses setObject:word forKey:firstAddress];
            }
            currentWordCount++;
        }
        if (possibleWordAddresses.count == 0) {
            dispatch_async(dispatchQueue, ^{
                completion([NSDictionary dictionary]);
            });
        } else {
            [[DSInsightManager sharedInstance] findExistingAddresses:[possibleWordAddresses allKeys] onChain:[DSChain mainnet] completion:^(NSArray * _Nonnull addresses, NSError * _Nonnull error) {
                NSDictionary * reducedDictionary = [possibleWordAddresses dictionaryWithValuesForKeys:addresses];
                NSArray * perfectConfidenceWords = [reducedDictionary allValues];
                if (perfectConfidenceWords.count) {
                    NSMutableDictionary * possibleWordArrays = [NSMutableDictionary dictionary];
                    for (NSString * address in perfectConfidenceWords) {
                        [possibleWordArrays setObject:@(DSBIP39RecoveryWordConfidence_Max) forKey:address];
                    }
                    dispatch_async(dispatchQueue, ^{
                        completion(possibleWordArrays);
                    });
                } else if (useDistanceAsBackup) {
                    NSMutableDictionary * possibleWordArrays = [NSMutableDictionary dictionary];
                    for (NSString * potentialWord in [possibleWordAddresses allValues]) {
                        NSUInteger distance = [replacementString mdc_damerauLevenshteinDistanceTo:potentialWord];
                        if ([replacementString mdc_damerauLevenshteinDistanceTo:potentialWord] < 3) {
                            [possibleWordArrays setObject:@(distance) forKey:potentialWord];
                        }
                    }
                    dispatch_async(dispatchQueue, ^{
                        completion(possibleWordArrays);
                    });
                } else {
                    dispatch_async(dispatchQueue, ^{
                        completion([NSDictionary dictionary]);
                    });
                }
            }];
        }

    });
}

@end
