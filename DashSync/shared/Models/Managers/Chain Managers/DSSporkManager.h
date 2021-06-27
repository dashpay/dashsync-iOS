//
//  DSSporkManager.h
//  DashSync
//
//  Created by Sam Westrich on 10/18/17.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

#import "DSPeer.h"
#import "DSSpork.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DSSporkListDidUpdateNotification;

@class DSPeer, DSChain;

@interface DSSporkManager : NSObject <DSPeerSporkDelegate>

@property (nonatomic, readonly) NSTimeInterval lastRequestedSporks;      //this is the time after a successful spork sync, this is not persisted between sessions
@property (nonatomic, readonly) NSTimeInterval lastSyncedSporks;         //this is the time after a successful spork sync, this is not persisted between sessions
@property (nonatomic, readonly) BOOL instantSendActive;                  //spork 2
@property (nonatomic, readonly) BOOL deterministicMasternodeListEnabled; //spork 15
@property (nonatomic, readonly) BOOL llmqInstantSendEnabled;             // spork 20
@property (nonatomic, readonly) BOOL quorumDKGEnabled;                   // spork 17
@property (nonatomic, readonly) BOOL chainLocksEnabled;                  // spork 19

@property (nonatomic, readonly) NSDictionary *sporkDictionary;
@property (nonatomic, readonly) DSChain *chain;

@end

NS_ASSUME_NONNULL_END
