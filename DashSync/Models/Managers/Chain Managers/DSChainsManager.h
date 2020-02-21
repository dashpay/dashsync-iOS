//
//  DSChainsManager.h
//  DashSync
//
//  Created by Sam Westrich on 5/6/18.
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

#import <Foundation/Foundation.h>
#import "DSChainManager.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString* const DSChainsDidChangeNotification;

@interface DSChainsManager : NSObject

@property (nonatomic,strong) DSChainManager * mainnetManager;
@property (nonatomic,strong) DSChainManager * testnetManager;
@property (nonatomic,strong) NSArray * devnetManagers;
@property (nonatomic,readonly) BOOL hasAWallet;
@property (nonatomic,readonly) NSArray * allWallets;
@property (nonatomic,readonly) NSArray * chains;
@property (nonatomic,readonly) NSArray * devnetChains;

-(DSChainManager * _Nullable)chainManagerForChain:(DSChain*)chain;

-(void)updateDevnetChain:(DSChain *)chain forServiceLocations:(NSMutableOrderedSet<NSString*> *)serviceLocations  standardPort:(uint32_t)standardPort dapiPort:(uint32_t)dapiPort protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString* _Nullable)sporkAddress sporkPrivateKey:(NSString * _Nullable)sporkPrivateKey;

-(DSChain* _Nullable)registerDevnetChainWithIdentifier:(NSString *)identifier forServiceLocations:(NSMutableOrderedSet<NSString*> * )serviceLocations standardPort:(uint32_t)standardPort dapiPort:(uint32_t)dapiPort  protocolVersion:(uint32_t)protocolVersion minProtocolVersion:(uint32_t)minProtocolVersion sporkAddress:(NSString * _Nullable)sporkAddress sporkPrivateKey:(NSString * _Nullable)sporkPrivateKey;

-(void)removeDevnetChain:(DSChain *)chain;

+(instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
