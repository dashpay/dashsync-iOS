//
//  DSIdentity.m
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//
#import "DSIdentity.h"
#import "DPContract+Protected.h"
#import "DSAccount.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSAssetLockDerivationPath.h"
#import "DSAssetLockTransaction.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSAuthenticationManager.h"
#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Transaction.h"
#import "DSChain+Wallet.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPathFactory.h"
#import "DSIdentitiesManager+Protected.h"
#import "DSIdentitiesManager+CoreData.h"
#import "DSIdentity+ContactRequest.h"
#import "DSIdentity+Profile.h"
#import "DSIdentity+Protected.h"
#import "DSIdentity+Username.h"
#import "DSInstantSendTransactionLock.h"
#import "DSInvitation+Protected.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSMerkleBlock.h"
#import "DSOptionsManager.h"
#import "DSTransaction+FFI.h"
#import "DSTransactionOutput+FFI.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSWallet+Identity.h"
#import "NSData+Encryption.h"
#import "NSDate+Utils.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSIndexPath+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSObject+Notification.h"

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"
#define DEFAULT_FETCH_IDENTITY_RETRY_COUNT 5

#define ERROR_REGISTER_KEYS_BEFORE_IDENTITY [NSError errorWithCode:500 localizedDescriptionKey:@"The blockchain identity extended public keys need to be registered before you can register a identity."]
#define ERROR_FUNDING_TX_CREATION [NSError errorWithCode:500 localizedDescriptionKey:@"Funding transaction could not be created"]
#define ERROR_FUNDING_TX_SIGNING [NSError errorWithCode:500 localizedDescriptionKey:@"Transaction could not be signed"]
#define ERROR_FUNDING_TX_TIMEOUT [NSError errorWithCode:500 localizedDescriptionKey:@"Timeout while waiting for funding transaction to be accepted by network"]
#define ERROR_FUNDING_TX_ISD_TIMEOUT [NSError errorWithCode:500 localizedDescriptionKey:@"Timeout while waiting for funding transaction to acquire an instant send lock"]
#define ERROR_REG_TRANSITION [NSError errorWithCode:501 localizedDescriptionKey:@"Unable to register registration transition"]
#define ERROR_REG_TRANSITION_CREATION [NSError errorWithCode:501 localizedDescriptionKey:@"Unable to create registration transition"]
#define ERROR_ATTEMPT_QUERY_WITHOUT_KEYS [NSError errorWithCode:501 localizedDescriptionKey:@"Attempt to query DAPs for identity with no active keys"]
#define ERROR_NO_FUNDING_PRV_KEY [NSError errorWithCode:500 localizedDescriptionKey:@"The blockchain identity funding private key should be first created with createFundingPrivateKeyWithCompletion"]
#define ERROR_FUNDING_TX_NOT_MINED [NSError errorWithCode:500 localizedDescriptionKey:@"The registration credit funding transaction has not been mined yet and has no instant send lock"]
#define ERROR_NO_IDENTITY [NSError errorWithCode:500 localizedDescriptionKey:@"Platform returned no identity when one was expected"]

NSString * DSRegistrationStepsDescription(DSIdentityRegistrationStep step) {
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_None))
        [components addObject:@"None"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_FundingTransactionCreation))
        [components addObject:@"FundingTransactionCreation"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_FundingTransactionAccepted))
        [components addObject:@"FundingTransactionAccepted"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_LocalInWalletPersistence))
        [components addObject:@"LocalInWalletPersistence"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_ProofAvailable))
        [components addObject:@"ProofAvailable"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_L1Steps))
        [components addObject:@"L1Steps"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_Identity))
        [components addObject:@"Identity"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_RegistrationSteps))
        [components addObject:@"RegistrationSteps"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_Username))
        [components addObject:@"Username"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_RegistrationStepsWithUsername))
        [components addObject:@"RegistrationStepsWithUsername"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_Profile))
        [components addObject:@"Profile"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_RegistrationStepsWithUsernameAndDashpayProfile))
        [components addObject:@"RegistrationStepsWithUsernameAndDashpayProfile"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_All))
        [components addObject:@"All"];
    if (FLAG_IS_SET(step, DSIdentityRegistrationStep_Cancelled))
        [components addObject:@"Cancelled"];
    return [components componentsJoinedByString:@" | "];
}

NSString * DSIdentityQueryStepsDescription(DSIdentityQueryStep step) {
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_None))
        [components addObject:@"None"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_Identity))
        [components addObject:@"Identity"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_Username))
        [components addObject:@"Username"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_Profile))
        [components addObject:@"Profile"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_IncomingContactRequests))
        [components addObject:@"IncomingContactRequests"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_OutgoingContactRequests))
        [components addObject:@"OutgoingContactRequests"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_ContactRequests))
        [components addObject:@"ContactRequests"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_AllForForeignIdentity))
        [components addObject:@"AllForForeignIdentity"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_AllForLocalIdentity))
        [components addObject:@"AllForLocalIdentity"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_NoIdentity))
        [components addObject:@"NoIdentity"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_BadQuery))
        [components addObject:@"BadQuery"];
    if (FLAG_IS_SET(step, DSIdentityQueryStep_Cancelled))
        [components addObject:@"Cancelled"];
    return [components componentsJoinedByString:@" | "];
}

#define AS_OBJC(context) ((__bridge DSIdentity *)(context))
#define AS_RUST(context) ((__bridge void *)(context))


@implementation DSDerivationContext
+ (instancetype)withDerivationPath:(DSDerivationPath *)derivationPath indexPath:(NSIndexPath *)indexPath {
    DSDerivationContext *context = [[DSDerivationContext alloc] init];
    context.derivationPath = derivationPath;
    context.indexPath = indexPath;
    return context;
}
@end

@interface DSIdentity ()

@property (nonatomic, strong) DSDashpayUserEntity *matchingDashpayUserInViewContext;
@property (nonatomic, strong) DSDashpayUserEntity *matchingDashpayUserInPlatformContext;
@property (nonatomic, strong) DSAssetLockTransaction *registrationAssetLockTransaction;

@end


const void *get_derivation_context_caller(const void *context, DKeyKind *key_kind, DOpaqueKey *key, uint32_t identity_index, uint32_t key_id) {
    DSIdentity *identity = AS_OBJC(context);
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:(const NSUInteger[]){identity_index, key_id} length:2];
    DSAuthenticationKeysDerivationPath *derivationPath = [identity derivationPathForType:key_kind];
    DOpaqueKey *key_to_check = [derivationPath publicKeyAtIndexPathAsOpt:[indexPath hardenAllItems]];
    BOOL isEqual = [DSKeyManager keysPublicKeyDataIsEqual:key_to_check key2:key];
    DKeyKindDtor(key_kind);
    DOpaqueKeyDtor(key);
    if (key_to_check)
        DOpaqueKeyDtor(key_to_check);
    return isEqual ? ((__bridge void *)([DSDerivationContext withDerivationPath:derivationPath indexPath:indexPath])) : nil;
}

void get_derivation_context_dtor(const void *derivation_context) {}

BOOL save_key_info_caller(const void *identity_context, const void *storage_context, uint32_t identity_index, uint32_t key_index, DKeyInfo *key_info) {
    DSIdentity *identity = AS_OBJC(identity_context);
    if (!identity.isActive) {
        DKeyInfoDtor(key_info);
        return NO;
    }
    if (!storage_context) {
        DKeyInfoDtor(key_info);
        return NO;
    }
    NSManagedObjectContext *storageContext = ((__bridge NSManagedObjectContext *)(storage_context));
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:(const NSUInteger[]){identity_index, key_index} length:2];
    DKeyKind *key_kind = dash_spv_platform_identity_key_info_KeyInfo_kind(key_info);
    DSAuthenticationKeysDerivationPath *derivationPath = [identity derivationPathForType:key_kind];
    DOpaqueKey *key_to_check = [derivationPath publicKeyAtIndexPathAsOpt:[indexPath hardenAllItems]];
    BOOL isEqual = [DSKeyManager keysPublicKeyDataIsEqual:key_to_check key2:key_info->key];
    if (!isEqual) {
        DSLog(@"save_key_info: Public Keys don't match");
        DKeyInfoDtor(key_info);
        return NO;
    }
    BOOL saved = [identity saveNewKeyInfoForCurrentEntity:key_info
                                              atIndexPath:indexPath
                                       fromDerivationPath:derivationPath
                                                inContext:storageContext];
    DKeyInfoDtor(key_info);
    return saved;
}
BOOL save_remote_key_info_caller(const void *identity_context, const void *storage_context, uint32_t index, DKeyInfo *key_info) {
    DSIdentity *identity = AS_OBJC(identity_context);
    if (!identity.isActive) {
        DKeyInfoDtor(key_info);
        return NO;
    }
    if (!storage_context) {
        DKeyInfoDtor(key_info);
        return NO;
    }
    __block BOOL saved = NO;
    NSManagedObjectContext *storageContext = ((__bridge NSManagedObjectContext *)(storage_context));
    [storageContext performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [identity identityEntityInContext:storageContext];
        NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsInContext:storageContext matching:@"blockchainIdentity == %@ && keyID == %@", identityEntity, @(index)];
        if (!count) {
            DSBlockchainIdentityKeyPathEntity *keyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:storageContext];
            // TODO: migrate OpaqueKey/KeyKind to KeyType
            keyPathEntity.keyType = DOpaqueKeyToKeyTypeIndex(key_info->key);
            keyPathEntity.keyStatus = DIdentityKeyStatusToIndex(key_info->key_status);
            keyPathEntity.keyID = index;
            keyPathEntity.publicKeyData = [DSKeyManager publicKeyData:key_info->key];
            keyPathEntity.securityLevel = DSecurityLevelIndex(key_info->security_level);
            keyPathEntity.purpose = DPurposeIndex(key_info->purpose);
            [identityEntity addKeyPathsObject:keyPathEntity];
            [storageContext ds_save];
            saved = YES;
        }
    }];
    DKeyInfoDtor(key_info);
    return saved;
}
BOOL save_key_status_caller(const void *identity_context, const void *storage_context, uint32_t identity_index, uint32_t key_index, DKeyInfo *key_info) {
    DSIdentity *identity = AS_OBJC(identity_context);
    if (!identity.isActive) {
        DKeyInfoDtor(key_info);
        return NO;
    }
    if (!storage_context) {
        DKeyInfoDtor(key_info);
        return NO;
    }
    NSManagedObjectContext *storageContext = ((__bridge NSManagedObjectContext *)(storage_context));
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:(const NSUInteger[]){identity_index, key_index} length:2];
    DKeyKind *key_kind = dash_spv_platform_identity_key_info_KeyInfo_kind(key_info);
    DSAuthenticationKeysDerivationPath *derivationPath = [identity derivationPathForType:key_kind];

    uint16_t keyStatus = DIdentityKeyStatusToIndex(key_info->key_status);
    DKeyInfoDtor(key_info);
    __block BOOL saved = NO;
    [storageContext performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [identity identityEntityInContext:storageContext];
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath inContext:storageContext];
        DSBlockchainIdentityKeyPathEntity *keyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:storageContext matching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@ && keyStatus != %u", identityEntity, derivationPathEntity, indexPath, keyStatus] firstObject];
        if (keyPathEntity) {
            keyPathEntity.keyStatus = keyStatus;
            [storageContext ds_save];
            saved = YES;
        }
    }];
    return saved;
}
BOOL save_remote_key_status_caller(const void *identity_context, const void *storage_context, uint32_t index, DIdentityKeyStatus *status) {
    DSIdentity *identity = AS_OBJC(identity_context);
    if (!identity.isActive) {
        DIdentityKeyStatusDtor(status);
        return NO;
    }
    if (!storage_context) {
        DIdentityKeyStatusDtor(status);
        return NO;
    }
    NSManagedObjectContext *storageContext = ((__bridge NSManagedObjectContext *)(storage_context));
    uint16_t keyStatus = DIdentityKeyStatusToIndex(status);
    DIdentityKeyStatusDtor(status);
    __block BOOL saved = NO;
    [storageContext performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [identity identityEntityInContext:storageContext];
        DSBlockchainIdentityKeyPathEntity *keyPathEntity = [[DSBlockchainIdentityKeyPathEntity objectsInContext:storageContext matching:@"blockchainIdentity == %@ && derivationPath == NULL && keyID == %@", identityEntity, @(index)] firstObject];
        if (keyPathEntity) {
            keyPathEntity.keyStatus = keyStatus;
            [storageContext ds_save];
            saved = YES;
        }
    }];
    return saved;
}


void save_key_dtor(bool saved) {}

Vec_u8 *get_private_key_caller(const void *context, uint32_t index, DKeyKind *key_kind) {
    DSIdentity *identity = AS_OBJC(context);
    NSIndexPath *indexPath = [identity hardenedIndexPathForIndex:index];
    DSAuthenticationKeysDerivationPath *derivationPath = [identity derivationPathForType:key_kind];
    DKeyKindDtor(key_kind);
    NSError *error = nil;
    NSString *identifier = [NSString stringWithFormat:@"%@-%@-%@", identity.uniqueIdString, derivationPath.standaloneExtendedPublicKeyUniqueID, [[indexPath softenAllItems] indexPathString]];
    NSData *keySecret = getKeychainData(identifier, &error);
//    NSAssert(keySecret, @"This should be present");
    if (!keySecret || error) return nil;
    return bytes_ctor(keySecret);
}
void get_private_key_dtor(Vec_u8 *private_key_data) {}

void save_username_caller(const void *context, DSaveUsernameContext* save_username_context) {
    DSIdentity *identity = AS_OBJC(context);
    if (identity.isTransient || !identity.isActive) {
        dash_spv_platform_identity_storage_username_SaveUsernameContext_destroy(save_username_context);
        return;
    }
    NSManagedObjectContext *platformContext = identity.platformContext;

    [platformContext performBlockAndWait:^{
        switch (save_username_context->tag) {
            case dash_spv_platform_identity_storage_username_SaveUsernameContext_NewUsername: {
                NSString *username = NSStringFromPtr(save_username_context->new_username.username);
                NSString *domain = NSStringFromPtr(save_username_context->new_username.domain);
                uint16_t status = DUsernameStatusIndex(save_username_context->new_username.status);
                u256 *maybe_salt = save_username_context->new_username.salt;
                DSBlockchainIdentityEntity *entity = [identity identityEntityInContext:platformContext];
                DSBlockchainIdentityUsernameEntity *usernameEntity = [DSBlockchainIdentityUsernameEntity managedObjectInBlockedContext:platformContext];
                usernameEntity.status = status;
                usernameEntity.domain = domain;
                usernameEntity.stringValue = username;
                if (maybe_salt)
                    usernameEntity.salt = NSDataFromPtr(maybe_salt);
                [entity addUsernamesObject:usernameEntity];
                [entity setDashpayUsername:usernameEntity];
                [platformContext ds_save];
                [identity notifyUsernameUpdate:@{
                    DSChainManagerNotificationChainKey: identity.chain,
                    DSIdentityKey: identity
                }];
                break;
            }
            case dash_spv_platform_identity_storage_username_SaveUsernameContext_Username: {
                NSString *username = NSStringFromPtr(save_username_context->username.username);
                DSBlockchainIdentityEntity *entity = [identity identityEntityInContext:platformContext];
                NSSet *usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity *_Nonnull obj, BOOL *_Nonnull stop) {
                    BOOL isEqual = [obj.stringValue isEqualToString:username];
                    if (isEqual) *stop = YES;
                    return isEqual;
                }];
                if ([usernamesPassingTest count]) {
                    NSString *domain = NSStringFromPtr(save_username_context->username.domain);
                    uint16_t status = DUsernameStatusIndex(save_username_context->username.status);
                    u256 *maybe_salt = save_username_context->username.salt;
                    //                    NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
                    DSBlockchainIdentityUsernameEntity *usernameEntity = [usernamesPassingTest anyObject];
                    usernameEntity.status = status;
                    if (maybe_salt)
                        usernameEntity.salt = NSDataFromPtr(maybe_salt);
                    if (save_username_context->username.commit_save)
                        [platformContext ds_save];
                    [identity notifyUsernameUpdate:@{
                        DSChainManagerNotificationChainKey: identity.chain,
                        DSIdentityKey: identity,
                        DSIdentityUsernameKey: username,
                        DSIdentityUsernameDomainKey: domain
                    }];
                }
                break;
            }
            case dash_spv_platform_identity_storage_username_SaveUsernameContext_UsernameFullPath: {
                NSString *usernameFullPath = NSStringFromPtr(save_username_context->username_full_path.username_full_path);
                
                DSBlockchainIdentityEntity *entity = [identity identityEntityInContext:platformContext];
                NSSet *usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity *_Nonnull obj, BOOL *_Nonnull stop) {
                    BOOL isEqual = [[[obj.stringValue lowercaseString] stringByAppendingFormat:@".%@", [obj.domain lowercaseString]] isEqualToString:usernameFullPath];
                    if (isEqual) *stop = YES;
                    return isEqual;
                }];
                if ([usernamesPassingTest count]) {
                    //                    NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
                    DSBlockchainIdentityUsernameEntity *usernameEntity = [usernamesPassingTest anyObject];
                    uint16_t status = DUsernameStatusIndex(save_username_context->username_full_path.status);
                    u256 *maybe_salt = save_username_context->username_full_path.salt;
                    usernameEntity.status = status;
                    if (maybe_salt)
                        usernameEntity.salt = NSDataFromPtr(maybe_salt);
                    if (save_username_context->username_full_path.commit_save)
                        [platformContext ds_save];
                    [identity notifyUsernameUpdate:@{
                        DSChainManagerNotificationChainKey: identity.chain,
                        DSIdentityKey: identity,
                        DSIdentityUsernameKey: usernameEntity.stringValue,
                        DSIdentityUsernameDomainKey: usernameEntity.domain
                    }];
                }
                break;
            }
            case dash_spv_platform_identity_storage_username_SaveUsernameContext_UsernameFullPaths: {
                DUsernameStatus *status = save_username_context->username_full_paths.status;
                Vec_Tuple_String_String *result = save_username_context->username_full_paths.usernames_and_domains;
                
                for (int i = 0; i < result->count; i++) {
                    Tuple_String_String *pair = result->values[i];
                    NSString *username = NSStringFromPtr(pair->o_0);
                    NSString *domain = NSStringFromPtr(pair->o_1);
                    DSBlockchainIdentityEntity *entity = [identity identityEntityInContext:platformContext];
                    NSSet *usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity *_Nonnull obj, BOOL *_Nonnull stop) {
                        BOOL isEqual = [obj.stringValue isEqualToString:username];
                        if (isEqual) *stop = YES;
                        return isEqual;
                    }];
                    if ([usernamesPassingTest count]) {
                        //                    NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
                        DSBlockchainIdentityUsernameEntity *usernameEntity = [usernamesPassingTest anyObject];
                        usernameEntity.status = DUsernameStatusIndex(status);
                        [identity notifyUsernameUpdate:@{
                            DSChainManagerNotificationChainKey: identity.chain,
                            DSIdentityKey: identity,
                            DSIdentityUsernameKey: username,
                            DSIdentityUsernameDomainKey: domain
                        }];
                    }
                }
                Vec_Tuple_String_String_destroy(result);
                [platformContext ds_save];
                break;
            }
        }
    }];
    dash_spv_platform_identity_storage_username_SaveUsernameContext_destroy(save_username_context);
}

Result_ok_u32_err_dash_spv_platform_error_Error *create_new_key_caller(const void *context, DKeyKind *key_kind, DSecurityLevel *security_level, DPurpose *purpose, BOOL save_key) {
    DSIdentity *identity = AS_OBJC(context);
    uint32_t rIndex;
    DKeyKind kind = DKeyKindIndex(key_kind);
    BOOL created = [identity createNewKeyOfType:kind
                                  securityLevel:DSecurityLevelIndex(security_level)
                                        purpose:DPurposeIndex(purpose)
                                        saveKey:save_key
                                    returnIndex:&rIndex];
    DKeyKindDtor(key_kind);
    DSecurityLevelDtor(security_level);
    DPurposeDtor(purpose);
    if (created) {
        return Result_ok_u32_err_dash_spv_platform_error_Error_ctor(u32_ctor(rIndex), NULL);
    } else {
        NSString *err = [NSString stringWithFormat:@"Can't create key of %u", kind];
        return Result_ok_u32_err_dash_spv_platform_error_Error_ctor(NULL, dash_spv_platform_error_Error_Any_ctor(0, DChar(err)));
    }
}
void create_new_key_dtor(Result_ok_u32_err_dash_spv_platform_error_Error *result) {}

Result_ok_bool_err_dash_spv_platform_error_Error *active_private_keys_are_loaded_caller(const void *context, BOOL is_local, DKeyInfoDictionaries *key_infos) {
    DSIdentity *identity = AS_OBJC(context);
    NSError *error = nil;
    BOOL loaded = YES;
    for (uint32_t i = 0; i < key_infos->count; i++) {
        DKeyInfo *key_info = key_infos->values[i];
        uint32_t index = key_infos->keys[i];
        NSIndexPath *indexPath = [identity hardenedIndexPathForIndex:index];
        DKeyKind *kind = dash_spv_platform_identity_key_info_KeyInfo_kind(key_info);
        DSDerivationPath *derivationPath = [identity derivationPathForType:kind];
        DKeyKindDtor(kind);
        NSString *identifier = [NSString stringWithFormat:@"%@-%@-%@", identity.uniqueIdString, derivationPath.standaloneExtendedPublicKeyUniqueID, [[indexPath softenAllItems] indexPathString]];
        loaded &= !identity.isLocal ? NO : hasKeychainData(identifier, &error);
        if (error) {
            DKeyInfoDictionariesDtor(key_infos);
            return Result_ok_bool_err_dash_spv_platform_error_Error_ctor(NULL, dash_spv_platform_error_Error_Any_ctor(0, DChar([error description])));
        }
    }
    DKeyInfoDictionariesDtor(key_infos);
    return Result_ok_bool_err_dash_spv_platform_error_Error_ctor(&loaded, NULL);
}
void active_private_keys_are_loaded_dtor(Result_ok_bool_err_dash_spv_platform_error_Error *result) {}

Fn_ARGS_std_os_raw_c_void_dash_spv_crypto_keys_key_KeyKind_dash_spv_crypto_keys_key_OpaqueKey_u32_u32_RTRN_std_os_raw_c_void get_derivation_context = {
    .caller = &get_derivation_context_caller,
    .destructor = &get_derivation_context_dtor
};
Fn_ARGS_std_os_raw_c_void_std_os_raw_c_void_u32_u32_dash_spv_platform_identity_key_info_KeyInfo_RTRN_bool save_key_info = {
    .caller = &save_key_info_caller,
    .destructor = &save_key_dtor,
};
Fn_ARGS_std_os_raw_c_void_std_os_raw_c_void_u32_u32_dash_spv_platform_identity_key_info_KeyInfo_RTRN_bool save_key_status = {
    .caller = &save_key_status_caller,
    .destructor = &save_key_dtor,
};
Fn_ARGS_std_os_raw_c_void_std_os_raw_c_void_u32_dash_spv_platform_identity_key_info_KeyInfo_RTRN_bool save_remote_key_info = {
    .caller = &save_remote_key_info_caller,
    .destructor = &save_key_dtor,
};
Fn_ARGS_std_os_raw_c_void_std_os_raw_c_void_u32_dash_spv_platform_identity_key_status_IdentityKeyStatus_RTRN_bool save_remote_key_status = {
    .caller = &save_remote_key_status_caller,
    .destructor = &save_key_dtor,
};

Fn_ARGS_std_os_raw_c_void_u32_dash_spv_crypto_keys_key_KeyKind_RTRN_Option_Vec_u8 get_private_key = {
    .caller = &get_private_key_caller,
    .destructor = &get_private_key_dtor,
};
Fn_ARGS_std_os_raw_c_void_dash_spv_platform_identity_storage_username_SaveUsernameContext_RTRN_ save_username = {
    .caller = &save_username_caller,
};
Fn_ARGS_std_os_raw_c_void_dash_spv_crypto_keys_key_KeyKind_dpp_identity_identity_public_key_security_level_SecurityLevel_dpp_identity_identity_public_key_purpose_Purpose_bool_RTRN_Result_ok_u32_err_dash_spv_platform_error_Error create_new_key = {
    .caller = &create_new_key_caller,
    .destructor = &create_new_key_dtor
};
Fn_ARGS_std_os_raw_c_void_bool_std_collections_Map_keys_u32_values_dash_spv_platform_identity_key_info_KeyInfo_RTRN_Result_ok_bool_err_dash_spv_platform_error_Error active_private_keys_are_loaded = {
    .caller = &active_private_keys_are_loaded_caller,
    .destructor = &active_private_keys_are_loaded_dtor
};

#define DIdentityModelNew(unique_id, registration_status, is_local, is_transient, main_index, main_key_type) dash_spv_platform_identity_model_IdentityModel_new(unique_id, registration_status, is_local, is_transient, main_index, main_key_type, get_derivation_context, save_key_status, save_remote_key_status, save_key_info, save_remote_key_info, save_username, get_private_key, create_new_key, active_private_keys_are_loaded)


@implementation DSIdentity

- (void)dealloc {
    if (_model != NULL)
        dash_spv_platform_identity_model_IdentityModel_destroy(_model);
}
// MARK: - Initialization

- (instancetype)initWithModel:(IdentityModel *)model onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    _model = model;
    self.chain = chain;
    return self;
}
- (instancetype)initWithUniqueId:(UInt256)uniqueId
                     isTransient:(BOOL)isTransient
                         onChain:(DSChain *)chain {
    //this is the initialization of a non local identity
    if (!(self = [super init])) return nil;
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    
    _model = DIdentityModelNew(u256_ctor_u(uniqueId), DIdentityRegistrationStatusRegistered(), NO, isTransient, 0, DKeyKindECDSA());
    self.chain = chain;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
                   inWallet:(DSWallet *)wallet {
    //this is the creation of a new blockchain identity
    NSParameterAssert(wallet);
    if (!(self = [super init])) return nil;
    self.wallet = wallet;

    _model = DIdentityModelNew(u256_ctor_u(UINT256_ZERO), DIdentityRegistrationStatusUnknown(), YES, NO, 0, DKeyKindECDSA());
    dash_spv_platform_identity_model_IdentityModel_set_index(self.model, index);
    self.chain = wallet.chain;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
                   uniqueId:(UInt256)uniqueId
                   inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    _model = DIdentityModelNew(u256_ctor_u(uniqueId), DIdentityRegistrationStatusRegistered(), YES, NO, 0, DKeyKindECDSA());
    dash_spv_platform_identity_model_IdentityModel_set_index(self.model, index);
    self.chain = wallet.chain;
    return self;
}

- (instancetype)initWithIdentityEntity:(DSBlockchainIdentityEntity *)entity {
    if (!(self = [self initWithUniqueId:entity.uniqueID.UInt256
                            isTransient:FALSE
                                onChain:entity.chain.chain])) return nil;
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity {
    if (!(self = [self initAtIndex:index
                withLockedOutpoint:lockedOutpoint
                          inWallet:wallet])) return nil;
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
               withUniqueId:(UInt256)uniqueId
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity {
    if (!(self = [self initAtIndex:index
                          uniqueId:uniqueId
                          inWallet:wallet])) return nil;
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity
     associatedToInvitation:(DSInvitation *)invitation {
    if (!(self = [self initAtIndex:index
                withLockedOutpoint:lockedOutpoint
                          inWallet:wallet])) return nil;
    [self setAssociatedInvitation:invitation];
    [self applyIdentityEntity:entity];
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet {
    
    NSAssert(dsutxo_hash_is_not_zero(lockedOutpoint), @"utxo must not be nil");
    if (!(self = [self initAtIndex:index uniqueId:[dsutxo_data(lockedOutpoint) SHA256_2] inWallet:wallet]))
        return nil;
    dash_spv_platform_identity_model_IdentityModel_set_locked_outpoint(self.model, DOutPointFromUTXO(lockedOutpoint));
//    self.lockedOutpoint = lockedOutpoint;
    DSLog(@"%@ initAtIndex: %u lockedOutpoint: %@: %lu", self.logPrefix, index, uint256_hex(lockedOutpoint.hash), lockedOutpoint.n);
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
   withAssetLockTransaction:(DSAssetLockTransaction *)transaction
                   inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [self initAtIndex:index withLockedOutpoint:transaction.lockedOutpoint inWallet:wallet]))
        return nil;
//    dash_spv_platform_identity_model_IdentityModel_set_registration_asset_lock_transaction(self.model, [transaction ffi_malloc:self.chain.chainType]);
    self.registrationAssetLockTransaction = transaction;
    return self;
}



- (void)saveProfileTimestamp {
    [self.platformContext performBlockAndWait:^{
        DIdentityModelSetLastCheckedProfileTimestamp(self.model, [NSDate timeIntervalSince1970]);
        //[self saveInContext:self.platformContext];
    }];
}

- (void)registerKeyFromKeyPathEntity:(DSBlockchainIdentityKeyPathEntity *)entity {
    DKeyKind *keyType = DKeyKindFromIndex(entity.keyType);
    DMaybeOpaqueKey *key = DMaybeOpaqueKeyWithPublicKeyData(keyType, slice_ctor(entity.publicKeyData));
    DSecurityLevel *level = DSecurityLevelFromIndex(entity.securityLevel);
    DPurpose *purpose = DPurposeFromIndex(entity.purpose);
    DIdentityModelSetKeysCreated(self.model, MAX(DIdentityModelKeysCreated(self.model), entity.keyID + 1));
    [self addKeyInfo:key->ok
       securityLevel:level
             purpose:purpose
              status:DIdentityKeyStatusFromIndex(entity.keyStatus)
               index:entity.keyID];
}
- (void)applyIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity {
    [self applyUsernameEntitiesFromIdentityEntity:identityEntity];
    DIdentityModelSetBalance(self.model, identityEntity.creditBalance);
    DIdentityModelSetStatus(self.model, DIdentityRegistrationStatusFromIndex(identityEntity.registrationStatus));
    DIdentityModelSetLastCheckedProfileTimestamp(self.model, identityEntity.lastCheckedProfileTimestamp);
    DIdentityModelSetLastCheckedUsernamesTimestamp(self.model, identityEntity.lastCheckedUsernamesTimestamp);
    DIdentityModelSetLastCheckedIncomingContactsTimestamp(self.model, identityEntity.lastCheckedIncomingContactsTimestamp);
    DIdentityModelSetLastCheckedOutgoingContactsTimestamp(self.model, identityEntity.lastCheckedOutgoingContactsTimestamp);
    NSData *dashpaySyncronizationBlockHash = identityEntity.dashpaySyncronizationBlockHash;
    if (dashpaySyncronizationBlockHash)
        self.dashpaySyncronizationBlockHash = dashpaySyncronizationBlockHash.UInt256;
    for (DSBlockchainIdentityKeyPathEntity *keyPathEntity in identityEntity.keyPaths) {
        NSIndexPath *keyIndexPath = (NSIndexPath *)[keyPathEntity path];
        DKeyKind *keyType = DKeyKindFromIndex(keyPathEntity.keyType);
        BOOL added = NO;
        if (keyIndexPath) {
            DSecurityLevel *level = DSecurityLevelFromIndex(keyPathEntity.securityLevel);
            DPurpose *purpose = DPurposeFromIndex(keyPathEntity.purpose);
            DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:keyType];
            NSIndexPath *nonhardenedPath = [keyIndexPath softenAllItems];
            NSIndexPath *hardenedPath = [nonhardenedPath hardenAllItems];
            DOpaqueKey *key = [derivationPath publicKeyAtIndexPathAsOpt:hardenedPath];
            if (key) {
                uint32_t index = (uint32_t)[nonhardenedPath indexAtPosition:[nonhardenedPath length] - 1];
                DIdentityModelSetKeysCreated(self.model, MAX(DIdentityModelKeysCreated(self.model), index + 1));
                DKeyInfo *key_info = DKeyInfoCtor(key, DIdentityKeyStatusFromIndex(keyPathEntity.keyStatus), level, purpose);
                DIdentityModelAddKeyInfo(self.model, index, key_info);
                added = YES;
            }
        }
        if (!added)
            [self registerKeyFromKeyPathEntity:keyPathEntity];
    }
    if (self.isLocal || self.isOutgoingInvitation) {
        if (identityEntity.registrationFundingTransaction) {
            self.registrationAssetLockTransactionHash = identityEntity.registrationFundingTransaction.transactionHash.txHash.UInt256;
            DSLog(@"%@ AssetLockTX: Entity Attached: txHash: %@: entity: %@", self.logPrefix, uint256_hex(self.registrationAssetLockTransactionHash), identityEntity.registrationFundingTransaction);
        } else {
            NSData *transactionHashData = uint256_data(uint256_reverse(self.lockedOutpoint.hash));
            DSLog(@"%@ AssetLockTX: Load: lockedOutpoint: %@: %lu %@", self.logPrefix, uint256_hex(self.lockedOutpoint.hash), self.lockedOutpoint.n, transactionHashData.hexString);
            DSAssetLockTransactionEntity *assetLockEntity = [DSAssetLockTransactionEntity anyObjectInContext:identityEntity.managedObjectContext matching:@"transactionHash.txHash == %@", transactionHashData];
            if (assetLockEntity) {
                self.registrationAssetLockTransactionHash = assetLockEntity.transactionHash.txHash.UInt256;
                DSLog(@"%@ AssetLockTX: Entity Found for txHash: %@", self.logPrefix, uint256_hex(self.registrationAssetLockTransactionHash));
                DSAssetLockTransaction *registrationAssetLockTransaction = (DSAssetLockTransaction *)[assetLockEntity transactionForChain:self.chain];
                BOOL correctIndex = self.isOutgoingInvitation ?
                    [registrationAssetLockTransaction checkInvitationDerivationPathIndexForWallet:self.wallet isIndex:self.index] :
                    [registrationAssetLockTransaction checkDerivationPathIndexForWallet:self.wallet isIndex:self.index];
                if (!correctIndex) {
                    DSLog(@"%@ AssetLockTX: IncorrectIndex %u (%@)", self.logPrefix, self.index, registrationAssetLockTransaction.toData.hexString);
                    //NSAssert(FALSE, @"We should implement this");
                }
            }
        }
    }
}

- (BOOL)isLocal {
    return dash_spv_platform_identity_model_IdentityModel_is_local(self.model);
}
- (BOOL)isTransient {
    return dash_spv_platform_identity_model_IdentityModel_is_transient(self.model);
}

- (uint64_t)creditBalance {
    return dash_spv_platform_identity_model_IdentityModel_credit_balance(self.model);
}

- (BOOL)isOutgoingInvitation {
    return dash_spv_platform_identity_model_IdentityModel_is_outgoing_invitation(self.model);
}

- (BOOL)isFromIncomingInvitation {
    return dash_spv_platform_identity_model_IdentityModel_is_from_incoming_invitation(self.model);
}

- (uint32_t)index {
    return DIdentityModelIndex(self.model);
}

- (uint32_t)currentMainKeyIndex {
    return dash_spv_platform_identity_model_IdentityModel_current_main_index(self.model);
}

- (DKeyKind *)currentMainKeyType {
    return dash_spv_platform_identity_model_IdentityModel_current_main_key_type(self.model);
}

- (void)setAssociatedInvitation:(DSInvitation *)associatedInvitation {
    _associatedInvitation = associatedInvitation;
    // It was created locally, we are sending the invite
    if (associatedInvitation.createdLocally) {
        dash_spv_platform_identity_model_IdentityModel_set_is_outgoing_invitation(self.model, YES);
        dash_spv_platform_identity_model_IdentityModel_set_is_from_incoming_invitation(self.model, NO);
        dash_spv_platform_identity_model_IdentityModel_set_is_local(self.model, NO);
    } else {
        // It was created on another device, we are receiving the invite
        dash_spv_platform_identity_model_IdentityModel_set_is_outgoing_invitation(self.model, NO);
        dash_spv_platform_identity_model_IdentityModel_set_is_from_incoming_invitation(self.model, YES);
        dash_spv_platform_identity_model_IdentityModel_set_is_local(self.model, YES);
    }
}

- (dispatch_queue_t)identityQueue {
    if (_identityQueue) return _identityQueue;
    _identityQueue = self.chain.chainManager.identitiesManager.identityQueue;
    return _identityQueue;
}

// MARK: - Full Registration agglomerate

- (DSIdentityRegistrationStep)stepsCompleted {
    DSIdentityRegistrationStep stepsCompleted = DSIdentityRegistrationStep_None;
    if (self.isRegistered) {
        stepsCompleted = DSIdentityRegistrationStep_RegistrationSteps;
        if (dash_spv_platform_identity_model_IdentityModel_confirmed_username_full_paths_count(self.model))
            stepsCompleted |= DSIdentityRegistrationStep_Username;
    } else if (self.registrationAssetLockTransaction) {
        stepsCompleted |= DSIdentityRegistrationStep_FundingTransactionCreation;
        DSAccount *account = [self.chain firstAccountThatCanContainTransaction:self.registrationAssetLockTransaction];
        if (self.registrationAssetLockTransaction.blockHeight != TX_UNCONFIRMED || [account transactionIsVerified:self.registrationAssetLockTransaction])
            stepsCompleted |= DSIdentityRegistrationStep_FundingTransactionAccepted;
        if ([self isRegisteredInWallet])
            stepsCompleted |= DSIdentityRegistrationStep_LocalInWalletPersistence;
        if (self.registrationAssetLockTransaction.instantSendLockAwaitingProcessing)
            stepsCompleted |= DSIdentityRegistrationStep_ProofAvailable;
    }
    return stepsCompleted;
}

- (void)continueRegisteringProfileOnNetwork:(DSIdentityRegistrationStep)steps
                             stepsCompleted:(DSIdentityRegistrationStep)stepsAlreadyCompleted
                             stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                                 completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *error))completion {
    __block DSIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
    if (!(steps & DSIdentityRegistrationStep_Profile)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    [self signAndPublishProfileWithCompletion:^(BOOL success, BOOL cancelled, NSError *_Nullable error) {
        if (!success) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[error]); });
            return;
        }
        if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_Profile); });
        stepsCompleted |= DSIdentityRegistrationStep_Profile;
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
    }];
    //todo:we need to still do profile
}

- (void)continueRegisteringUsernamesOnNetwork:(DSIdentityRegistrationStep)steps
                               stepsCompleted:(DSIdentityRegistrationStep)stepsAlreadyCompleted
                               stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                                   completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
    __block DSIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
    if (!(steps & DSIdentityRegistrationStep_Username)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    [self registerUsernamesWithCompletion:^(BOOL success, NSArray<NSError *> *errors) {
        if (!success) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, errors); });
            return;
        }
        if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_Username); });
        stepsCompleted |= DSIdentityRegistrationStep_Username;
        [self continueRegisteringProfileOnNetwork:steps
                                   stepsCompleted:stepsCompleted
                                   stepCompletion:stepCompletion
                                       completion:completion];
    }];
}

- (void)continueRegisteringIdentityOnNetwork:(DSIdentityRegistrationStep)steps
                              stepsCompleted:(DSIdentityRegistrationStep)stepsAlreadyCompleted
                              stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                                  completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
    __block DSIdentityRegistrationStep stepsCompleted = stepsAlreadyCompleted;
    if (!(steps & DSIdentityRegistrationStep_Identity)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    [self createAndPublishRegistrationTransitionWithCompletion:^(BOOL success, NSError *_Nullable error) {
        if (error) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[error]); });
            return;
        }
        if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_Identity); });
        stepsCompleted |= DSIdentityRegistrationStep_Identity;
        [self continueRegisteringUsernamesOnNetwork:steps
                                     stepsCompleted:stepsCompleted
                                     stepCompletion:stepCompletion
                                         completion:completion];
    }];
}

- (void)continueRegisteringOnNetwork:(DSIdentityRegistrationStep)steps
                  withFundingAccount:(DSAccount *)fundingAccount
                      forTopupAmount:(uint64_t)topupDuffAmount
                           pinPrompt:(NSString *)prompt
                      stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                          completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
    [self continueRegisteringOnNetwork:steps
                    withFundingAccount:fundingAccount
                        forTopupAmount:topupDuffAmount
                             pinPrompt:prompt
                             inContext:self.platformContext
                        stepCompletion:stepCompletion
                            completion:completion];
}

- (void)continueRegisteringOnNetwork:(DSIdentityRegistrationStep)steps
                  withFundingAccount:(DSAccount *)fundingAccount
                      forTopupAmount:(uint64_t)topupDuffAmount
                           pinPrompt:(NSString *)prompt
                           inContext:(NSManagedObjectContext *)context
                      stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                          completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
    if (!self.registrationAssetLockTransaction) {
        [self registerOnNetwork:steps
             withFundingAccount:fundingAccount
                 forTopupAmount:topupDuffAmount
                      pinPrompt:prompt
                 stepCompletion:stepCompletion
                     completion:completion];
    } else if (dash_spv_platform_identity_model_IdentityModel_is_registered(self.model)) {
        [self continueRegisteringIdentityOnNetwork:steps
                                    stepsCompleted:DSIdentityRegistrationStep_L1Steps
                                    stepCompletion:stepCompletion
                                        completion:completion];
    } else if (dash_spv_platform_identity_model_IdentityModel_unregistered_username_full_paths_count(self.model)) {
        [self continueRegisteringUsernamesOnNetwork:steps
                                     stepsCompleted:DSIdentityRegistrationStep_L1Steps | DSIdentityRegistrationStep_Identity
                                     stepCompletion:stepCompletion
                                         completion:completion];
    } else if ([self matchingDashpayUserInContext:context].remoteProfileDocumentRevision < 1) {
        [self continueRegisteringProfileOnNetwork:steps
                                   stepsCompleted:DSIdentityRegistrationStep_L1Steps | DSIdentityRegistrationStep_Identity
                                   stepCompletion:stepCompletion
                                       completion:completion];
    }
}

//- (void)submitAssetLockTransactionAndWaitForInstantSendLock:(DSAssetLockTransaction *)assetLockTransaction
//                                         withFundingAccount:(DSAccount *)fundingAccount
//                                                registrator:(BOOL (^_Nullable)(DSAssetLockTransaction *assetLockTransaction))registrator
//                                                  pinPrompt:(NSString *)prompt
//                                       completion:(void (^_Nullable)(BOOL success, BOOL cancelled, NSError *error))completion {
//    [fundingAccount signTransaction:assetLockTransaction
//                         withPrompt:prompt
//                         completion:^(BOOL signedTransaction, BOOL cancelled) {
//        if (!signedTransaction) {
//            if (completion)
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    completion(NO, cancelled, cancelled ? nil : ERROR_FUNDING_TX_SIGNING);
//                });
//            return;
//        }
//        BOOL canContinue = registrator(assetLockTransaction);
//        if (!canContinue)
//            return;
//
//    }];
//}

- (void)publishTransactionAndWait:(DSAssetLockTransaction *)transaction
                       completion:(void (^_Nullable)(BOOL published, DSInstantSendTransactionLock *_Nullable instantSendLock, NSError *_Nullable error))completion {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block BOOL transactionSuccessfullyPublished = FALSE;
    __block DSInstantSendTransactionLock *instantSendLock = nil;
    __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                                            object:nil
                                                                             queue:nil
                                                                        usingBlock:^(NSNotification *note) {
        DSTransaction *tx = [note.userInfo objectForKey:DSTransactionManagerNotificationTransactionKey];
        if ([tx isEqual:transaction]) {
            NSDictionary *changes = [note.userInfo objectForKey:DSTransactionManagerNotificationTransactionChangesKey];
            if (changes) {
                NSNumber *accepted = changes[DSTransactionManagerNotificationTransactionAcceptedStatusKey];
                NSNumber *lockVerified = changes[DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey];
                DSInstantSendTransactionLock *lock = changes[DSTransactionManagerNotificationInstantSendTransactionLockKey];
                if ([lockVerified boolValue] && lock != nil) {
                    instantSendLock = lock;
                    transactionSuccessfullyPublished = TRUE;
                    dispatch_semaphore_signal(sem);
                } else if ([accepted boolValue]) {
                    transactionSuccessfullyPublished = TRUE;
                }
            }
        }
    }];
    [self.chain.chainManager.transactionManager publishTransaction:transaction completion:^(NSError *_Nullable error) {
        if (error) {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
            completion(NO, nil, error);
            return;
        }
        dispatch_async(self.identityQueue, ^{
            dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_SEC));
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
            completion(transactionSuccessfullyPublished, instantSendLock, nil);
        });
    }];

}

- (void)registerOnNetwork:(DSIdentityRegistrationStep)steps
       withFundingAccount:(DSAccount *)fundingAccount
           forTopupAmount:(uint64_t)topupDuffAmount
                pinPrompt:(NSString *)prompt
           stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
               completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion {
    DSLog(@"%@ Register On Network: %@", self.logPrefix, DSRegistrationStepsDescription(steps));
    __block DSIdentityRegistrationStep stepsCompleted = DSIdentityRegistrationStep_None;
    if (![self hasIdentityExtendedPublicKeys]) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[ERROR_REGISTER_KEYS_BEFORE_IDENTITY]); });
        return;
    }
    if (!(steps & DSIdentityRegistrationStep_FundingTransactionCreation)) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
        return;
    }
    NSString *assetLockRegistrationAddress = [self registrationFundingAddress];

    DSAssetLockTransaction *assetLockTransaction = [fundingAccount assetLockTransactionFor:topupDuffAmount
                                                                                        to:assetLockRegistrationAddress
                                                                                   withFee:YES];
    if (!assetLockTransaction) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[ERROR_FUNDING_TX_CREATION]); });
        return;
    }
    [fundingAccount signTransaction:assetLockTransaction
                         withPrompt:prompt
                         completion:^(BOOL signedTransaction, BOOL cancelled) {
        if (!signedTransaction) {
            if (completion)
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (cancelled) stepsCompleted |= DSIdentityRegistrationStep_Cancelled;
                    completion(stepsCompleted, cancelled ? nil : @[ERROR_FUNDING_TX_SIGNING]);
                });
            return;
        }
        if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_FundingTransactionCreation); });
        stepsCompleted |= DSIdentityRegistrationStep_FundingTransactionCreation;
        
        //In wallet registration occurs now
        
        if (!(steps & DSIdentityRegistrationStep_LocalInWalletPersistence)) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
            return;
        }
        if (self.isOutgoingInvitation) {
            [self.associatedInvitation registerInWalletForAssetLockTransaction:assetLockTransaction];
        } else {
            [self registerInWalletForAssetLockTransaction:assetLockTransaction];
        }
        if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_LocalInWalletPersistence); });
        stepsCompleted |= DSIdentityRegistrationStep_LocalInWalletPersistence;
        if (!(steps & DSIdentityRegistrationStep_FundingTransactionAccepted)) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, nil); });
            return;
        }
        [self publishTransactionAndWait:assetLockTransaction
                             completion:^(BOOL published, DSInstantSendTransactionLock *_Nullable instantSendLock, NSError *_Nullable error) {
            if (!self) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[ERROR_MEM_ALLOC]); });
                return;
            }
            if (!published) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[ERROR_FUNDING_TX_TIMEOUT]); });
                return;
            }
            if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_FundingTransactionAccepted); });
            stepsCompleted |= DSIdentityRegistrationStep_FundingTransactionAccepted;
            if (!instantSendLock) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(stepsCompleted, @[ERROR_FUNDING_TX_ISD_TIMEOUT]); });
                return;
            }
            if (stepCompletion) dispatch_async(dispatch_get_main_queue(), ^{ stepCompletion(DSIdentityRegistrationStep_ProofAvailable); });
            stepsCompleted |= DSIdentityRegistrationStep_ProofAvailable;
            [self continueRegisteringIdentityOnNetwork:steps
                                        stepsCompleted:stepsCompleted
                                        stepCompletion:stepCompletion
                                            completion:completion];

        }];
    }];
}

// MARK: - Local Registration and Generation

- (BOOL)hasIdentityExtendedPublicKeys {
    NSAssert(self.isLocal || self.isOutgoingInvitation, @"This should not be performed on a non local identity (but can be done for an invitation)");
    if (!self.isLocal && !self.isOutgoingInvitation) return FALSE;
    if (self.isLocal) {
        return [self.wallet hasExtendedPublicKeyForDerivationPathOfKind:DSDerivationPathKind_IdentityBLS]
        && [self.wallet hasExtendedPublicKeyForDerivationPathOfKind:DSDerivationPathKind_IdentityECDSA]
        && [self.wallet hasExtendedPublicKeyForDerivationPathOfKind:DSDerivationPathKind_IdentityRegistrationFunding]
        && [self.wallet hasExtendedPublicKeyForDerivationPathOfKind:DSDerivationPathKind_IdentityTopupFunding];
    } else if (self.isOutgoingInvitation) {
        return [self.wallet hasExtendedPublicKeyForDerivationPathOfKind:DSDerivationPathKind_InvitationFunding];
    } else {
        return NO;
    }
}

- (void)generateIdentityExtendedPublicKeysWithPrompt:(NSString *)prompt
                                          completion:(void (^_Nullable)(BOOL registered))completion {
    BOOL isLocal = self.isLocal;
    NSAssert(isLocal || self.isOutgoingInvitation, @"This should not be performed on a non local identity (but can be done for an invitation)");
    if (!isLocal && !self.isOutgoingInvitation) return;
    if ([self hasIdentityExtendedPublicKeys]) {
        if (completion) completion(YES);
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt
                                                   forWallet:self.wallet
                                                   forAmount:0
                                         forceAuthentication:NO
                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
        if (!seed) {
            if (completion) completion(NO);
            return;
        }
        if (self.isLocal) {
            [self.wallet generateExtendedPublicKeyFromSeedForDerivationPathKind:seed kind:DSDerivationPathKind_IdentityBLS];
            [self.wallet generateExtendedPublicKeyFromSeedForDerivationPathKind:seed kind:DSDerivationPathKind_IdentityECDSA];
            if (!self.isOutgoingInvitation) {
                [self.wallet generateExtendedPublicKeyFromSeedForDerivationPathKind:seed kind:DSDerivationPathKind_IdentityRegistrationFunding];
                [self.wallet generateExtendedPublicKeyFromSeedForDerivationPathKind:seed kind:DSDerivationPathKind_IdentityTopupFunding];
            }
        }
        if (self.isOutgoingInvitation) {
            [self.wallet generateExtendedPublicKeyFromSeedForDerivationPathKind:seed kind:DSDerivationPathKind_InvitationFunding];
        }
        if (completion) completion(YES);
    }];
}

- (void)registerInWalletForAssetLockTransaction:(DSAssetLockTransaction *)transaction {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal) return;
    self.registrationAssetLockTransactionHash = transaction.txHash;
    DSUTXO lockedOutpoint = transaction.lockedOutpoint;
    UInt256 creditBurnIdentityIdentifier = transaction.creditBurnIdentityIdentifier;
    DSLog(@"%@ Register In Wallet (AssetLockTx Register): txHash: %@: creditBurnIdentityID: %@, creditBurnPublicKeyHash: %@, lockedOutpoint: %@: %lu", self.logPrefix, uint256_hex(transaction.txHash), uint256_hex(creditBurnIdentityIdentifier), uint160_hex(transaction.creditBurnPublicKeyHash), uint256_hex(lockedOutpoint.hash), lockedOutpoint.n);
//    self.lockedOutpoint = lockedOutpoint;
    dash_spv_platform_identity_model_IdentityModel_set_locked_outpoint(self.model, DOutPointFromUTXO(lockedOutpoint));
    [self registerInWalletForIdentityUniqueId:creditBurnIdentityIdentifier];
    //we need to also set the address of the funding transaction to being used so future identities past the initial gap limit are found
    [transaction markAddressAsUsedInWallet:self.wallet];
}

- (void)registerInWalletForAssetLockTopupTransaction:(DSAssetLockTransaction *)transaction {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal) return;
    [self.topupAssetLockTransactionHashes addObject:uint256_data(transaction.txHash)];

    DSUTXO lockedOutpoint = transaction.lockedOutpoint;
    UInt256 creditBurnIdentityIdentifier = transaction.creditBurnIdentityIdentifier;
    DSLog(@"%@ Register In Wallet (AssetLockTx TopUp): txHash: %@: creditBurnIdentityID: %@, creditBurnPublicKeyHash: %@, lockedOutpoint: %@: %lu", self.logPrefix, uint256_hex(transaction.txHash), uint256_hex(creditBurnIdentityIdentifier), uint160_hex(transaction.creditBurnPublicKeyHash), uint256_hex(lockedOutpoint.hash), lockedOutpoint.n);
//    self.lockedOutpoint = lockedOutpoint;
    dash_spv_platform_identity_model_IdentityModel_set_locked_outpoint(self.model, DOutPointFromUTXO(lockedOutpoint));
    [self registerInWalletForIdentityUniqueId:creditBurnIdentityIdentifier];
    //we need to also set the address of the funding transaction to being used so future identities past the initial gap limit are found
    [transaction markAddressAsUsedInWallet:self.wallet];
}

- (void)registerInWalletForIdentityUniqueId:(UInt256)identityUniqueId {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal) return;
    dash_spv_platform_identity_model_IdentityModel_set_unique_id(self.model, u256_ctor_u(identityUniqueId));
//    self.uniqueID = identityUniqueId;
    [self registerInWallet];
}

- (BOOL)isRegisteredInWallet {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal || !self.wallet) return FALSE;
    return [self.wallet containsIdentity:self];
}

- (void)registerInWallet {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal) return;
    [self.wallet registerIdentity:self];
    [self saveInitial];
}

- (BOOL)unregisterLocally {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal) return FALSE;
    if (self.isRegistered) return FALSE; //if it is already registered we can not unregister it from the wallet
    [self.wallet unregisterIdentity:self];
    [self deletePersistentObjectAndSave:YES inContext:self.platformContext];
    return TRUE;
}

- (void)setInvitationUniqueId:(UInt256)uniqueId {
    NSAssert(self.isOutgoingInvitation, @"This can only be done on an invitation");
    if (!self.isOutgoingInvitation) return;
    dash_spv_platform_identity_model_IdentityModel_set_unique_id(self.model, u256_ctor_u(uniqueId));
}

- (void)setInvitationAssetLockTransaction:(DSAssetLockTransaction *)transaction {
    NSParameterAssert(transaction);
    NSAssert(self.isOutgoingInvitation, @"This can only be done on an invitation");
    if (!self.isOutgoingInvitation) return;
    self.registrationAssetLockTransaction = transaction;
    dash_spv_platform_identity_model_IdentityModel_set_locked_outpoint(self.model, DOutPointFromUTXO(transaction.lockedOutpoint));

}

// MARK: - Read Only Property Helpers

- (BOOL)isActive {
    if (self.isLocal) {
        if (!self.wallet) return NO;
        return self.wallet.identities[self.uniqueIDData] != nil;
    } else {
        return [self.chain.chainManager.identitiesManager foreignIdentityWithUniqueId:self.uniqueID] != nil;
    }
}

- (DSAssetLockTransaction *)registrationAssetLockTransaction {
    if (!_registrationAssetLockTransaction)
        _registrationAssetLockTransaction = (DSAssetLockTransaction *)[self.chain transactionForHash:self.registrationAssetLockTransactionHash];
    return _registrationAssetLockTransaction;
}

- (UInt256)uniqueID {
    u256 *unique_id = dash_spv_platform_identity_model_IdentityModel_unique_id(self.model);
    UInt256 result = u256_cast(unique_id);
    u256_dtor(unique_id);
    return result;
}

- (NSData *)uniqueIDData {
    u256 *unique_id = dash_spv_platform_identity_model_IdentityModel_unique_id(self.model);
    NSData *result = NSDataFromPtr(unique_id);
    u256_dtor(unique_id);
    return result;
}

- (DSUTXO)lockedOutpoint {
    DOutPoint *outpoint = dash_spv_platform_identity_model_IdentityModel_locked_outpoint(self.model);
    if (!outpoint)
        return DSUTXO_ZERO;
    DSUTXO utxo = (((DSUTXO){u256_cast(dashcore_hash_types_Txid_inner(outpoint->txid)), outpoint->vout}));
    DOutPointDtor(outpoint);
    return utxo;
}

- (NSData *)lockedOutpointData {
    return dsutxo_data(self.lockedOutpoint);
}

- (NSString *)currentDashpayUsername {
    return [self.dashpayUsernames firstObject];
}

- (NSArray<DSDerivationPath *> *)derivationPaths {
    if (!self.isLocal) return nil;
    return [[DSDerivationPathFactory sharedInstance] unloadedSpecializedDerivationPathsForWallet:self.wallet];
}

- (NSString *)uniqueIdString {
    return [uint256_data(self.uniqueID) base58String];
}

- (dispatch_queue_t)networkingQueue {
    return self.chain.networkingQueue;
}

- (NSManagedObjectContext *)platformContext {
    //    NSAssert(![NSThread isMainThread], @"We should not be on main thread");
    return [NSManagedObjectContext platformContext];
}

- (DSIdentitiesManager *)identitiesManager {
    return self.chain.chainManager.identitiesManager;
}

// ECDSA
- (DOpaqueKey *)registrationFundingPrivateKey {
    return dash_spv_platform_identity_model_IdentityModel_registration_funding_private_key(self.model);
}
- (DOpaqueKey *)topupFundingPrivateKey {
    return dash_spv_platform_identity_model_IdentityModel_topup_funding_private_key(self.model);
}

- (UInt256)dashpaySyncronizationBlockHash {
    u256 *block_hash = dash_spv_platform_identity_model_IdentityModel_sync_block_hash(self.model);
    UInt256 blockHash = u256_cast(block_hash);
    u256_dtor(block_hash);
    return blockHash;
}

- (void)setDashpaySyncronizationBlockHash:(UInt256)dashpaySyncronizationBlockHash {
    dash_spv_platform_identity_model_IdentityModel_set_sync_block_hash(self.model, u256_ctor_u(dashpaySyncronizationBlockHash));
    if (uint256_is_zero(dashpaySyncronizationBlockHash)) {
        _dashpaySyncronizationBlockHeight = 0;
    } else {
        _dashpaySyncronizationBlockHeight = [self.chain heightForBlockHash:dashpaySyncronizationBlockHash];
        if (_dashpaySyncronizationBlockHeight == UINT32_MAX)
            _dashpaySyncronizationBlockHeight = 0;
    }
}


// MARK: - Keys

- (BOOL)createFundingPrivateKeyWithSeed:(NSData *)seed
                        isForInvitation:(BOOL)isForInvitation {
    DSDerivationPathKind kind = isForInvitation ? DSDerivationPathKind_InvitationFunding : DSDerivationPathKind_IdentityRegistrationFunding;
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndex:self.index];
    DOpaqueKey *key = [[DSDerivationPathFactory sharedInstance] privateKeyAtIndexPath:indexPath
                                                                             fromSeed:seed
                                                                               ofKind:kind
                                                                            forWallet:self.wallet];
    BOOL ok = key != NULL;
    dash_spv_platform_identity_model_IdentityModel_set_registration_funding_private_key(self.model, key);
    return ok;
}
- (BOOL)createTopupFundingPrivateKeyWithSeed:(NSData *)seed {
    DSDerivationPathKind kind = DSDerivationPathKind_IdentityTopupFunding;
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndex:self.index];
    DOpaqueKey *key = [[DSDerivationPathFactory sharedInstance] privateKeyAtIndexPath:indexPath
                                                                             fromSeed:seed
                                                                               ofKind:kind
                                                                            forWallet:self.wallet];
    BOOL ok = key != NULL;
    dash_spv_platform_identity_model_IdentityModel_set_topup_funding_private_key(self.model, key);
    return ok;
}

- (BOOL)setExternalFundingPrivateKey:(DOpaqueKey *)privateKey {
    if (!self.isFromIncomingInvitation) return FALSE;
    BOOL ok = privateKey != NULL;
    dash_spv_platform_identity_model_IdentityModel_set_registration_funding_private_key(self.model, privateKey);
//    self.internalRegistrationFundingPrivateKey = privateKey;
    return ok;
}

- (void)createFundingPrivateKeyForInvitationWithPrompt:(NSString *)prompt
                                            completion:(void (^_Nullable)(BOOL success, BOOL cancelled))completion {
    [self createFundingPrivateKeyWithPrompt:prompt
                            isForInvitation:YES
                                 completion:completion];
}

- (void)createFundingPrivateKeyWithPrompt:(NSString *)prompt
                               completion:(void (^_Nullable)(BOOL success, BOOL cancelled))completion {
    [self createFundingPrivateKeyWithPrompt:prompt
                            isForInvitation:NO
                                 completion:completion];
}

- (void)createFundingPrivateKeyWithPrompt:(NSString *)prompt
                          isForInvitation:(BOOL)isForInvitation
                               completion:(void (^_Nullable)(BOOL success, BOOL cancelled))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt
                                                       forWallet:self.wallet
                                                       forAmount:0
                                             forceAuthentication:NO
                                                      completion:^(NSData *_Nullable seed, BOOL cancelled) {
            if (!seed) {
                if (completion) completion(NO, cancelled);
                return;
            }
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                BOOL success = [self createFundingPrivateKeyWithSeed:seed isForInvitation:isForInvitation];
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(success, NO); });
            });
        }];
    });
}

- (BOOL)activePrivateKeysAreLoadedWithFetchingError:(NSError **)error {
    BOOL loaded = YES;
    DKeyInfoDictionaries *key_infos = DGetRegisteredKeyInfoDictionaries(self.model);
    for (uint32_t index = 0; index < key_infos->count; index++) {
        DKeyInfo *key_info = key_infos->values[index];
        NSIndexPath *indexPath = [self hardenedIndexPathForIndex:key_infos->keys[index]];
        DKeyKind *kind = dash_spv_platform_identity_key_info_KeyInfo_kind(key_info);
        DSDerivationPath *derivationPath = [self derivationPathForType:kind];
        DKeyKindDtor(kind);
        loaded &= !self.isLocal ? NO : hasKeychainData([self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath], error);
        if (*error) {
            DKeyInfoDictionariesDtor(key_infos);
            return NO;
        }
    }
    DKeyInfoDictionariesDtor(key_infos);
    return loaded;
}

- (uintptr_t)activeKeyCount {
    return dash_spv_platform_identity_model_IdentityModel_active_key_count(self.model);
}

- (uintptr_t)totalKeyCount {
    return dash_spv_platform_identity_model_IdentityModel_total_key_count(self.model);
}

- (BOOL)verifyKeysForWallet:(DSWallet *)wallet {
    DSWallet *originalWallet = self.wallet;
    self.wallet = wallet;
    DKeyInfoDictionaries *key_info_dictionaries = DGetKeyInfoDictionaries(self.model);
    for (uint32_t index = 0; index < key_info_dictionaries->count; index++) {
        DKeyInfo *key_info = key_info_dictionaries->values[index];
        if (!key_info->key) {
            self.wallet = originalWallet;
            DKeyInfoDictionariesDtor(key_info_dictionaries);
            return NO;
        }
        DOpaqueKey *key = [self keyAtIndex:index];
        DKeyKind *key_kind = dash_spv_platform_identity_key_info_KeyInfo_kind(key_info);
        BOOL hasSameKind = DOpaqueKeyHasKind(key, key_kind);
        if (!hasSameKind) {
            self.wallet = originalWallet;
            DKeyKindDtor(key_kind);
            DKeyInfoDictionariesDtor(key_info_dictionaries);
            return NO;
        }
        DOpaqueKey *derivedKey = [self publicKeyAtIndex:index ofType:key_kind];
        if (!derivedKey) {
            DKeyKindDtor(key_kind);
            DKeyInfoDictionariesDtor(key_info_dictionaries);
            return NO;
        }
        BOOL isEqual = [DSKeyManager keysPublicKeyDataIsEqual:derivedKey key2:key];
        DOpaqueKeyDtor(derivedKey);
        if (!isEqual) {
            self.wallet = originalWallet;
            DKeyKindDtor(key_kind);
            DKeyInfoDictionariesDtor(key_info_dictionaries);
            return NO;
        }
        DKeyKindDtor(key_kind);
    }
    DKeyInfoDictionariesDtor(key_info_dictionaries);
    return TRUE;
}

- (DIdentityKeyStatus *)statusOfKeyAtIndex:(NSUInteger)index {
    return dash_spv_platform_identity_model_IdentityModel_status_of_key_at_index(self.model, (uint32_t) index);
}

- (DOpaqueKey *_Nullable)keyAtIndex:(NSUInteger)index {
    return dash_spv_platform_identity_model_IdentityModel_key_at_index(self.model, (uint32_t) index);
}
- (BOOL)hasKeyAtIndex:(NSUInteger)index {
    return dash_spv_platform_identity_model_IdentityModel_has_key_at_index(self.model, (uint32_t) index);
}

- (NSString *)localizedStatusOfKeyAtIndex:(NSUInteger)index {
    return [[self class] localizedStatusOfKeyForIdentityKeyStatus:[self statusOfKeyAtIndex:index]];
}

+ (NSString *)localizedStatusOfKeyForIdentityKeyStatus:(DIdentityKeyStatus *)status {
    char *str = dash_spv_platform_identity_key_status_IdentityKeyStatus_string(status);
    char *desc = dash_spv_platform_identity_key_status_IdentityKeyStatus_string_description(status);
    NSString *localizedStatus = DSLocalizedString(NSStringFromPtr(str), NSStringFromPtr(desc));
    DCharDtor(str);
    DCharDtor(desc);
    return localizedStatus;
}

- (DSAuthenticationKeysDerivationPath *)derivationPathForType:(DKeyKind *)type {
    if (!self.isLocal) return nil;
    // TODO: ed25519 + bls basic
    int16_t index = DKeyKindIndex(type);
    switch (index) {
        case dash_spv_crypto_keys_key_KeyKind_ECDSA:
            return [[DSDerivationPathFactory sharedInstance] identityECDSAKeysDerivationPathForWallet:self.wallet];
        case dash_spv_crypto_keys_key_KeyKind_BLS:
        case dash_spv_crypto_keys_key_KeyKind_BLSBasic:
            return [[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:self.wallet];
        default:
            return nil;
    }
}

- (NSIndexPath *)hardenedIndexPathForIndex:(uint32_t)index {
    const NSUInteger indexes[] = {DIdentityModelIndex(self.model) | BIP32_HARD, index | BIP32_HARD};
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    return indexPath;
}

- (NSIndexPath *)indexPathForIndex:(uint32_t)index {
    const NSUInteger indexes[] = {DIdentityModelIndex(self.model), index};
    NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
    return indexPath;
}

- (DOpaqueKey *_Nullable)privateKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type {
    if (!self.isLocal) return nil;
    NSIndexPath *indexPath = [self hardenedIndexPathForIndex:index];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    NSError *error = nil;
    NSString *identifier = [self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath];
    NSData *keySecret = getKeychainData(identifier, &error);
    NSAssert(keySecret, @"This should be present");
    if (!keySecret || error) return nil;
    Slice_u8 *slice = slice_ctor(keySecret);
    return DMaybeOpaqueKeyWithPrivateKeyDataAsOpt(type, slice);
}

- (DOpaqueKey *)derivePrivateKeyAtIndexPath:(NSIndexPath *)indexPath ofType:(DKeyKind *)type {
    if (!self.isLocal) return nil;
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath privateKeyAtIndexPathAsOpt:[indexPath hardenAllItems]];
}

- (DOpaqueKey *_Nullable)publicKeyAtIndex:(uint32_t)index ofType:(DKeyKind *)type {
    if (!self.isLocal) return nil;
    NSIndexPath *hardenedIndexPath = [self hardenedIndexPathForIndex:index];
    DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
    return [derivationPath publicKeyAtIndexPathAsOpt:hardenedIndexPath];
}

- (BOOL)createNewKeyOfType:(DKeyKind)type
             securityLevel:(DSecurityLevel)security_level
                   purpose:(DPurpose)purpose
                   saveKey:(BOOL)saveKey
               returnIndex:(uint32_t *)rIndex {
    if (!self.isLocal) return NO;
    uint32_t keyIndex = DIdentityModelKeysCreated(self.model);
    DSLog(@"createNewKeyOfType: %u / %u / %u = %u", type, purpose, security_level, keyIndex);
    NSIndexPath *hardenedIndexPath = [self hardenedIndexPathForIndex:keyIndex];
    DSAuthenticationKeysDerivationPath *derivationPath = NULL;
    switch (type) {
        case dash_spv_crypto_keys_key_KeyKind_ECDSA:
            derivationPath = [[DSDerivationPathFactory sharedInstance] identityECDSAKeysDerivationPathForWallet:self.wallet];
            break;
        case dash_spv_crypto_keys_key_KeyKind_BLS:
        case dash_spv_crypto_keys_key_KeyKind_BLSBasic:
            derivationPath = [[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:self.wallet];
            break;
        default:
            return NO;
    }

    DOpaqueKey *public_key = [derivationPath publicKeyAtIndexPathAsOpt:hardenedIndexPath];
    if (!public_key) {
        DSLog(@"%@ Error creating public key of type %u with security level %u for purpose %u at %@", self.logPrefix, type, security_level, purpose, hardenedIndexPath);
        return NO;
    }
    NSAssert([derivationPath hasExtendedPrivateKey], @"The derivation path should have an extended private key");
    DOpaqueKey *privateKey = [derivationPath privateKeyAtIndexPathAsOpt:hardenedIndexPath];
    NSAssert(privateKey, @"The private key should have been derived");
    NSAssert([DSKeyManager keysPublicKeyDataIsEqual:public_key key2:privateKey], @"These should be equal");
    DOpaqueKeyDtor(privateKey);
    
    if (rIndex)
        *rIndex = keyIndex;
    
    DIdentityModelSetKeysCreated(self.model, DIdentityModelKeysCreated(self.model) + 1);
    DIdentityModelAddKeyInfo(self.model, keyIndex, DKeyInfoCtor(public_key, dash_spv_platform_identity_key_status_IdentityKeyStatus_Registering_ctor(), DSecurityLevelFromIndex(security_level), DPurposeFromIndex(purpose)));
    if (saveKey && !self.isTransient && self.isActive) {
        DKeyInfo *key_info = DKeyInfoAtIndex(self.model, keyIndex);
        [self saveNewKeyInfoForCurrentEntity:key_info
                                 atIndexPath:hardenedIndexPath
                          fromDerivationPath:derivationPath
                                   inContext:[NSManagedObjectContext viewContext]];
        DKeyInfoDtor(key_info);
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self,
            DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
        }];
    }
    return YES;
}

- (uint32_t)firstIndexOfKeyOfType:(DKeyKind *)type
               createIfNotPresent:(BOOL)createIfNotPresent
                          saveKey:(BOOL)saveKey {
    DKeyKind kind = DKeyKindIndex(type);
    uint32_t *first_index = dash_spv_platform_identity_model_IdentityModel_first_index_of_key_kind(self.model, type);
    if (first_index) {
        uint32_t index = first_index[0];
        u32_destroy(first_index);
        return index;
    }
    if (self.isLocal && createIfNotPresent) {
        uint32_t rIndex;
        [self createNewKeyOfType:kind
                   securityLevel:dpp_identity_identity_public_key_security_level_SecurityLevel_MASTER
                         purpose:dpp_identity_identity_public_key_purpose_Purpose_AUTHENTICATION
                         saveKey:saveKey
                     returnIndex:&rIndex];
        return rIndex;
    } else {
        return UINT32_MAX;
    }
}

- (DIdentityPublicKey *_Nullable)firstIdentityPublicKeyOfSecurityLevel:(DSecurityLevel *)security_level
                                                            andPurpose:(DPurpose *)purpose {
    return dash_spv_platform_identity_model_IdentityModel_first_identity_public_key(self.model, security_level, purpose);
}

- (void)addKeyInfo:(DOpaqueKey *)key
     securityLevel:(DSecurityLevel *)security_level
           purpose:(DPurpose *)purpose
            status:(DIdentityKeyStatus *)status
             index:(uint32_t)index {
    DIdentityModelAddKeyInfo(self.model, index, DKeyInfoCtor(key, status, security_level, purpose));
}

// MARK: - Funding

- (NSString *)registrationFundingAddress {
    if (self.registrationAssetLockTransaction) {
        return [DSKeyManager addressFromHash160:self.registrationAssetLockTransaction.creditBurnPublicKeyHash forChain:self.chain];
    } else {
        DSAssetLockDerivationPath *path = self.isOutgoingInvitation
            ? [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:self.wallet]
            : [[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:self.wallet];
        return [path addressAtIndexPath:[NSIndexPath indexPathWithIndex:self.index]];
    }
}


// MARK: Helpers

- (BOOL)isRegistered {
    return dash_spv_platform_identity_model_IdentityModel_is_registered(self.model);
}

- (BOOL)isUnknown {
    return DIdentityRegistrationStatusIndex(self.model) == dash_spv_platform_identity_registration_status_IdentityRegistrationStatus_Unknown;
}

- (NSString *)localizedRegistrationStatusString {
    char *status_string = dash_spv_platform_identity_registration_status_IdentityRegistrationStatus_string(self.registrationStatus);
    NSString *status = NSStringFromPtr(status_string);
    DCharDtor(status_string);
    return status;
}

- (void)applyIdentity:(DIdentity *)identity
            inContext:(NSManagedObjectContext *_Nullable)context {
    
    Result_ok_bool_err_dash_spv_platform_error_Error *result = dash_spv_platform_identity_model_IdentityModel_update_with_state_information(self.model, identity, ((__bridge void *)context), AS_RUST(self));
    if (result->error) {
        Result_ok_bool_err_dash_spv_platform_error_Error_destroy(result);
        return;
    }
    if (result->ok[0])
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self,
            DSIdentityUpdateEvents: @[DSIdentityUpdateEventKeyUpdate]
        }];
    Result_ok_bool_err_dash_spv_platform_error_Error_destroy(result);
}

// MARK: Registering

/// instant lock verification will work for recently signed instant locks.
/// we expect clients to use ChainAssetLockProof.
- (DAssetLockProof *)createProof:(DSInstantSendTransactionLock *_Nullable)isLock {
    return isLock ? [self createInstantProof:isLock.lock] : [self createChainProof];
}

- (DAssetLockProof *)createInstantProof:(DInstantLock *)isLock {
    uint16_t tx_version = self.registrationAssetLockTransaction.version;
    uint32_t lock_time = self.registrationAssetLockTransaction.lockTime;
    NSArray *inputs = self.registrationAssetLockTransaction.inputs;
    NSUInteger inputsCount = inputs.count;
    DTxIn **tx_inputs = malloc(sizeof(DTxIn *) * inputsCount);
    for (int i = 0; i < inputs.count; i++) {
        DSTransactionInput *o = inputs[i];
        DScriptBuf *script = o.signature ? DScriptBufCtor(bytes_ctor(o.signature)) : o.inScript ? DScriptBufCtor(bytes_ctor(o.inScript)) : NULL;
        DOutPoint *prev_output = DOutPointCtorU(o.inputHash, o.index);
        tx_inputs[i] = DTxInCtor(prev_output, script, o.sequence);
    }
    
    NSArray *outputs = self.registrationAssetLockTransaction.outputs;
    NSUInteger outputsCount = outputs.count;
    DTxOut **tx_outputs = malloc(sizeof(DTxOut *) * outputsCount);
    for (int i = 0; i < outputs.count; i++) {
        DSTransactionOutput *o = outputs[i];
        tx_outputs[i] = [o ffi_malloc];
    }
    uint8_t asset_lock_payload_version = self.registrationAssetLockTransaction.specialTransactionVersion;
    
    NSArray *creditOutputs = self.registrationAssetLockTransaction.creditOutputs;
    NSUInteger creditOutputsCount = creditOutputs.count;
    DTxOut **credit_outputs = malloc(sizeof(DTxOut *) * creditOutputsCount);
    for (int i = 0; i < creditOutputsCount; i++) {
        DSTransactionOutput *o = creditOutputs[i];
        credit_outputs[i] = [o ffi_malloc];
    }

    DTxInputs *input_vec = DTxInputsCtor(inputsCount, tx_inputs);
    DTxOutputs *output_vec = DTxOutputsCtor(outputsCount, tx_outputs);
    DTxOutputs *credit_output_vec = DTxOutputsCtor(creditOutputsCount, credit_outputs);
    uint32_t output_index = (uint32_t ) self.registrationAssetLockTransaction.lockedOutpoint.n;
    
    return dash_spv_platform_transition_instant_proof(output_index, isLock, tx_version, lock_time, input_vec, output_vec, asset_lock_payload_version, credit_output_vec);

}

- (DAssetLockProof *)createChainProof {
    DSUTXO lockedOutpoint = self.registrationAssetLockTransaction.lockedOutpoint;
    u256 *txid = u256_ctor_u(uint256_reverse(lockedOutpoint.hash));
    uint32_t vout = (uint32_t) lockedOutpoint.n;
    return dash_spv_platform_transition_chain_proof(self.registrationAssetLockTransaction.blockHeight, txid, vout);
}

- (BOOL)containsPublicKey:(DIdentityPublicKey *)identity_public_key {
    return dash_spv_platform_identity_model_IdentityModel_has_identity_public_key(self.model, identity_public_key);
}

- (BOOL)containsTopupTransaction:(DSAssetLockTransaction *)transaction {
    return [self.topupAssetLockTransactionHashes containsObject:uint256_data(transaction.txHash)];
}

//- (void)registerIdentityWithProof:(DAssetLockProof *)proof
//                       public_key:(DIdentityPublicKey *)public_key
//                          atIndex:(uint32_t)index
//                        completion:(void (^)(BOOL, NSError *_Nullable))completion {
//    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ Register Identity (public key (%u: %p) at %u", self.logPrefix, public_key->tag, public_key, index];
//    DSLog(@"%@", debugInfo);
//
//    
//    const Runtime *runtime = self.chain.sharedRuntimeObj;
//    PlatformSDK *platform = self.chain.sharedPlatformObj;
//    DOpaqueKey *private_key = self.registrationFundingPrivateKey;
//    
//    Result_ok_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error *result = dash_spv_platform_PlatformSDK_identity_register_using_public_key_at_index(runtime, platform, public_key, index, proof, private_key);
//    runtime_destroy(runtime);
//    if (result->error) {
//        NSError *error = [NSError ffi_from_platform_error:result->error];
//        DSLog(@"%@: ERROR: %@", debugInfo, error);
//        switch (result->error->tag) {
//            case dash_spv_platform_error_Error_InstantSendSignatureVerificationError:
//                DSLog(@"%@: Probably isd lock is outdated... try with chain lock proof", debugInfo);
//                Result_ok_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
//                DAssetLockProof *proof = [self createChainProof];
//                [self registerIdentityWithProof:proof public_key:public_key atIndex:index completion:completion];
//                break;
//                
//            default: {
//                Result_ok_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
//                if (completion) completion(nil, ERROR_REG_TRANSITION_CREATION);
//                break;
//            }
//        }
//        return;
//    }
//    [self applyIdentity:result->ok inContext:self.platformContext];
//    Result_ok_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
//    DSLog(@"%@: OK ", debugInfo);
//    completion(YES, NULL);
//}

- (void)topupIdentityWithProof:(DAssetLockProof *)proof
                    public_key:(DIdentityPublicKey *)public_key
                       atIndex:(uint32_t)index
                    completion:(void (^)(BOOL, NSError *_Nullable))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ TopUp Identity using public key (%u: %p) at %u", self.logPrefix, public_key->tag, public_key, index];
    DSLog(@"%@", debugInfo);
    u256 *identity_id = u256_ctor_u(self.uniqueID);
    dispatch_group_t dispatchGroup = dispatch_group_create();
    dispatch_group_enter(dispatchGroup);
    const Runtime *runtime = self.chain.sharedRuntimeObj;
    DMaybeStateTransitionProofResult *state_transition_result = dash_spv_platform_PlatformSDK_identity_topup(runtime, self.chain.sharedPlatformObj, identity_id, proof, self.topupFundingPrivateKey);
    runtime_destroy(runtime);
    dispatch_group_leave(dispatchGroup);
    if (state_transition_result->error) {
        NSError *error = [NSError ffi_from_platform_error:state_transition_result->error];
        DSLog(@"%@: ERROR: %@", debugInfo, error.debugDescription);
        switch (state_transition_result->error->tag) {
            case dash_spv_platform_error_Error_InstantSendSignatureVerificationError:
                DSLog(@"%@: Probably isd lock is outdated... try with chain lock proof", debugInfo);
                DMaybeStateTransitionProofResultDtor(state_transition_result);
                DAssetLockProof *proof = [self createChainProof];
                [self topupIdentityWithProof:proof public_key:public_key atIndex:index completion:completion];
                break;
                
            default: {
                DMaybeStateTransitionProofResultDtor(state_transition_result);
                if (completion) completion(nil, ERROR_REG_TRANSITION_CREATION);
                break;
            }
        }
        return;
    }
    DSLog(@"%@: OK", debugInfo);
    [self processStateTransitionResult:state_transition_result];
    DMaybeStateTransitionProofResultDtor(state_transition_result);
    completion(YES, NULL);
}

//    [self.identity topupTransactionForTopupAmount:topupAmount fundedByAccount:self.fundingAccount completion:^(DSIdentityTopupTransition *identityTopupTransaction) {
//        if (identityTopupTransaction) {
//            [self.fundingAccount signTransaction:identityTopupTransaction withPrompt:@"Fund Transaction" completion:^(BOOL signedTransaction, BOOL cancelled) {
//                if (signedTransaction) {
//                    [self.chainManager.transactionManager publishTransaction:identityTopupTransaction completion:^(NSError * _Nullable error) {
//                        if (error) {
//                            [self raiseIssue:@"Error" message:error.localizedDescription];
//
//                        } else {
//                            [self.navigationController popViewControllerAnimated:TRUE];
//                        }
//                    }];
//                } else {
//                    [self raiseIssue:@"Error" message:@"Transaction was not signed."];
//
//                }
//            }];
//        } else {
//            [self raiseIssue:@"Error" message:@"Unable to create BlockchainIdentityTopupTransaction."];
//
//        }
//    }];

- (void)createAndPublishTopUpTransitionForAmount:(uint64_t)amount
                                 fundedByAccount:(DSAccount *)fundingAccount
                                       pinPrompt:(NSString *)prompt
                                  withCompletion:(void (^)(BOOL, NSError *_Nullable))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ CREATE AND PUBLISH IDENTITY TOPUP TRANSITION", self.logPrefix];
    DSLog(@"%@", debugInfo);
    DSAssetLockDerivationPath *path = [[DSDerivationPathFactory sharedInstance] identityTopupFundingDerivationPathForWallet:self.wallet];
    NSString *topupAddress = [path addressAtIndexPath:[NSIndexPath indexPathWithIndex:self.index]];
    DSAssetLockTransaction *assetLockTransaction = [fundingAccount assetLockTransactionFor:amount to:topupAddress withFee:YES];
    if (!assetLockTransaction) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, ERROR_FUNDING_TX_CREATION); });
        return;
    }
    
    [fundingAccount signTransaction:assetLockTransaction
                         withPrompt:prompt
                         completion:^(BOOL signedTransaction, BOOL cancelled) {
        if (!signedTransaction) {
            if (completion)
                dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, cancelled ? nil : ERROR_FUNDING_TX_SIGNING); });
            return;
        }
        [self publishTransactionAndWait:assetLockTransaction completion:^(BOOL published, DSInstantSendTransactionLock *_Nullable instantSendLock, NSError *_Nullable error) {
            if (!published) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, ERROR_FUNDING_TX_TIMEOUT); });
                return;
            }
            if (!instantSendLock) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, ERROR_FUNDING_TX_ISD_TIMEOUT); });
                return;
            }
            
            if (!dash_spv_platform_identity_model_IdentityModel_has_topup_funding_private_key(self.model)) {
                DSLog(@"%@: ERROR: No TopUp Funding Private Key", debugInfo);
                if (completion) completion(nil, ERROR_NO_FUNDING_PRV_KEY);
                return;
            }
            uint32_t index = [self firstIndexOfKeyOfType:DKeyKindECDSA() createIfNotPresent:YES saveKey:!self.wallet.isTransient];
            [debugInfo appendFormat:@", index: %u", index];
            DOpaqueKey *publicKey = [self keyAtIndex:index];
            [debugInfo appendFormat:@", public_key: %p", publicKey];
            DSInstantSendTransactionLock *isLock = assetLockTransaction.instantSendLockAwaitingProcessing;
            [debugInfo appendFormat:@", is_lock: %p", isLock];
            if (!isLock && assetLockTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT) {
                DSLog(@"%@: ERROR: Funding Tx Not Mined", debugInfo);
                if (completion) completion(nil, ERROR_FUNDING_TX_NOT_MINED);
                return;
            }
            DIdentityPublicKey *public_key = DIdentityRegistrationPublicKey(index, publicKey);
            DAssetLockProof *proof = [self createProof:isLock];
            DSLog(@"%@ Proof: %u: %p", debugInfo, proof->tag, proof);
            [self topupIdentityWithProof:proof public_key:public_key atIndex:index completion:completion];
        }];

    }];
}

- (void)createAndPublishRegistrationTransitionWithCompletion:(void (^)(BOOL, NSError *))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ CREATE AND PUBLISH IDENTITY REGISTRATION TRANSITION", self.logPrefix];
    DSLog(@"%@", debugInfo);
    NSAssert(self.registrationAssetLockTransaction, @"The registration credit funding transaction must be known %@", uint256_hex(self.registrationAssetLockTransactionHash));
    uint32_t core_chain_locked_height = self.registrationAssetLockTransaction.blockHeight;
    DSInstantSendTransactionLock *isLock = self.registrationAssetLockTransaction.instantSendLockAwaitingProcessing;
    if (!isLock && core_chain_locked_height == BLOCK_UNKNOWN_HEIGHT) {
        DSLog(@"%@: ERROR: Funding Tx Not Mined", debugInfo);
        if (completion) completion(nil, ERROR_FUNDING_TX_NOT_MINED);
        return;
    }
    
    dispatch_async(self.identityQueue, ^{
        std_collections_Map_keys_u32_values_dash_spv_platform_identity_key_info_KeyInfo *dict = dash_spv_platform_identity_model_IdentityModel_key_info_dictionaries(self.model);
        DSLog(@"KEY INFO DICTIONARY");
        for (int i = 0; i < dict->count; i++) {
            DKeyInfo *key_info = dict->values[i];
            DKeyKind *kind = dash_spv_crypto_keys_key_OpaqueKey_kind(key_info->key);
            DSLog(@"\t %u: %u: %u: %u: %u", dict->keys[i], DKeyKindIndex(kind), DIdentityKeyStatusToIndex(key_info->key_status), DPurposeIndex(key_info->purpose), DSecurityLevelIndex(key_info->security_level));
        }
        
        std_collections_Map_keys_u32_values_dash_spv_platform_identity_key_info_KeyInfo_destroy(dict);
        const Runtime *runtime = self.chain.sharedRuntimeObj;
        PlatformSDK *platform = self.chain.sharedPlatformObj;
        DTransaction *transaction = [self.registrationAssetLockTransaction ffi_malloc:self.chain.chainType];
        void *storage_context = ((__bridge void *)(self.platformContext));
        IdentityModel *model = self.model;
        DInstantLock *lock = isLock.lock;
        void *self_ = AS_RUST(self);
        DSLog(@"IDENTITY REGISTRATION TRANSITION: %p / %p / %p / %p / %p / %p / %p", runtime, platform, model, transaction, lock, storage_context, self_);
        Result_ok_bool_err_dash_spv_platform_error_Error *result = dash_spv_platform_PlatformSDK_create_and_publish_registration_transition(runtime, platform, model, transaction, core_chain_locked_height, lock, !self.wallet.isTransient, storage_context, self_);
        runtime_destroy(runtime);
        
        if (result->error) {
            NSError *error = [NSError ffi_from_platform_error:result->error];
            DSLog(@"%@: ERROR: %@", debugInfo, error.debugDescription);
            Result_ok_bool_err_dash_spv_platform_error_Error_destroy(result);
            if (completion) completion(NO, error);
            return;
        }
        BOOL success = result->ok[0];
        Result_ok_bool_err_dash_spv_platform_error_Error_destroy(result);
        if (completion) completion(success, nil);
    });

    
//    if (!dash_spv_platform_identity_model_IdentityModel_has_registration_funding_private_key(self.model)) {
//        DSLog(@"%@: ERROR: No Funding Private Key", debugInfo);
//        if (completion) completion(nil, ERROR_NO_FUNDING_PRV_KEY);
//        return;
//    }
//
//    uint32_t index = [self firstIndexOfKeyOfType:DKeyKindECDSA() createIfNotPresent:YES saveKey:!self.wallet.isTransient];
//    NSAssert((index & ~(BIP32_HARD)) == 0, @"The index should be 0 here");
//    DOpaqueKey *publicKey = [self keyAtIndex:index];
//    DIdentityPublicKey *public_key = DIdentityRegistrationPublicKey(index, publicKey);
//    DAssetLockProof *proof = [self createProof:isLock];
//    DSLog(@"%@ Proof: %u: %p", debugInfo, proof->tag, proof);
//    [self registerIdentityWithProof:proof public_key:public_key atIndex:index completion:completion];
}

- (void)createFundingPrivateKeyWithPromptAndPublishRegistrationTransition:(NSString *)prompt
                                                           withCompletion:(void (^_Nullable)(BOOL success, NSError *_Nullable error))completion {
    [self createFundingPrivateKeyWithPrompt:prompt
                                 completion:^(BOOL success, BOOL cancelled) {
        [self createAndPublishRegistrationTransitionWithCompletion:completion];
    }];

}


// MARK: Retrieval

- (void)fetchIdentityNetworkStateInformationWithCompletion:(void (^)(BOOL success, BOOL found, NSError *error))completion {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Fetch Identity State", self.logPrefix];
    DSLog(@"%@", debugString);
    dispatch_async(self.identityQueue, ^{
        const Runtime *runtime = self.chain.sharedRuntimeObj;
        IdentitiesManager *manager = self.chain.sharedIdentitiesObj;
        void *storage_context = ((__bridge void *)(self.platformContext));
        void *identity_context = AS_RUST(self);
        IdentityModel *model = self.model;
        DSLog(@"%@: fetch_identity_network_state_information: %p / %p / %p / %p / %p", debugString, runtime, manager, model, storage_context, identity_context);
//        fetch_identity_network_state_information(runtime, manager, model, storage_context, identity_context);
        Result_Tuple_bool_bool_err_dash_spv_platform_error_Error *result = dash_spv_platform_identity_manager_IdentitiesManager_fetch_identity_network_state_information(runtime, manager, model, storage_context, identity_context);
        runtime_destroy(runtime);
        if (result->error) {
            NSError *error = [NSError ffi_from_platform_error:result->error];
            DSLog(@"%@: ERROR: %@", debugString, error.debugDescription);
            Result_Tuple_bool_bool_err_dash_spv_platform_error_Error_destroy(result);
            completion(NO, NO, error);
            return;
        }
        BOOL success = result->ok->o_0;
        BOOL found = result->ok->o_1;
        Result_Tuple_bool_bool_err_dash_spv_platform_error_Error_destroy(result);
        completion(success, found, nil);
//        completion(NO, NO, nil);
    });
}


- (void)fetchAllNetworkStateInformationWithCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion {
    dispatch_async(self.identityQueue, ^{
        [self fetchAllNetworkStateInformationInContext:self.platformContext
                                        withCompletion:completion
                                     onCompletionQueue:dispatch_get_main_queue()];
    });
}

- (void)fetchAllNetworkStateInformationInContext:(NSManagedObjectContext *)context
                                  withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                               onCompletionQueue:(dispatch_queue_t)completionQueue {
    dispatch_async(self.identityQueue, ^{
        DSIdentityQueryStep query = DSIdentityQueryStep_None;
        if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Identities)
            query |= DSIdentityQueryStep_Identity;
        if ([DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
            query |= DSIdentityQueryStep_Username;
        if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay) {
            query |= DSIdentityQueryStep_Profile;
            if (self.isLocal)
                query |= DSIdentityQueryStep_ContactRequests;
        }
        [self fetchNetworkStateInformation:query
                                 inContext:context
                            withCompletion:completion
                         onCompletionQueue:completionQueue];
    });
}

- (void)fetchL3NetworkStateInformation:(DSIdentityQueryStep)queryStep
                        withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion {
    [self fetchL3NetworkStateInformation:queryStep
                               inContext:self.platformContext
                          withCompletion:completion
                       onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchL3NetworkStateInformation:(DSIdentityQueryStep)queryStep
                             inContext:(NSManagedObjectContext *)context
                        withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                     onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Fetch L3 State (%@)", self.logPrefix, DSIdentityQueryStepsDescription(queryStep)];
    DSLog(@"%@", debugString);
    if (!(queryStep & DSIdentityQueryStep_Identity) && !self.activeKeyCount) {
        // We need to fetch keys if we want to query other information
        if (completion) completion(DSIdentityQueryStep_BadQuery, @[ERROR_ATTEMPT_QUERY_WITHOUT_KEYS]);
        return;
    }
    __block DSIdentityQueryStep failureStep = DSIdentityQueryStep_None;
    __block NSMutableArray *groupedErrors = [NSMutableArray array];
    dispatch_group_t dispatchGroup = dispatch_group_create();
    if (queryStep & DSIdentityQueryStep_Username) {
        dispatch_group_enter(dispatchGroup);
        [self fetchUsernamesInContext:context
                       withCompletion:^(BOOL success, NSError *error) {
            failureStep |= success & DSIdentityQueryStep_Username;
            if (error) [groupedErrors addObject:error];
            dispatch_group_leave(dispatchGroup);
        }
                    onCompletionQueue:self.identityQueue];
    }
    
    if (queryStep & DSIdentityQueryStep_Profile) {
        dispatch_group_enter(dispatchGroup);
        [self fetchProfileInContext:context withCompletion:^(BOOL success, NSError *error) {
            failureStep |= success & DSIdentityQueryStep_Profile;
            if (error) [groupedErrors addObject:error];
            dispatch_group_leave(dispatchGroup);
        }
                  onCompletionQueue:self.identityQueue];
    }
    
    if (queryStep & DSIdentityQueryStep_OutgoingContactRequests) {
        dispatch_group_enter(dispatchGroup);
        [self fetchOutgoingContactRequestsInContext:context
                                         startAfter:nil
                                     withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
            failureStep |= success & DSIdentityQueryStep_OutgoingContactRequests;
            if ([errors count]) {
                [groupedErrors addObjectsFromArray:errors];
                dispatch_group_leave(dispatchGroup);
            } else {
                if (queryStep & DSIdentityQueryStep_IncomingContactRequests) {
                    [self fetchIncomingContactRequestsInContext:context
                                                     startAfter:nil
                                                 withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
                        failureStep |= success & DSIdentityQueryStep_IncomingContactRequests;
                        if ([errors count]) [groupedErrors addObjectsFromArray:errors];
                        dispatch_group_leave(dispatchGroup);
                    }
                                              onCompletionQueue:self.identityQueue];
                } else {
                    dispatch_group_leave(dispatchGroup);
                }
            }
        }
                                  onCompletionQueue:self.identityQueue];
    } else if (queryStep & DSIdentityQueryStep_IncomingContactRequests) {
        dispatch_group_enter(dispatchGroup);
        [self fetchIncomingContactRequestsInContext:context
                                         startAfter:nil
                                     withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
            failureStep |= success & DSIdentityQueryStep_IncomingContactRequests;
            if ([errors count]) [groupedErrors addObjectsFromArray:errors];
            dispatch_group_leave(dispatchGroup);
        }
                                  onCompletionQueue:self.identityQueue];
    }
    
    __weak typeof(self) weakSelf = self;
    if (completion) {
        dispatch_group_notify(dispatchGroup, self.identityQueue, ^{
#if DEBUG
            DSLog(@"%@: Finished for user %@ (query %@ - failures %@)", debugString,
                         self.currentDashpayUsername ? self.currentDashpayUsername : self.uniqueIdString, DSIdentityQueryStepsDescription(queryStep), DSIdentityQueryStepsDescription(failureStep));
#else
            DSLog(@"%@: Finished for user %@ (query %@ - failures %@)",
                  @"<REDACTED>", debugString, DSIdentityQueryStepsDescription(queryStep), DSIdentityQueryStepsDescription(failureStep));
#endif /* DEBUG */
            if (!(failureStep & DSIdentityQueryStep_ContactRequests)) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                //todo This needs to be eventually set with the blockchain returned by platform.
                strongSelf.dashpaySyncronizationBlockHash = strongSelf.chain.lastTerminalBlock.blockHash;
            }
            dispatch_async(completionQueue, ^{ completion(failureStep, [groupedErrors copy]); });
        });
    }
}

- (void)fetchNetworkStateInformation:(DSIdentityQueryStep)querySteps
                      withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion {
    [self fetchNetworkStateInformation:querySteps
                             inContext:self.platformContext
                        withCompletion:completion
                     onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchNetworkStateInformation:(DSIdentityQueryStep)querySteps
                           inContext:(NSManagedObjectContext *)context
                      withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                   onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ fetchNetworkStateInformation (%@)", self.logPrefix, DSIdentityQueryStepsDescription(querySteps)];
    DSLog(@"%@", debugString);
    if (querySteps & DSIdentityQueryStep_Identity) {
        [self fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, BOOL found, NSError *error) {
            if (!success) {
                DSLog(@"%@: ERROR: %@", debugString, error.debugDescription);
                if (completion) dispatch_async(completionQueue, ^{ completion(DSIdentityQueryStep_Identity, error ? @[error] : @[]); });
                return;
            }
            if (!found) {
                DSLog(@"%@: ERROR: NoIdentity", debugString);
                if (completion) dispatch_async(completionQueue, ^{ completion(DSIdentityQueryStep_NoIdentity, @[]); });
                return;
            }
            [self fetchL3NetworkStateInformation:querySteps
                                       inContext:context
                                  withCompletion:completion
                               onCompletionQueue:completionQueue];
        }];
    } else {
        NSAssert([self identityEntityInContext:context], @"Blockchain identity entity should be known");
        [self fetchL3NetworkStateInformation:querySteps
                                   inContext:context
                              withCompletion:completion
                           onCompletionQueue:completionQueue];
    }
}

- (void)fetchIfNeededNetworkStateInformation:(DSIdentityQueryStep)querySteps
                                   inContext:(NSManagedObjectContext *)context
                              withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                           onCompletionQueue:(dispatch_queue_t)completionQueue {
    dispatch_async(self.identityQueue, ^{
        if (!self.activeKeyCount) {
            if (self.isLocal) {
                [self fetchNetworkStateInformation:querySteps
                                         inContext:context
                                    withCompletion:completion
                                 onCompletionQueue:completionQueue];
            } else {
                DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
                if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Identities)
                    stepsNeeded |= DSIdentityQueryStep_Identity;
                if (!self.dashpayUsernameCount && DIdentityModelLastCheckedUsernamesTimestamp(self.model) == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
                    stepsNeeded |= DSIdentityQueryStep_Username;
                if ((DIdentityModelLastCheckedProfileTimestamp(self.model) < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                    stepsNeeded |= DSIdentityQueryStep_Profile;
                if (stepsNeeded != DSIdentityQueryStep_None) {
                    [self fetchNetworkStateInformation:stepsNeeded & querySteps inContext:context withCompletion:completion onCompletionQueue:completionQueue];
                } else if (completion) {
                    completion(DSIdentityQueryStep_None, @[]);
                }
            }
        } else {
            DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
            if (!self.dashpayUsernameCount && DIdentityModelLastCheckedUsernamesTimestamp(self.model) == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS) {
                stepsNeeded |= DSIdentityQueryStep_Username;
            }
            __block uint64_t createdAt;
            [context performBlockAndWait:^{
                createdAt = [[self matchingDashpayUserInContext:context] createdAt];
            }];
            if (!createdAt && (DIdentityModelLastCheckedProfileTimestamp(self.model) < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_Profile;
            if (self.isLocal && (DIdentityModelLastCheckedIncomingContactsTimestamp(self.model) < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_IncomingContactRequests;
            if (self.isLocal && (DIdentityModelLastCheckedOutgoingContactsTimestamp(self.model) < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_OutgoingContactRequests;
            if (stepsNeeded != DSIdentityQueryStep_None) {
                [self fetchNetworkStateInformation:stepsNeeded & querySteps inContext:context withCompletion:completion onCompletionQueue:completionQueue];
            } else if (completion) {
                completion(DSIdentityQueryStep_None, @[]);
            }
        }
    });
}

- (void)fetchNeededNetworkStateInformationInContext:(NSManagedObjectContext *)context
                                     withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                                  onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Fetch Needed Network State Info (local: %u, active keys: %lu) ", self.logPrefix, self.isLocal, self.activeKeyCount];
    DSLog(@"%@", debugString);
    dispatch_async(self.identityQueue, ^{
        if (!self.activeKeyCount) {
            if (self.isLocal) {
                [self fetchAllNetworkStateInformationWithCompletion:completion];
            } else {
                DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
                if ([DSOptionsManager sharedInstance].syncType & DSSyncType_Identities)
                    stepsNeeded |= DSIdentityQueryStep_Identity;
                if (!self.dashpayUsernameCount && DIdentityModelLastCheckedUsernamesTimestamp(self.model) == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
                    stepsNeeded |= DSIdentityQueryStep_Username;
                if ((DIdentityModelLastCheckedProfileTimestamp(self.model) < [NSDate timeIntervalSince1970Minus:HOUR_TIME_INTERVAL]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                    stepsNeeded |= DSIdentityQueryStep_Profile;
                if (stepsNeeded != DSIdentityQueryStep_None) {
                    [self fetchNetworkStateInformation:stepsNeeded
                                             inContext:context
                                        withCompletion:completion
                                     onCompletionQueue:completionQueue];
                } else if (completion) {
                    completion(DSIdentityQueryStep_None, @[]);
                }
            }
        } else {
            DSIdentityQueryStep stepsNeeded = DSIdentityQueryStep_None;
            if (!self.dashpayUsernameCount && DIdentityModelLastCheckedUsernamesTimestamp(self.model) == 0 && [DSOptionsManager sharedInstance].syncType & DSSyncType_DPNS)
                stepsNeeded |= DSIdentityQueryStep_Username;
            if (![[self matchingDashpayUserInContext:context] createdAt] && (DIdentityModelLastCheckedProfileTimestamp(self.model) < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_Profile;
            if (self.isLocal && (DIdentityModelLastCheckedIncomingContactsTimestamp(self.model) < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_IncomingContactRequests;
            if (self.isLocal && (DIdentityModelLastCheckedOutgoingContactsTimestamp(self.model) < [NSDate timeIntervalSince1970MinusHour]) && [DSOptionsManager sharedInstance].syncType & DSSyncType_Dashpay)
                stepsNeeded |= DSIdentityQueryStep_OutgoingContactRequests;
            if (stepsNeeded != DSIdentityQueryStep_None) {
                [self fetchNetworkStateInformation:stepsNeeded
                                         inContext:context
                                    withCompletion:completion
                                 onCompletionQueue:completionQueue];
            } else if (completion) {
                completion(DSIdentityQueryStep_None, @[]);
            }
        }
    });
}

- (BOOL)processStateTransitionResult:(DMaybeStateTransitionProofResult *)result {
#if (defined(DPP_STATE_TRANSITIONS))
    dpp_state_transition_proof_result_StateTransitionProofResult *proof_result = result->ok;
    switch (proof_result->tag) {
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedDataContract: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_data_contract->v0->id->_0->_0);
            DSLog(@"%@ VerifiedDataContract: %@", self.logPrefix, identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedIdentity: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_identity->v0->id->_0->_0);
            DSLog(@"%@ VerifiedIdentity: %@", self.logPrefix, identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedPartialIdentity: {
            NSData *identifier = NSDataFromPtr(proof_result->verified_partial_identity->id->_0->_0);
            DSLog(@"%@ VerifiedPartialIdentity: %@", self.logPrefix, identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedBalanceTransfer: {
            dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedBalanceTransfer_Body transfer = proof_result->verified_balance_transfer;
            NSData *from_identifier = NSDataFromPtr(transfer._0->id->_0->_0);
            NSData *to_identifier = NSDataFromPtr(transfer._1->id->_0->_0);
            DSLog(@"%@ VerifiedBalanceTransfer: %@ --> %@", self.logPrefix, from_identifier.hexString, to_identifier.hexString);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedDocuments: {
            std_collections_Map_keys_platform_value_types_identifier_Identifier_values_Option_dpp_document_Document *verified_documents = proof_result->verified_documents;
            DSLog(@"%@ VerifiedDocuments: %lu", self.logPrefix, verified_documents->count);
            break;
        }
        case dpp_state_transition_proof_result_StateTransitionProofResult_VerifiedMasternodeVote: {
            dpp_voting_votes_Vote *verified_masternode_vote = proof_result->verified_masternode_vote;
            DSLog(@"%@ VerifiedMasternodeVote: %u", self.logPrefix, verified_masternode_vote->tag);
            break;
        }
        default:
            break;
    }
#endif
    return YES;
}

// MARK: - Contracts

- (void)fetchAndUpdateContract:(DPContract *)contract {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Fetch & Update Contract (%lu) ", self.logPrefix, (unsigned long) contract.contractState];
    DSLog(@"%@", debugString);
    NSManagedObjectContext *context = [NSManagedObjectContext platformContext];
    __weak typeof(contract) weakContract = contract;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get service immediately
        BOOL isDPNSEmpty = [contract.name isEqual:@"DPNS"] && uint256_is_zero(self.chain.dpnsContractID);
        BOOL isDashpayEmpty = [contract.name isEqual:@"DashPay"] && uint256_is_zero(self.chain.dashpayContractID);
        BOOL isOtherContract = !([contract.name isEqual:@"DashPay"] || [contract.name isEqual:@"DPNS"]);
        if (((isDPNSEmpty || isDashpayEmpty || isOtherContract) && uint256_is_zero(contract.registeredIdentityUniqueID)) || contract.contractState == DPContractState_NotRegistered) {
            [contract registerCreator:self];
            [contract saveAndWaitInContext:context];
            
            if (!DIdentityModelKeysCreated(self.model)) {
                uint32_t index;
                [self createNewKeyOfType:dash_spv_crypto_keys_key_KeyKind_ECDSA
                           securityLevel:dpp_identity_identity_public_key_security_level_SecurityLevel_MASTER
                                 purpose:dpp_identity_identity_public_key_purpose_Purpose_AUTHENTICATION
                                 saveKey:!self.wallet.isTransient
                             returnIndex:&index];
            }
            DOpaqueKey *privateKey = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
            const Runtime *runtime = self.chain.sharedRuntimeObj;

            DMaybeStateTransitionProofResult *state_transition_result = dash_spv_platform_PlatformSDK_data_contract_create2(runtime, self.chain.sharedPlatformObj, data_contracts_SystemDataContract_DPNS_ctor(), u256_ctor_u(self.uniqueID), 0, privateKey);
            runtime_destroy(runtime);
            if (state_transition_result->error) {
                DSLog(@"%@ ERROR: %@", debugString, [NSError ffi_from_platform_error:state_transition_result->error]);
                DMaybeStateTransitionProofResultDtor(state_transition_result);
                return;
            }
            DSLog(@"%@ OK", debugString);
            if ([self processStateTransitionResult:state_transition_result]) {
                contract.contractState = DPContractState_Registering;
            } else {
                contract.contractState = DPContractState_Unknown;
            }
            [contract saveAndWaitInContext:context];
            const Runtime *contract_runtime = self.chain.sharedRuntimeObj;

            DMaybeContract *monitor_result = dash_spv_platform_contract_manager_ContractsManager_monitor_for_id_bytes(contract_runtime, self.chain.sharedContractsObj, u256_ctor_u(contract.contractId), DRetryLinear(2), dash_spv_platform_contract_manager_ContractValidator_None_ctor());
            runtime_destroy(contract_runtime);

            if (monitor_result->error) {
                DMaybeContractDtor(monitor_result);
                DSLog(@"%@ Contract Monitoring Error: %@", self.logPrefix, [NSError ffi_from_platform_error:monitor_result->error]);
                return;
            }
            if (monitor_result->ok) {
                NSData *identifier = NSDataFromPtr(monitor_result->ok->v0->id->_0->_0);
                if ([identifier isEqualToData:uint256_data(contract.contractId)]) {
                    DSLog(@"%@ Contract Monitoring OK", self.logPrefix);
                    contract.contractState = DPContractState_Registered;
                    [contract saveAndWaitInContext:context];
                } else {
                    DSLog(@"%@ Contract Monitoring Error: Ids dont match", self.logPrefix);
                }
            }
            DSLog(@"%@ Contract Monitoring Error", self.logPrefix);

        } else if (contract.contractState == DPContractState_Registered || contract.contractState == DPContractState_Registering) {
            DSLog(@"%@ Fetching contract for verification %@", self.logPrefix, contract.base58ContractId);
            const Runtime *runtime = self.chain.sharedRuntimeObj;
            DMaybeContract *contract_result = dash_spv_platform_contract_manager_ContractsManager_fetch_contract_by_id_bytes(runtime, self.chain.sharedContractsObj, u256_ctor_u(contract.contractId));
            runtime_destroy(runtime);
            
            dispatch_async(self.identityQueue, ^{
                __strong typeof(weakContract) strongContract = weakContract;
                if (!weakContract || !contract_result) return;
                if (!contract_result->ok) {
                    DSLog(@"%@ Contract Monitoring ERROR: NotRegistered ", self.logPrefix);
                    strongContract.contractState = DPContractState_NotRegistered;
                    [strongContract saveAndWaitInContext:context];
                    DMaybeContractDtor(contract_result);
                    return;
                }
                DSLog(@"%@ Contract Monitoring OK: %@ ", self.logPrefix, strongContract);
                if (strongContract.contractState == DPContractState_Registered && !dash_spv_platform_contract_manager_has_equal_document_type_keys(contract_result->ok, strongContract.raw_contract)) {
                    strongContract.contractState = DPContractState_NotRegistered;
                    [strongContract saveAndWaitInContext:context];
                    //DSLog(@"Contract dictionary is %@", contractDictionary);
                }
                DMaybeContractDtor(contract_result);

            });
        }
    });
}

// MARK: - Monitoring

- (void)updateCreditBalance {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ //this is so we don't get DAPINetworkService immediately
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        const Runtime *runtime = strongSelf.chain.sharedRuntimeObj;
        DMaybeIdentityBalance *result = dash_spv_platform_identity_manager_IdentitiesManager_fetch_balance_by_id_bytes(runtime, strongSelf.chain.sharedIdentitiesObj, u256_ctor(self.uniqueIDData));
        runtime_destroy(runtime);
        if (!result->ok) {
            DSLog(@"%@ Update Credit Balance: ERROR RESULT: %u", self.logPrefix, result->error->tag);
            DMaybeIdentityBalanceDtor(result);
            return;
        }
        uint64_t balance = result->ok[0];
        DMaybeIdentityBalanceDtor(result);
        DSLog(@"%@ Update Credit Balance: OK: %llu", self.logPrefix, balance);
        dispatch_async(self.identityQueue, ^{
            DIdentityModelSetBalance(strongSelf.model, balance);
        });
    });
}


// MARK: Helpers

- (BOOL)isDashpayReady {
    return self.activeKeyCount > 0 && self.isRegistered;
}

- (UInt256)contractIdIfRegistered:(DDataContract *)contract {
    NSMutableData *mData = [NSMutableData data];
    [mData appendUInt256:self.uniqueID];
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identitiesECDSAKeysDerivationPathForWallet:self.wallet];
    Result_ok_Vec_u8_err_dash_spv_platform_error_Error *result = dash_spv_platform_contract_manager_ContractsManager_contract_serialized_hash(self.chain.sharedContractsObj, contract);
    NSData *serializedHash = NSDataFromPtr(result->ok);
    Result_ok_Vec_u8_err_dash_spv_platform_error_Error_destroy(result);
    NSMutableData *entropyData = [serializedHash mutableCopy];
    [entropyData appendUInt256:self.uniqueID];
    [entropyData appendData:[derivationPath publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndex:UINT32_MAX - 1]]]; //use the last key in 32 bit space (it won't probably ever be used anyways)
    [mData appendData:uint256_data([entropyData SHA256])];
    return [mData SHA256_2]; //this is the contract ID
}

- (DIdentityRegistrationStatus *)registrationStatus {
    return dash_spv_platform_identity_model_IdentityModel_registration_status(self.model);
}

- (BOOL)registrationStatusIsPending {
    DIdentityRegistrationStatus *status = self.registrationStatus;
    BOOL is_pending = dash_spv_platform_identity_registration_status_IdentityRegistrationStatus_is_unknown(status) || dash_spv_platform_identity_registration_status_IdentityRegistrationStatus_is_not_registered(status);
    DIdentityRegistrationStatusDtor(status);
    return is_pending;
}
- (BOOL)registrationStatusIsClaimed {
    DIdentityRegistrationStatus *status = self.registrationStatus;
    BOOL is_claimed = dash_spv_platform_identity_registration_status_IdentityRegistrationStatus_is_registering(status) || dash_spv_platform_identity_registration_status_IdentityRegistrationStatus_is_registered(status);
//    is_claimed = dash_spv_platform_identity_registration_status_IdentityRegistrationStatus_is_unknown(status) || dash_spv_platform_identity_registration_status_IdentityRegistrationStatus_is_not_registered(status);
    DIdentityRegistrationStatusDtor(status);
    return is_claimed;
}


// MARK: - Persistence

// MARK: Saving

- (void)saveInitial {
    [self saveInitialInContext:self.platformContext];
}

- (DSBlockchainIdentityEntity *)initialEntityInContext:(NSManagedObjectContext *)context {
    DSChainEntity *chainEntity = [self.chain chainEntityInContext:context];
    DSBlockchainIdentityEntity *entity = [DSBlockchainIdentityEntity managedObjectInBlockedContext:context];
    entity.uniqueID = uint256_data(self.uniqueID);
    entity.isLocal = self.isLocal;
    entity.registrationStatus = DIdentityRegistrationStatusIndex(self.model);
    if (self.isLocal)
        entity.registrationFundingTransaction = [DSAssetLockTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", uint256_data(self.registrationAssetLockTransaction.txHash)];
    entity.chain = chainEntity;
    [self collectUsernameEntitiesIntoIdentityEntityInContext:entity context:context];
    DKeyInfoDictionaries *key_info_dictionaries = DGetKeyInfoDictionaries(self.model);
    
    for (uint32_t index = 0; index < key_info_dictionaries->count; index++) {
        uint32_t key_info_index = key_info_dictionaries->keys[index];
        DKeyInfo *key_info = key_info_dictionaries->values[index];
        DKeyKind *type = dash_spv_platform_identity_key_info_KeyInfo_kind(key_info);
        DSAuthenticationKeysDerivationPath *derivationPath = [self derivationPathForType:type];
        DKeyKindDtor(type);
        NSIndexPath *indexPath = [self indexPathForIndex:key_info_index];
        [self createNewKeyFromKeyInfo:key_info
                    forIdentityEntity:entity
                          atIndexPath:indexPath
                   fromDerivationPath:derivationPath
                            inContext:context];
    }
    DKeyInfoDictionariesDtor(key_info_dictionaries);
    DSDashpayUserEntity *dashpayUserEntity = [DSDashpayUserEntity managedObjectInBlockedContext:context];
    dashpayUserEntity.chain = chainEntity;
    entity.matchingDashpayUser = dashpayUserEntity;
    if (self.isOutgoingInvitation) {
        DSBlockchainInvitationEntity *invitationEntity = [DSBlockchainInvitationEntity managedObjectInBlockedContext:context];
        invitationEntity.chain = chainEntity;
        entity.associatedInvitation = invitationEntity;
    }
    return entity;
}

- (void)saveInitialInContext:(NSManagedObjectContext *)context {
    if (self.isTransient) return;
    //no need for active check, in fact it will cause an infinite loop
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *entity = [self initialEntityInContext:context];
        DSDashpayUserEntity *dashpayUserEntity = entity.matchingDashpayUser;
        [context ds_saveInBlockAndWait];
        [[NSManagedObjectContext viewContext] performBlockAndWait:^{
            self.matchingDashpayUserInViewContext = [[NSManagedObjectContext viewContext] objectWithID:dashpayUserEntity.objectID];
        }];
        [[NSManagedObjectContext platformContext] performBlockAndWait:^{
            self.matchingDashpayUserInPlatformContext = [[NSManagedObjectContext platformContext] objectWithID:dashpayUserEntity.objectID];
        }];
        if ([self isLocal])
            [self notifyUpdate:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSIdentityKey: self
            }];
    }];
}

- (void)saveInContext:(NSManagedObjectContext *)context {
    if (self.isTransient) return;
    if (!self.isActive) return;
    [context performBlockAndWait:^{
        BOOL changeOccured = NO;
        NSMutableArray *updateEvents = [NSMutableArray array];
        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
        if (entity.creditBalance != self.creditBalance) {
            entity.creditBalance = self.creditBalance;
            changeOccured = YES;
            [updateEvents addObject:DSIdentityUpdateEventCreditBalance];
        }
        
        uint16_t registrationStatus = DIdentityRegistrationStatusIndex(self.model);
        if (entity.registrationStatus != registrationStatus) {
            entity.registrationStatus = registrationStatus;
            changeOccured = YES;
            [updateEvents addObject:DSIdentityUpdateEventRegistration];
        }
        
        if (!uint256_eq(entity.dashpaySyncronizationBlockHash.UInt256, self.dashpaySyncronizationBlockHash)) {
            entity.dashpaySyncronizationBlockHash = uint256_data(self.dashpaySyncronizationBlockHash);
            changeOccured = YES;
            [updateEvents addObject:DSIdentityUpdateEventDashpaySyncronizationBlockHash];
        }
        uint64_t lastCheckedUsernamesTimestamp = DIdentityModelLastCheckedUsernamesTimestamp(self.model);
        if (entity.lastCheckedUsernamesTimestamp != lastCheckedUsernamesTimestamp) {
            entity.lastCheckedUsernamesTimestamp = lastCheckedUsernamesTimestamp;
            changeOccured = YES;
        }
        uint64_t lastCheckedProfileTimestamp = DIdentityModelLastCheckedProfileTimestamp(self.model);
        if (entity.lastCheckedProfileTimestamp != lastCheckedProfileTimestamp) {
            entity.lastCheckedProfileTimestamp = lastCheckedProfileTimestamp;
            changeOccured = YES;
        }
        uint64_t lastCheckedIncomingContactsTimestamp = DIdentityModelLastCheckedIncomingContactsTimestamp(self.model);
        if (entity.lastCheckedIncomingContactsTimestamp != lastCheckedIncomingContactsTimestamp) {
            entity.lastCheckedIncomingContactsTimestamp = lastCheckedIncomingContactsTimestamp;
            changeOccured = YES;
        }
        uint64_t lastCheckedOutgoingContactsTimestamp = DIdentityModelLastCheckedOutgoingContactsTimestamp(self.model);
        if (entity.lastCheckedOutgoingContactsTimestamp != lastCheckedOutgoingContactsTimestamp) {
            entity.lastCheckedOutgoingContactsTimestamp = lastCheckedOutgoingContactsTimestamp;
            changeOccured = YES;
        }
        
        if (changeOccured) {
            [context ds_save];
            if (updateEvents.count)
                [self notifyUpdate:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSIdentityKey: self,
                    DSIdentityUpdateEvents: updateEvents
                }];
        }
    }];
}

- (NSString *)identifierForKeyAtPath:(NSIndexPath *)path
                  fromDerivationPath:(DSDerivationPath *)derivationPath {
    return [NSString stringWithFormat:@"%@-%@-%@", self.uniqueIdString, derivationPath.standaloneExtendedPublicKeyUniqueID, [[path softenAllItems] indexPathString]];
}

- (BOOL)saveNewKeyInfoForCurrentEntity:(DKeyInfo *)key_info
                           atIndexPath:(NSIndexPath *)indexPath
                    fromDerivationPath:(DSDerivationPath *)derivationPath
                             inContext:(NSManagedObjectContext *)context {
    __block BOOL save = NO;
    [context performBlockAndWait:^{
        save = [self createNewKeyFromKeyInfo:key_info
                           forIdentityEntity:[self identityEntityInContext:context]
                                 atIndexPath:indexPath
                          fromDerivationPath:derivationPath
                                   inContext:context];
        if (save)
            [context ds_save];
    }];
    return save;
}

- (BOOL)createNewKeyFromKeyInfo:(DKeyInfo *)key_info
              forIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity
                    atIndexPath:(NSIndexPath *)indexPath
             fromDerivationPath:(DSDerivationPath *)derivationPath
                      inContext:(NSManagedObjectContext *)context {
    NSAssert(identityEntity, @"Entity should be present");
    DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:derivationPath inContext:context];
    NSUInteger count = [DSBlockchainIdentityKeyPathEntity countObjectsInContext:context matching:@"blockchainIdentity == %@ && derivationPath == %@ && path == %@", identityEntity, derivationPathEntity, indexPath];
    DOpaqueKey *key = key_info->key;
    DIdentityKeyStatus *status = key_info->key_status;
    DSecurityLevel *security_level = key_info->security_level;
    DPurpose *purpose = key_info->purpose;
    if (!count) {
        NSData *privateKeyData = [DSKeyManager privateKeyData:key];
        if (!privateKeyData) {
            DKeyKind *kind = DOpaqueKeyKind(key);
            DOpaqueKey *privateKey = [self derivePrivateKeyAtIndexPath:indexPath ofType:kind];
            NSAssert([DSKeyManager keysPublicKeyDataIsEqual:privateKey key2:key], @"The keys don't seem to match up");
            privateKeyData = [DSKeyManager privateKeyData:privateKey];
            DKeyKindDtor(kind);
            DOpaqueKeyDtor(privateKey);
            NSAssert(privateKeyData, @"Private key data should exist");
        }
        DSBlockchainIdentityKeyPathEntity *keyPathEntity = [DSBlockchainIdentityKeyPathEntity managedObjectInBlockedContext:context];
        keyPathEntity.derivationPath = derivationPathEntity;
        // TODO: that's wrong should convert KeyType <-> KeyKind
        keyPathEntity.keyType = DOpaqueKeyToKeyTypeIndex(key);
        keyPathEntity.keyStatus = DIdentityKeyStatusToIndex(status);
        NSString *identifier = [self identifierForKeyAtPath:indexPath fromDerivationPath:derivationPath];
        setKeychainData(privateKeyData, identifier, YES);

        keyPathEntity.path = indexPath;
        keyPathEntity.publicKeyData = [DSKeyManager publicKeyData:key];
        keyPathEntity.keyID = (uint32_t)[indexPath indexAtPosition:indexPath.length - 1];
        keyPathEntity.securityLevel = DSecurityLevelIndex(security_level);
        keyPathEntity.purpose = DPurposeIndex(purpose);
        [identityEntity addKeyPathsObject:keyPathEntity];
        return YES;
    } else {
        return NO; //no need to save the context
    }
}

// MARK: Deletion

- (void)deletePersistentObjectAndSave:(BOOL)save
                            inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *identityEntity = [self identityEntityInContext:context];
        if (identityEntity) {
            NSSet<DSFriendRequestEntity *> *friendRequests = [identityEntity.matchingDashpayUser outgoingRequests];
            for (DSFriendRequestEntity *friendRequest in friendRequests) {
                uint32_t accountNumber = friendRequest.account.index;
                DSAccount *account = [self.wallet accountWithNumber:accountNumber];
                [account removeIncomingDerivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
            }
            [identityEntity deleteObjectAndWait];
            if (save)
                [context ds_save];
        }
        [self notifyUpdate:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSIdentityKey: self
        }];
    }];
}

// MARK: Entity

- (DSBlockchainIdentityEntity *)identityEntity {
    return [self identityEntityInContext:[NSManagedObjectContext viewContext]];
}

- (DSBlockchainIdentityEntity *)identityEntityInContext:(NSManagedObjectContext *)context {
    __block DSBlockchainIdentityEntity *entity = nil;
    [context performBlockAndWait:^{
        entity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@", self.uniqueIDData];
    }];
    NSAssert(entity, @"An entity should always be found");
    return entity;
}

- (DSDashpayUserEntity *)matchingDashpayUserInViewContext {
    if (!_matchingDashpayUserInViewContext) {
        _matchingDashpayUserInViewContext = [self matchingDashpayUserInContext:[NSManagedObjectContext viewContext]];
    }
    return _matchingDashpayUserInViewContext;
}

- (DSDashpayUserEntity *)matchingDashpayUserInPlatformContext {
    if (!_matchingDashpayUserInPlatformContext) {
        _matchingDashpayUserInPlatformContext = [self matchingDashpayUserInContext:[NSManagedObjectContext platformContext]];
    }
    return _matchingDashpayUserInPlatformContext;
}

- (DSDashpayUserEntity *)matchingDashpayUserInContext:(NSManagedObjectContext *)context {
    if (_matchingDashpayUserInViewContext || _matchingDashpayUserInPlatformContext) {
        if (context == [_matchingDashpayUserInPlatformContext managedObjectContext]) return _matchingDashpayUserInPlatformContext;
        if (context == [_matchingDashpayUserInViewContext managedObjectContext]) return _matchingDashpayUserInViewContext;
        if (_matchingDashpayUserInPlatformContext) {
            __block NSManagedObjectID *managedId;
            [[NSManagedObjectContext platformContext] performBlockAndWait:^{
                managedId = _matchingDashpayUserInPlatformContext.objectID;
            }];
            return [context objectWithID:managedId];
        } else {
            __block NSManagedObjectID *managedId;
            [[NSManagedObjectContext viewContext] performBlockAndWait:^{
                managedId = _matchingDashpayUserInViewContext.objectID;
            }];
            return [context objectWithID:managedId];
        }
    } else {
        __block DSDashpayUserEntity *dashpayUserEntity = nil;
        [context performBlockAndWait:^{
            dashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:context matching:@"associatedBlockchainIdentity.uniqueID == %@", uint256_data(self.uniqueID)];
        }];
        return dashpayUserEntity;
    }
}

- (void)notifyUpdate:(NSDictionary *_Nullable)userInfo {
    [self notify:DSIdentityDidUpdateNotification userInfo:userInfo];
}

- (BOOL)isDefault {
    return self.wallet.defaultIdentity == self;
}


- (NSString *)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@-%@-%u}", self.currentDashpayUsername, self.uniqueIdString, DIdentityRegistrationStatusIndex(self.model)]];
}

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [Identity: %@]", self.chain.name, uint256_hex(self.uniqueID)];
}


@end
