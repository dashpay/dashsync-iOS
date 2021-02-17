//  
//  Created by Sam Westrich
//  Copyright © 2021 Dash Core Group. All rights reserved.
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
#import "DSNetworkInfo.h"
#import <DashSync/DashSync.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString * outputDirectory;

        if (argc < 3 || ![[NSString stringWithUTF8String:argv[1]] isEqualToString:@"-outputDir"]) { // Remind user of how to use this program
            NSLog(@"Usage: requires -outputDir to be set");
            exit(1);
        } else {
            outputDirectory = [NSString stringWithUTF8String:argv[2]];
        }

        
        [DSLogger sharedInstance];
        [[DSAuthenticationManager sharedInstance] setOneTimeShouldUseAuthentication:FALSE];
        [DashSync sharedSyncController];
        DSNetworkInfo * networkInfo = [[DSNetworkInfo alloc] init];
        [networkInfo getTestnetInfo:outputDirectory];
    }
    return 0;
}
