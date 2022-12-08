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

#define DSLog(frmt, ...) DDLogInfo(frmt, ##__VA_ARGS__) //!OCLINT

#ifdef DEBUG
#define DSLogPrivate(s, ...) DDLogVerbose(s, ##__VA_ARGS__)
#else
#define DSLogPrivate(s, ...)
#endif /* DEBUG */

NS_ASSUME_NONNULL_BEGIN

@interface DSLogger : NSObject

+ (instancetype)sharedInstance;

- (NSArray<NSURL *> *)logFiles;

/** @fn log:
 *  @brief This method is identical to `DSLog` macro
 *  @param message Final message to log
 */
+ (void)log:(NSString *)message;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
