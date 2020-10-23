//  
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSContractTransition.h"
#import "DPDocument.h"
#import "DSTransition+Protected.h"
#import "DPContract+Protected.h"
#import "NSString+Dash.h"

@interface DSContractTransition()

@property(nonatomic,strong) DPContract * contract;

@end

@implementation DSContractTransition

- (DSMutableStringValueDictionary *)baseKeyValueDictionary {
    DSMutableStringValueDictionary *json = [super baseKeyValueDictionary];
    json[@"dataContract"] = self.contract.objectDictionary;
    json[@"entropy"] = uint256_data(self.contract.entropy);
    return json;
}

-(instancetype)initWithContract:(DPContract*)contract withTransitionVersion:(uint16_t)version blockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId onChain:(DSChain *)chain {
    if (self = [super initWithTransitionVersion:version blockchainIdentityUniqueId:blockchainIdentityUniqueId onChain:chain]) {
        self.contract = contract;
    }
    self.type = DSTransitionType_DataContract;
    
    return self;
}

@end
