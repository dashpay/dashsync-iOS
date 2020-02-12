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

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSPlatformDocumentType) {
    DSPlatformDocumentType_Contract = 1,
    DSPlatformDocumentType_Document = 2,
};

@class GetDocumentsRequest;

@interface DSPlatformDocumentsRequest : NSObject

@property(nonatomic,strong) NSPredicate * predicate;
@property(nonatomic,strong) NSArray <NSSortDescriptor*>* sortDescriptors;
@property(nonatomic,assign) uint32_t startAt;
@property(nonatomic,assign) uint32_t limit;
@property(nonatomic,assign) DSPlatformDocumentType type;

+(instancetype)dpnsRequestForName:(NSString*)name;

+(instancetype)dpnsRequestForPreorderSaltedHashes:(NSArray*)preorderSaltedHashes;

-(GetDocumentsRequest*)getDocumentsRequest;

@end

NS_ASSUME_NONNULL_END
