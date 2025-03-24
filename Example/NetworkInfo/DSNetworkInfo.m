//  
//  Created by Sam Westrich
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "DSNetworkInfo.h"
#import <DashSync/DashSync.h>
#import "DSChain+Protected.h"
#import "DSWallet+Tests.h"

@interface DSNetworkInfo ()

@property (strong, nonatomic) DSChain *mainnetChain;
@property (strong, nonatomic) DSWallet *mainnetWallet;
@property (strong, nonatomic) DSChain *testnetChain;
@property (strong, nonatomic) DSWallet *testnetWallet;
@property (strong, nonatomic) id mnListMainnetStatusObserver, mnListTestnetStatusObserver;

@end

@implementation DSNetworkInfo

- (id)init {
    if (!(self = [super init])) return nil;
//    self.mainnetChain = [DSChain mainnet];
//    self.mainnetWallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.mainnetChain storeSeedPhrase:NO isTransient:YES];
//    [self.mainnetChain unregisterAllWallets];
//    [self.mainnetChain addWallet:self.mainnetWallet];
    
    self.testnetChain = [DSChain testnet];
    [self.testnetChain unregisterAllWallets];
    self.testnetWallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.testnetChain storeSeedPhrase:YES isTransient:NO];
    [self.testnetChain addWallet:self.testnetWallet];
    return self;
}

+ (NSURL *)applicationDocumentsDirectory
{
     return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

-(void)getTestnetInfo:(NSString*)outputDirectory {
    [[DashSync sharedSyncController] wipePeerDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    [[DashSync sharedSyncController] wipeSporkDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    
    void (^currentMasternodeListDidChangeBlock)(NSNotification *note) = ^(NSNotification *note) {
        NSValue *masternodeList = [note userInfo][DSMasternodeManagerNotificationMasternodeListKey];
        if (![masternodeList isEqual:[NSNull null]]) {
            DMasternodeList *list = masternodeList.pointerValue;
            DSLogPrivate(@"Finished sync");
            [[DashSync sharedSyncController] stopSyncForChain:self.testnetChain];
            
            
            void (^pingTimeCompletionBlock)(NSMutableDictionary<NSData *, NSNumber *> *_Nonnull pingTimes, NSMutableDictionary<NSData *, NSError *> *_Nonnull errors) = ^(NSMutableDictionary<NSData *, NSNumber *> *_Nonnull pingTimes, NSMutableDictionary<NSData *, NSError *> *_Nonnull errors) {
                DSLogPrivate(@"Finished ping times");
                
                NSString *filePath = [[outputDirectory stringByExpandingTildeInPath] stringByAppendingPathComponent:@"networkHealth.json"];
                
                NSMutableDictionary *reportDictionary = [NSMutableDictionary dictionary];
                
                NSMutableDictionary *pingDictionary = [NSMutableDictionary dictionary];
                
                double totalPingTime = 0;
                
                for (NSData *data in pingTimes) {
                    DMasternodeEntry *masternode = [self.testnetChain.masternodeManager masternodeHavingProviderRegistrationTransactionHash:data.reverse];
                    if (masternode) {
                        u128 *ip_addr = dash_spv_masternode_processor_processing_socket_addr_ip(masternode->masternode_list_entry->service_address);
                        UInt128 ip = u128_cast(ip_addr);
                        char s[INET6_ADDRSTRLEN];
                        NSString *ipAddress = @(inet_ntop(AF_INET, &ip.u32[3], s, sizeof(s)));
                        totalPingTime += [pingTimes[data] doubleValue];
                        [pingDictionary setObject:@([pingTimes[data] unsignedLongValue]) forKey:ipAddress];
                    }
                }
                
                NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
                
                for (NSData *data in errors) {
                    DMasternodeEntry *masternode = [self.testnetChain.masternodeManager masternodeHavingProviderRegistrationTransactionHash:data.reverse];
                    if (masternode) {
                        u128 *ip_addr = dash_spv_masternode_processor_processing_socket_addr_ip(masternode->masternode_list_entry->service_address);
                        UInt128 ip = u128_cast(ip_addr);
                        char s[INET6_ADDRSTRLEN];
                        NSString *ipAddress = @(inet_ntop(AF_INET, &ip.u32[3], s, sizeof(s)));
                        [errorDictionary setObject:[errors[data] localizedDescription] forKey:ipAddress];
                    }
                }
                
                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
                [formatter setMaximumFractionDigits:2];
                NSString * formattedNumberString = [formatter stringFromNumber:@(totalPingTime/(1000*pingTimes.count))];
                
                [reportDictionary setObject:[NSString stringWithFormat:@"%@ s", formattedNumberString] forKey:@"averagePing"];
                [reportDictionary setObject:pingDictionary forKey:@"pings"];
                [reportDictionary setObject:errorDictionary forKey:@"errors"];
                
                NSError *error = nil;
                
                NSData *data = [NSJSONSerialization dataWithJSONObject:reportDictionary
                                                               options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                                 error:&error];
                
                NSAssert(error == nil, error.localizedDescription);
                
                [data writeToFile:filePath atomically:YES];
                
                NSLog(@"Writing network info to file %@", filePath);
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"FinishedGatheringNetworkInfo" object:nil];
                exit(0);
            };
            
            
            [self.testnetChain.chainManager.masternodeManager checkPingTimesForCurrentMasternodeListInContext:[NSManagedObjectContext viewContext]
                                                                                               withCompletion:pingTimeCompletionBlock];
        }
    };
    
    [[DashSync sharedSyncController] startSyncForChain:self.testnetChain];
    self.mnListTestnetStatusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DSCurrentMasternodeListDidChangeNotification
                                                                                         object:nil
                                                                                          queue:nil
                                                                                     usingBlock:currentMasternodeListDidChangeBlock];
    
    NSTimer * timeoutTimer = [NSTimer timerWithTimeInterval:1200 repeats:NO block:^(NSTimer * _Nonnull timer) {
        exit(1); //fail after 20 mins
    }];
    
    NSRunLoop * runLoop = [NSRunLoop currentRunLoop];
    
    [runLoop addTimer:timeoutTimer forMode:NSDefaultRunLoopMode];
    
    [runLoop run];
    
}

@end
