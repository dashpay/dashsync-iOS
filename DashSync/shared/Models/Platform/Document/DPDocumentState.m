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

#import "DPDocumentState.h"

@interface DPDocumentState ()

@property (assign, nonatomic) DPDocumentStateType documentStateType;
@property (strong, nonatomic) DSStringValueDictionary *dataChangeDictionary;

@end

@implementation DPDocumentState

- (instancetype)initWithDataDictionary:(DSStringValueDictionary *)dataDictionary {
    if (self = [self init]) {
        self.dataChangeDictionary = dataDictionary;
        if (dataDictionary[@"$updatedAt"] && !dataDictionary[@"$createdAt"]) {
            self.documentStateType = DPDocumentStateType_Replace;
        } else {
            self.documentStateType = DPDocumentStateType_Initial;
        }
    }
    return self;
}

+ (DPDocumentState *)documentStateWithDataDictionary:(DSStringValueDictionary *)dataDictionary {
    return [[DPDocumentState alloc] initWithDataDictionary:dataDictionary];
}

+ (DPDocumentState *)documentStateWithDataDictionary:(DSStringValueDictionary *)dataDictionary ofType:(DPDocumentStateType)documentStateType {
    DPDocumentState *documentState = [[DPDocumentState alloc] initWithDataDictionary:dataDictionary];
    documentState.documentStateType = documentStateType;
    return documentState;
}


@end
