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
#import "DSTransition+Protected.h"
#import "DPDocumentState.h"

@interface DSDocumentTransition()

@property(nonatomic,strong) NSArray<DPDocument *>* documents;
@property(nonatomic,strong) NSArray<NSNumber *>* actions;

@end

@implementation DSDocumentTransition

-(NSArray*)documentsAsArrayOfDictionaries {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DPDocument * document in self.documents) {
        [mArray addObject:document.objectDictionary];
    }
    return mArray;
}

- (DSMutableStringValueDictionary *)baseKeyValueDictionary {
    DSMutableStringValueDictionary *json = [super baseKeyValueDictionary];
    json[@"documents"] = [self documentsAsArrayOfDictionaries];
    json[@"actions"] = self.actions;
    return json;
}

-(instancetype)initForCreatedDocuments:(NSArray<DPDocument*>*)documents withTransitionVersion:(uint16_t)version blockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId onChain:(DSChain *)chain {
    
    NSMutableArray * createActionArray = [NSMutableArray array];
    for (uint32_t i =0;i<documents.count;i++) {
        [createActionArray addObject:@(DSDocumentTransitionType_Create)];
    }

    if (!(self = [self initForDocuments:documents withActions:createActionArray withTransitionVersion:version blockchainIdentityUniqueId:blockchainIdentityUniqueId onChain:chain])) return nil;
    
    return self;
}

-(instancetype)initForUpdatedDocuments:(NSArray<DPDocument*>*)documents withTransitionVersion:(uint16_t)version blockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId onChain:(DSChain *)chain {
    NSMutableArray * updateActionArray = [NSMutableArray array];
    for (uint32_t i =0;i<documents.count;i++) {
        [updateActionArray addObject:@(DSDocumentTransitionType_Update)];
    }

    if (!(self = [self initForDocuments:documents withActions:updateActionArray withTransitionVersion:version blockchainIdentityUniqueId:blockchainIdentityUniqueId onChain:chain])) return nil;
    
    return self;
}


-(instancetype)initForDocuments:(NSArray<DPDocument*>*)documents withActions:(NSArray<NSNumber*>*)actions withTransitionVersion:(uint16_t)version blockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId onChain:(DSChain *)chain {
    NSAssert(documents.count == actions.count, @"document count must match action count");
    if (!(self = [super initWithTransitionVersion:version blockchainIdentityUniqueId:blockchainIdentityUniqueId onChain:chain])) return nil;
    
    self.documents = documents;
    self.actions = actions;
    self.type = DSTransitionType_Documents;
    
    return self;
}

@end
