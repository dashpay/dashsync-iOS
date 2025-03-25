//
//  NSData+DSHash.m
//  DashSync
//
//  Created by Quantum Explorer on 01/31/17.
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

#import "dash_spv_apple_bindings.h"
#import "DSKeyManager.h"
#import "NSData+DSHash.h"

@implementation NSData (DSHash)

- (NSData *)blake3Data {
    Slice_u8 *slice = slice_ctor(self);
    u256 *result = dash_spv_crypto_blake3(slice);
    NSData *data = NSDataFromPtr(result);
    u256_dtor(result);
    return data;
}


- (UInt256)blake3 {
    return self.blake3Data.UInt256;
}

- (UInt256)blake3_2 {
    return self.blake3Data.blake3Data.UInt256;
}

//TODO: call this only when necessary (heavy op)
- (UInt256)x11 {
    return [DSKeyManager x11:self];
}

@end
