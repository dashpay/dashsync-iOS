//
//  Created by Sam Westrich
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSDocumentTransition.h"
#import "DPDocument.h"
#import "DPDocumentState.h"
#import "DSTransition+Protected.h"

@interface DSDocumentTransition ()

@property (nonatomic, strong) NSArray<DPDocument *> *documents;

@end

@implementation DSDocumentTransition

- (NSArray *)documentsAsArrayOfDictionaries {
    NSMutableArray *mArray = [NSMutableArray array];
    for (DPDocument *document in self.documents) {
        [mArray addObject:document.objectDictionary];
    }
    return mArray;
}

- (NSArray *)actions {
    NSMutableArray *mArray = [NSMutableArray array];
    for (DPDocument *document in self.documents) {
        [mArray addObject:@(1)];
    }
    return mArray;
}

- (DSMutableStringValueDictionary *)baseKeyValueDictionary {
    DSMutableStringValueDictionary *json = [super baseKeyValueDictionary];
    json[@"documents"] = [self documentsAsArrayOfDictionaries];
    json[@"actions"] = [self actions];
    return json;
}

- (instancetype)initForDocuments:(NSArray<DPDocument *> *)documents withTransitionVersion:(uint16_t)version blockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId onChain:(DSChain *)chain {
    if (self = [super initWithTransitionVersion:version blockchainIdentityUniqueId:blockchainIdentityUniqueId onChain:chain]) {
        self.documents = documents;
    }
    self.type = DSTransitionType_Documents;

    return self;
}

@end
