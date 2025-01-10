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
#import "DPDocumentState.h"
#import "DSPlatformQuery.h"
#import "DSPlatformTreeQuery.h"
#import "DSTransition+Protected.h"
#import "NSData+Dash.h"

@interface DSDocumentTransition ()

@property (nonatomic, strong) NSArray<DPDocument *> *documents;
@property (nonatomic, strong) NSArray<NSNumber *> *actions;

@end

@implementation DSDocumentTransition

- (NSArray *)documentsAsArrayOfDictionaries {
    NSMutableArray *mArray = [NSMutableArray array];
    for (DPDocument *document in self.documents) {
        [mArray addObject:document.objectDictionary];
    }
    return mArray;
}

- (DSMutableStringValueDictionary *)baseKeyValueDictionary {
    DSMutableStringValueDictionary *json = [super baseKeyValueDictionary];
    json[@"transitions"] = [self documentsAsArrayOfDictionaries];
    json[@"ownerId"] = uint256_data(self.identityUniqueId);
    return json;
}

- (instancetype)initForDocuments:(NSArray<DPDocument *> *)documents
           withTransitionVersion:(uint16_t)version
                identityUniqueId:(UInt256)identityUniqueId
                         onChain:(DSChain *)chain {
    if (!(self = [super initWithTransitionVersion:version identityUniqueId:identityUniqueId onChain:chain])) return nil;

    self.documents = documents;
    self.type = DSTransitionType_Documents;
    self.identityUniqueId = identityUniqueId;

    return self;
}

- (DSPlatformQuery *)expectedResponseQuery {
    return [DSPlatformQuery platformQueryForDocuments:self.documents];
}

@end
