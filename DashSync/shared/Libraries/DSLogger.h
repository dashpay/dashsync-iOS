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

NS_ASSUME_NONNULL_BEGIN

// Thread name helper
NSString *DSCurrentThreadName(void);

#pragma mark - Android-style logging macros
// Format: "HH:MM:SS [thread] ClassName - message"
// These match the Android/DashJ log format

#define DSLogInfo(className, frmt, ...) DDLogInfo(@"[%@] %@ - " frmt, DSCurrentThreadName(), className, ##__VA_ARGS__)
#define DSLogDebug(className, frmt, ...) DDLogDebug(@"[%@] %@ - " frmt, DSCurrentThreadName(), className, ##__VA_ARGS__)
#define DSLogWarn(className, frmt, ...) DDLogWarn(@"[%@] %@ - " frmt, DSCurrentThreadName(), className, ##__VA_ARGS__)
#define DSLogError(className, frmt, ...) DDLogError(@"[%@] %@ - " frmt, DSCurrentThreadName(), className, ##__VA_ARGS__)

#ifdef DEBUG
#define DSLogVerbose(className, frmt, ...) DDLogVerbose(@"[%@] %@ - " frmt, DSCurrentThreadName(), className, ##__VA_ARGS__)
#else
#define DSLogVerbose(className, frmt, ...)
#endif /* DEBUG */

#pragma mark - Legacy logging macros (deprecated - for backward compatibility during migration)
// These will be removed after full migration to Android-style logging

#define DSLog(frmt, ...) DDLogInfo(frmt, ##__VA_ARGS__)

#ifdef DEBUG
#define DSLogPrivate(s, ...) DDLogVerbose(s, ##__VA_ARGS__)
#else
#define DSLogPrivate(s, ...)
#endif /* DEBUG */

@interface DSLogger : NSObject

+ (instancetype)sharedInstance;

- (NSArray<NSURL *> *)logFiles;

/** @fn log:
 *  @brief This method logs a message with default class name
 *  @param message Final message to log
 */
+ (void)log:(NSString *)message;

/** @fn log:className:
 *  @brief This method logs a message with specified class name
 *  @param message Final message to log
 *  @param className The class name to include in the log
 */
+ (void)log:(NSString *)message className:(NSString *)className;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
