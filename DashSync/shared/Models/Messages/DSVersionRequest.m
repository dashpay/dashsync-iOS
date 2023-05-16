//  
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSPeer.h"
#import "DSVersionRequest.h"
#import "NSDate+Utils.h"
#import "NSMutableData+Dash.h"

@implementation DSVersionRequest

+ (instancetype)requestWithAddress:(UInt128)address
                              port:(uint16_t)port
                   protocolVersion:(uint32_t)protocolVersion
                          services:(uint64_t)services
                      standardPort:(uint32_t)standardPort
                        localNonce:(uint64_t)localNonce
                         userAgent:(NSString *)userAgent {
    return [[DSVersionRequest alloc] initWithAddress:address
                                                port:port
                                     protocolVersion:protocolVersion
                                            services:services
                                        standardPort:standardPort
                                          localNonce:localNonce
                                           userAgent:userAgent];
}

- (instancetype)initWithAddress:(UInt128)address
                           port:(uint16_t)port
                protocolVersion:(uint32_t)protocolVersion
                       services:(uint64_t)services
                   standardPort:(uint32_t)standardPort
                     localNonce:(uint64_t)localNonce
                      userAgent:(NSString *)userAgent {
    self = [super init];
    if (self) {
        _address = address;
        _port = port;
        _protocolVersion = protocolVersion;
        _services = services;
        _standardPort = standardPort;
        _localNonce = localNonce;
        _userAgent = userAgent;
    }
    return self;
}

- (NSString *)type {
    return MSG_VERSION;
}

- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    UInt128 address = self.address;
    uint16_t port = CFSwapInt16HostToBig(self.port);
    [msg appendUInt32:self.protocolVersion];                                            // version
    [msg appendUInt64:ENABLED_SERVICES];                                                // services
    [msg appendUInt64:[NSDate timeIntervalSince1970]];                                  // timestamp
    [msg appendUInt64:self.services];                                                   // services of remote peer
    [msg appendBytes:&address length:sizeof(address)];                                  // IPv6 address of remote peer
    [msg appendBytes:&port length:sizeof(port)];                                        // port of remote peer
    [msg appendNetAddress:LOCAL_HOST port:self.standardPort services:ENABLED_SERVICES]; // net address of local peer
    [msg appendUInt64:self.localNonce];                                                 // random nonce
    [msg appendString:self.userAgent];                                                  // user agent
    [msg appendUInt32:0];                                                               // last block received
    [msg appendUInt8:0];                                                                // relay transactions (no for SPV bloom filter mode)
    return msg;
}

@end
