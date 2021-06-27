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

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSDataController : NSObject

@property (nonatomic, readonly) NSManagedObjectContext *viewContext;
@property (nonatomic, readonly) NSManagedObjectContext *peerContext;
@property (nonatomic, readonly) NSManagedObjectContext *chainContext;
@property (nonatomic, readonly) NSManagedObjectContext *platformContext;

+ (instancetype)sharedInstance;

// returns the location on disk of the sqlite store file
+ (NSURL *)storeURL;
+ (NSURL *)storeWALURL;
+ (NSURL *)storeSHMURL;

@end

NS_ASSUME_NONNULL_END
