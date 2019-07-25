//  
//  Created by Andrew Podkovyrin
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

#import <Foundation/Foundation.h>

#import <CocoaLumberjack/CocoaLumberjack.h>

#ifdef DEBUG
    static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
    static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#endif /* DEBUG */

#define DSLogError(frmt, ...) DDLogError(frmt, ##__VA_ARGS__)
#define DSLogWarn(frmt, ...) DDLogWarn(frmt, ##__VA_ARGS__)
#define DSLogInfo(frmt, ...) DDLogInfo(frmt, ##__VA_ARGS__)
#define DSLogDebug(frmt, ...) DDLogDebug(frmt, ##__VA_ARGS__)
#define DSLogVerbose(frmt, ...) DDLogVerbose(frmt, ##__VA_ARGS__)

NS_ASSUME_NONNULL_BEGIN

@interface DSLogger : NSObject

@property (readonly, nonatomic, assign) BOOL shouldLogHTTPRequests;
@property (readonly, nonatomic, assign) BOOL shouldLogHTTPResponses;

+ (instancetype)sharedInstance;

- (NSArray <NSURL *> *)logFiles;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
