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
    self.mainnetChain = [DSChain testnet];
    self.mainnetWallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.mainnetChain storeSeedPhrase:NO isTransient:YES];
    [self.mainnetChain unregisterAllWallets];
    [self.mainnetChain addWallet:self.mainnetWallet];
    
    self.testnetChain = [DSChain testnet];
    self.testnetWallet = [DSWallet standardWalletWithRandomSeedPhraseForChain:self.testnetChain storeSeedPhrase:NO isTransient:YES];
    [self.testnetChain unregisterAllWallets];
    [self.testnetChain addWallet:self.testnetWallet];
    return self;
}

+ (NSURL *)applicationDocumentsDirectory
{
     return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

-(void)getTestnetInfo {
    [[DashSync sharedSyncController] wipePeerDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    [[DashSync sharedSyncController] wipeSporkDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.testnetChain inContext:[NSManagedObjectContext chainContext]];
    
    void (^currentMasternodeListDidChangeBlock)(NSNotification *note) = ^(NSNotification *note) {
        DSMasternodeList *masternodeList = [note userInfo][DSMasternodeManagerNotificationMasternodeListKey];
        if (![masternodeList isEqual:[NSNull null]]) {
            DSLogPrivate(@"Finished sync");
            [[DashSync sharedSyncController] stopSyncForChain:self.testnetChain];
            
            
            void (^pingTimeCompletionBlock)(NSMutableDictionary<NSData *, NSNumber *> *_Nonnull pingTimes, NSMutableDictionary<NSData *, NSError *> *_Nonnull errors) = ^(NSMutableDictionary<NSData *, NSNumber *> *_Nonnull pingTimes, NSMutableDictionary<NSData *, NSError *> *_Nonnull errors) {
                DSLogPrivate(@"Finished ping times");
                
                NSString *dirPath = [[DSNetworkInfo applicationDocumentsDirectory] path];
                
                NSString *filePath = [dirPath stringByAppendingPathComponent:@"networkHealth.json"];
                
                NSMutableDictionary *reportDictionary = [NSMutableDictionary dictionary];
                
                NSMutableDictionary *pingDictionary = [NSMutableDictionary dictionary];
                
                double totalPingTime = 0;
                
                for (NSData *data in pingTimes) {
                    DSSimplifiedMasternodeEntry *masternode = [masternodeList masternodeForRegistrationHash:data.reverse.UInt256];
                    totalPingTime += [pingTimes[data] doubleValue];
                    [pingDictionary setObject:@([pingTimes[data] unsignedLongValue]) forKey:masternode.ipAddressString];
                }
                
                NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
                
                for (NSData *data in errors) {
                    DSSimplifiedMasternodeEntry *masternode = [masternodeList masternodeForRegistrationHash:data.reverse.UInt256];
                    [errorDictionary setObject:[errors[data] localizedDescription] forKey:masternode.ipAddressString];
                }
                
                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
                [formatter setMaximumFractionDigits:2];
                NSString * formattedNumberString = [formatter stringFromNumber:@(totalPingTime/(1000*pingTimes.count))];
                
                [reportDictionary setObject:[NSString stringWithFormat:@"%@ ms", formattedNumberString] forKey:@"averagePing"];
                [reportDictionary setObject:pingDictionary forKey:@"pings"];
                [reportDictionary setObject:errorDictionary forKey:@"errors"];
                
                NSError *error = nil;
                
                NSData *data = [NSJSONSerialization dataWithJSONObject:reportDictionary
                                                               options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                                 error:&error];
                
                NSAssert(error == nil, error.localizedDescription);
                
                [data writeToFile:filePath atomically:YES];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"FinishedGatheringNetworkInfo" object:nil];
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
    
    [NSTimer scheduledTimerWithTimeInterval:300 repeats:NO block:^(NSTimer * _Nonnull timer) {
        exit(1); //fail after 5 mins
    }];
}

@end
