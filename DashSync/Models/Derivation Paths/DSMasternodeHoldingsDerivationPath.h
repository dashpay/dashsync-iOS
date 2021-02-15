//
//  DSMasternodeHoldingsDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath.h"
#import "DSSimpleIndexedDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeHoldingsDerivationPath : DSSimpleIndexedDerivationPath

+ (instancetype)providerFundsDerivationPathForWallet:(DSWallet *)wallet;

- (NSString *)receiveAddress;

- (void)signTransaction:(DSTransaction *)transaction withPrompt:(NSString *)authprompt completion:(TransactionValidityCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
