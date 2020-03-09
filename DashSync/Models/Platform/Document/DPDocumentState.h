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

#import "DPTypes.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DPDocument;

typedef NS_ENUM(NSUInteger, DPDocumentStateType) {
    DPDocumentStateType_Initial = 1,
    DPDocumentStateType_Update = 2,
    DPDocumentStateType_Delete = 4,
};

@interface DPDocumentState : NSObject

@property (readonly, nonatomic) DPDocumentStateType documentStateType;
@property (readonly, nonatomic) DSStringValueDictionary *dataChangeDictionary;

- (instancetype)initWithDataDictionary:(DSStringValueDictionary *)dataDictionary;

+ (DPDocumentState *)documentStateWithDataDictionary:(DSStringValueDictionary *)dataDictionary;

+ (DPDocumentState *)documentStateWithDataDictionary:(DSStringValueDictionary *)dataDictionary ofType:(DPDocumentStateType)documentStateType;

@end

NS_ASSUME_NONNULL_END
