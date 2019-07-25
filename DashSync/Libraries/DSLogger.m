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

#import "DSLogger.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSLogger ()

@property (readonly, nonatomic, strong) DDFileLogger *fileLogger;

@end

@implementation DSLogger

+ (instancetype)sharedInstance {
    static DSLogger *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [DDLog addLogger:[DDOSLogger sharedInstance]]; // os_log
        
        DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
        fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 3; // keep a 3 days worth of log files
        [DDLog addLogger:fileLogger];
        _fileLogger = fileLogger;
    }
    return self;
}

- (NSArray <NSURL *> *)logFiles {
    NSArray <DDLogFileInfo *> *logFileInfos = [self.fileLogger.logFileManager unsortedLogFileInfos];
    NSMutableArray <NSURL *> *logFiles = [NSMutableArray array];
    for (DDLogFileInfo *fileInfo in logFileInfos) {
        NSURL *fileURL = [NSURL fileURLWithPath:fileInfo.filePath];
        if (fileURL) {
            [logFiles addObject:fileURL];
        }
    }
    
    return [logFiles copy];
}

@end

NS_ASSUME_NONNULL_END
