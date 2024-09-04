//  
//  Created by Andrei Ashikhmin
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSCoinJoinBalance.h"

@implementation DSCoinJoinBalance

+ (DSCoinJoinBalance *)balanceWithMyTrusted:(uint64_t)myTrusted
                 denominatedTrusted:(uint64_t)denominatedTrusted
                         anonymized:(uint64_t)anonymized
                         myImmature:(uint64_t)myImmature
                myUntrustedPending:(uint64_t)myUntrustedPending
        denominatedUntrustedPending:(uint64_t)denominatedUntrustedPending
                  watchOnlyTrusted:(uint64_t)watchOnlyTrusted
       watchOnlyUntrustedPending:(uint64_t)watchOnlyUntrustedPending
                  watchOnlyImmature:(uint64_t)watchOnlyImmature {
    
    DSCoinJoinBalance *balance = [[DSCoinJoinBalance alloc] init];
    balance.myTrusted = myTrusted;
    balance.denominatedTrusted = denominatedTrusted;
    balance.anonymized = anonymized;
    balance.myImmature = myImmature;
    balance.myUntrustedPending = myUntrustedPending;
    balance.denominatedUntrustedPending = denominatedUntrustedPending;
    balance.watchOnlyTrusted = watchOnlyTrusted;
    balance.watchOnlyUntrustedPending = watchOnlyUntrustedPending;
    balance.watchOnlyImmature = watchOnlyImmature;
    
    return balance;
}

- (Balance *)ffi_malloc {
    Balance *balance = malloc(sizeof(Balance));
    balance->my_trusted = self.myTrusted;
    balance->denominated_trusted = self.denominatedTrusted;
    balance->anonymized = self.anonymized;
    balance->my_immature = self.myImmature;
    balance->my_untrusted_pending = self.myUntrustedPending;
    balance->denominated_untrusted_pending = self.denominatedUntrustedPending;
    balance->watch_only_trusted = self.watchOnlyTrusted;
    balance->watch_only_untrusted_pending = self.watchOnlyUntrustedPending;
    balance->watch_only_immature = self.watchOnlyImmature;
    
    return balance;
}

+ (void)ffi_free:(Balance *)balance {
    if (balance) {
        free(balance);
    }
}
@end
