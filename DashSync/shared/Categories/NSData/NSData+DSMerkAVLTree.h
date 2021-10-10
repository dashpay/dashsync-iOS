//
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
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

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSPlatformStoredMessage)
{
    /// The version is prepended before all items
    DSPlatformStoredMessage_Version,
    /// An item can be returned if decode is set to true
    DSPlatformStoredMessage_Item,
    /// A data item that can be returned if decode is set to false
    DSPlatformStoredMessage_Data,
};

@class DSPlatformTreeQuery;

@interface NSData (DSMerkAVLTree)

/* executeProofReturnElementDictionary returns items from the proof that match the specific query, if no query is set all
 items are returned.
 */
- (NSData *_Nullable)executeProofReturnElementDictionary:(NSDictionary *_Nonnull *_Nullable)rElementDictionary  query:(DSPlatformTreeQuery*_Nullable)query decode:(BOOL)decode usesVersion:(BOOL)usesVersion error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
