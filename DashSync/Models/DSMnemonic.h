//
//  DSMnemonic.h
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 8/15/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DSMnemonic<NSObject>
@required

- (NSString * _Nullable)encodePhrase:(NSData * _Nullable)data;
- (NSData * _Nullable)decodePhrase:(NSString *)phrase; // phrase must be normalized
- (BOOL)wordIsValid:(NSString *)word; // true if word is a member of any known word list
- (BOOL)wordIsLocal:(NSString *)word; // true if word is a member of the word list for the current locale
- (BOOL)phraseIsValid:(NSString *)phrase; // true if all words and checksum are valid, phrase must be normalized
- (NSString *)cleanupPhrase:(NSString *)phrase; // minimally cleans up user input phrase, suitable for display/editing
- (NSString * _Nullable)normalizePhrase:(NSString * _Nullable)phrase; // normalizes phrase, suitable for decode/derivation
- (NSData *)deriveKeyFromPhrase:(NSString *)phrase withPassphrase:(NSString * _Nullable)passphrase; // phrase must be normalized

@end

NS_ASSUME_NONNULL_END
