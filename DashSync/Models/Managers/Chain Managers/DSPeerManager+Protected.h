//
//  DSPeerManager+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
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

#import "DSPeerManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSPeerManagerDesiredState) {
    DSPeerManagerDesiredState_Unknown = -1,
    DSPeerManagerDesiredState_Connected = 1,
    DSPeerManagerDesiredState_Disconnected
};

#define MAX_CONNECT_FAILURES 20 // notify user of network problems after this many connect failures in a row

@interface DSPeerManager (Protected)

@property (nonatomic, readonly) NSUInteger connectFailures, misbehavingCount, maxConnectCount;
@property (nonatomic, readonly) NSSet *connectedPeers;
@property (nonatomic, readonly) DSPeerManagerDesiredState desiredState;

- (void)peerMisbehaving:(DSPeer *)peer;
- (void)syncStopped;
- (void)updateFilterOnPeers;

- (void)disconnectDownloadPeerWithCompletion:(void (^ _Nullable)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END

