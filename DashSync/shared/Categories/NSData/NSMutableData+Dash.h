//
//  NSMutableData+Dash.h
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 5/20/13.
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

#import "BigIntTypes.h"
#import "DSChain.h"

CF_IMPLICIT_BRIDGING_ENABLED

CFAllocatorRef SecureAllocator(void);

CF_IMPLICIT_BRIDGING_DISABLED

@class DSChain;

@interface NSMutableData (Dash)

+ (NSMutableData *)secureData;
+ (NSMutableData *)secureDataWithLength:(NSUInteger)length;
+ (NSMutableData *)secureDataWithCapacity:(NSUInteger)capacity;
+ (NSMutableData *)secureDataWithData:(NSData *)data;

+ (NSMutableData *)withScriptPubKeyForAddress:(NSString *)address forChain:(DSChain *)chain;

+ (NSMutableString *)secureString;
+ (NSMutableString *)secureStringWithLength:(NSUInteger)length;

+ (size_t)sizeOfVarInt:(uint64_t)i;

- (NSMutableData *)appendUInt8:(uint8_t)i;
- (NSMutableData *)appendUInt16:(uint16_t)i;
- (NSMutableData *)appendUInt16BigEndian:(uint16_t)i;
- (NSMutableData *)appendUInt32:(uint32_t)i;
- (NSMutableData *)appendInt64:(int64_t)i;
- (NSMutableData *)appendUInt64:(uint64_t)i;
- (NSMutableData *)appendUInt128:(UInt128)i;
- (NSMutableData *)appendUInt160:(UInt160)i;
- (NSMutableData *)appendUInt256:(UInt256)i;
- (NSMutableData *)appendUInt384:(UInt384)i;
- (NSMutableData *)appendUInt512:(UInt512)i;
- (NSMutableData *)appendUInt768:(UInt768)i;
- (NSMutableData *)appendUTXO:(DSUTXO)utxo;
- (NSMutableData *)appendVarInt:(uint64_t)i;
- (NSMutableData *)appendString:(NSString *)s;
- (NSMutableData *)appendCountedData:(NSData *)data;

- (NSMutableData *)appendDevnetGenesisCoinbaseMessage:(NSString *)message version:(uint16_t)version onProtocolVersion:(uint32_t)protocolVersion;
- (NSMutableData *)appendCoinbaseMessage:(NSString *)message atHeight:(uint32_t)height;

- (NSMutableData *)appendBitcoinScriptPubKeyForAddress:(NSString *)address forChain:(DSChain *)chain;
- (NSMutableData *)appendScriptPubKeyForAddress:(NSString *)address forChain:(DSChain *)chain;
- (NSMutableData *)appendCreditBurnScriptPubKeyForHashDataOfAddress:(NSData *)hashData forChain:(DSChain *)chain;
- (NSMutableData *)appendCreditBurnScriptPubKeyForAddress:(NSString *)address forChain:(DSChain *)chain;
- (NSMutableData *)appendScriptPushData:(NSData *)d;

- (NSMutableData *)appendShapeshiftMemoForAddress:(NSString *)address;
- (NSMutableData *)appendProposalInfo:(NSData *)proposalInfo;

- (NSMutableData *)appendMessage:(NSData *)message type:(NSString *)type forChain:(DSChain *)chain;
- (NSMutableData *)appendNullPaddedString:(NSString *)s length:(NSUInteger)length;
- (NSMutableData *)appendNetAddress:(uint32_t)address port:(uint16_t)port services:(uint64_t)services;

@end
