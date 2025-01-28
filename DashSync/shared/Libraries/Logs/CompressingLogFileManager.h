//
//  CompressingLogFileManager.h
//  LogFileCompressor
//
//  CocoaLumberjack Demos
//

#import <Foundation/Foundation.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface CompressingLogFileManager : DDLogFileManagerDefault
{
    BOOL upToDate;
    BOOL isCompressing;
}

@property (nonatomic, assign) unsigned long long maxFileSize;
- (instancetype)initWithFileSize:(unsigned long long)maxFileSize;

@end
