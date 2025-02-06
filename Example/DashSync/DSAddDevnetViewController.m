//
//  DSAddDevnetViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/19/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSAddDevnetViewController.h"
#import "DSAddDevnetAddIPAddressTableViewCell.h"
#import "DSAddDevnetIPAddressTableViewCell.h"
#import "DSKeyValueTableViewCell.h"
#import <DashSync/DashSync.h>

#define IP_ADDRESSES_SECTION 4

@interface DSAddDevnetViewController ()

@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *insertedIPAddresses;
@property (nonatomic, strong) DSKeyValueTableViewCell *addDevnetNameTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *addDevnetVersionTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *sporkAddressTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *sporkPrivateKeyTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *protocolVersionTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *minimumDifficultyBlocksTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *minProtocolVersionTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *instantSendLockQuorumTypeTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *chainLockQuorumTypeTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *platformQuorumTypeTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *dapiJRPCPortTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *dapiGRPCPortTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *dashdPortTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *dpnsContractIDTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *dashpayContractIDTableViewCell;

@property (nonatomic, strong) DSAddDevnetAddIPAddressTableViewCell *addDevnetAddIPAddressTableViewCell;
@property (nonatomic, strong) DSAddDevnetIPAddressTableViewCell *activeAddDevnetIPAddressTableViewCell;

@end

@implementation DSAddDevnetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.allowsSelection = YES;
    self.addDevnetNameTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetNameCellIdentifier"];
    self.addDevnetVersionTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetVersionCellIdentifier"];
    self.addDevnetAddIPAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetAddIPCellIdentifier"];
    self.sporkAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetSporkAddressCellIdentifier"];
    self.dpnsContractIDTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DPNSContractIDCellIdentifier"];
    self.dashpayContractIDTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DashpayContractIDCellIdentifier"];
    self.instantSendLockQuorumTypeTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"ISLocksQuorumTypeCellIdentifier"];
    self.chainLockQuorumTypeTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"ChainLocksQuorumTypeCellIdentifier"];
    self.platformQuorumTypeTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"PlatformQuorumTypeCellIdentifier"];
    self.sporkPrivateKeyTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetSporkPrivateKeyCellIdentifier"];
    self.protocolVersionTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetProtocolVersionCellIdentifier"];
    self.minProtocolVersionTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetMinProtocolVersionCellIdentifier"];
    self.dapiJRPCPortTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DapiJRPCPortCellIdentifier"];
    self.dapiGRPCPortTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DapiGRPCPortCellIdentifier"];
    self.dashdPortTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DashdPortCellIdentifier"];
    self.minimumDifficultyBlocksTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MinimumDifficultyBlocksCellIdentifier"];
    if (!self.chain) {
        self.insertedIPAddresses = [NSMutableOrderedSet orderedSet];
    } else {
        
        int16_t devnetVersion = dash_spv_crypto_network_chain_type_ChainType_devnet_version(self.chain.chainType);
        dash_spv_crypto_network_llmq_type_LLMQType *is_llmq_type = dash_spv_crypto_network_chain_type_ChainType_is_llmq_type(self.chain.chainType);
        dash_spv_crypto_network_llmq_type_LLMQType *cl_llmq_type = dash_spv_crypto_network_chain_type_ChainType_chain_locks_type(self.chain.chainType);
        dash_spv_crypto_network_llmq_type_LLMQType *pl_llmq_type = dash_spv_crypto_network_chain_type_ChainType_platform_type(self.chain.chainType);
        
        DSPeerManager *peerManager = [[DSChainsManager sharedInstance] chainManagerForChain:self.chain].peerManager;
        self.insertedIPAddresses = [NSMutableOrderedSet orderedSetWithArray:peerManager.registeredDevnetPeerServices];
        self.addDevnetNameTableViewCell.valueTextField.text = [DSKeyManager devnetIdentifierFor:self.chain.chainType];
        self.addDevnetVersionTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u", devnetVersion];
        self.protocolVersionTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u", self.chain.protocolVersion];
        self.minProtocolVersionTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u", self.chain.minProtocolVersion];
        self.sporkPrivateKeyTableViewCell.valueTextField.text = self.chain.sporkPrivateKeyBase58String;
        self.sporkAddressTableViewCell.valueTextField.text = self.chain.sporkAddress;
        self.addDevnetNameTableViewCell.userInteractionEnabled = FALSE;
        self.addDevnetVersionTableViewCell.userInteractionEnabled = FALSE;
        self.instantSendLockQuorumTypeTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u", dash_spv_crypto_network_llmq_type_LLMQType_index(is_llmq_type)];
        self.chainLockQuorumTypeTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u",  dash_spv_crypto_network_llmq_type_LLMQType_index(cl_llmq_type)];
        self.platformQuorumTypeTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u", dash_spv_crypto_network_llmq_type_LLMQType_index(pl_llmq_type)];
        self.dashdPortTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u", self.chain.standardPort];
        self.dapiJRPCPortTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u", self.chain.standardDapiJRPCPort];
        self.dapiGRPCPortTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u", self.chain.standardDapiGRPCPort];
        self.minimumDifficultyBlocksTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%u", self.chain.minimumDifficultyBlocks];
        self.dpnsContractIDTableViewCell.valueTextField.text = uint256_is_not_zero(self.chain.dpnsContractID) ? uint256_base58(self.chain.dpnsContractID) : @"";
        self.dashpayContractIDTableViewCell.valueTextField.text = uint256_is_not_zero(self.chain.dashpayContractID) ? uint256_base58(self.chain.dashpayContractID) : @"";
    }

    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// MARK:- Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 8;
            break;
        case 1:
            return 3;
            break;
        case 2:
            return 2;
            break;
        case 3:
            return 2;
            break;
        default:
            return 2 + _insertedIPAddresses.count;
            break;
    }
}

- (DSAddDevnetIPAddressTableViewCell *)IPAddressCellAtIndex:(NSUInteger)index {
    static NSString *CellIdentifier = @"DevnetIPCellIdentifier";
    DSAddDevnetIPAddressTableViewCell *addDevnetIPAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (index < _insertedIPAddresses.count) {
        addDevnetIPAddressTableViewCell.IPAddressTextField.text = [_insertedIPAddresses objectAtIndex:index];
    } else {
        addDevnetIPAddressTableViewCell.IPAddressTextField.text = @"";
    }
    addDevnetIPAddressTableViewCell.IPAddressTextField.delegate = self;
    return addDevnetIPAddressTableViewCell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: {
            switch (indexPath.row) {
                case 0:
                    return self.addDevnetNameTableViewCell;
                case 1:
                    return self.addDevnetVersionTableViewCell;
                case 2:
                    return self.protocolVersionTableViewCell;
                case 3:
                    return self.minProtocolVersionTableViewCell;
                case 4:
                    return self.minimumDifficultyBlocksTableViewCell;
                case 5:
                    return self.dashdPortTableViewCell;
                case 6:
                    return self.dapiJRPCPortTableViewCell;
                case 7:
                    return self.dapiGRPCPortTableViewCell;
                default:
                    NSAssert(NO, @"Unknown cell");
                    return [[UITableViewCell alloc] init];
            }
        }
        case 1:
            switch (indexPath.row) {
                case 0:
                    return self.instantSendLockQuorumTypeTableViewCell;
                case 1:
                    return self.chainLockQuorumTypeTableViewCell;
                case 2:
                    return self.platformQuorumTypeTableViewCell;
                default:
                    NSAssert(NO, @"Unknown cell");
                    return [[UITableViewCell alloc] init];
            }
        case 2:
            switch (indexPath.row) {
                case 0:
                    return self.sporkAddressTableViewCell;
                case 1:
                    return self.sporkPrivateKeyTableViewCell;
                default:
                    NSAssert(NO, @"Unknown cell");
                    return [[UITableViewCell alloc] init];
            }
        case 3:
            switch (indexPath.row) {
                case 0:
                    return self.dpnsContractIDTableViewCell;
                case 1:
                    return self.dashpayContractIDTableViewCell;
                default:
                    NSAssert(NO, @"Unknown cell");
                    return [[UITableViewCell alloc] init];
            }
        case IP_ADDRESSES_SECTION: {
            if (indexPath.row == _insertedIPAddresses.count + 1) return self.addDevnetAddIPAddressTableViewCell;
            return [self IPAddressCellAtIndex:indexPath.row];
        }
    }
    NSAssert(NO, @"Unknown cell");
    return [[UITableViewCell alloc] init];
}

// MARK:- Table View Data Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == IP_ADDRESSES_SECTION && indexPath.row == _insertedIPAddresses.count + 1) {
        if (self.activeAddDevnetIPAddressTableViewCell) {
            NSIndexPath *activeIndexPath = [self.tableView indexPathForCell:self.activeAddDevnetIPAddressTableViewCell];
            if (activeIndexPath.row == indexPath.row - 1) {
                if (![self.insertedIPAddresses containsObject:self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text]) {
                    [self.tableView beginUpdates];
                    [self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField resignFirstResponder];
                    //                [self.insertedIPAddresses addObject:self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text];
                    [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:_insertedIPAddresses.count inSection:IP_ADDRESSES_SECTION]] withRowAnimation:UITableViewRowAnimationTop];
                    [self.tableView endUpdates];
                }
            }
        }
    }
}

// MARK:- Text Field Delegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    for (UITableViewCell *tableViewCell in self.tableView.visibleCells) {
        if ([tableViewCell isMemberOfClass:[DSAddDevnetIPAddressTableViewCell class]]) {
            DSAddDevnetIPAddressTableViewCell *addDevnetIPAddressTableViewCell = (DSAddDevnetIPAddressTableViewCell *)tableViewCell;
            if (addDevnetIPAddressTableViewCell.IPAddressTextField == textField) {
                self.activeAddDevnetIPAddressTableViewCell = addDevnetIPAddressTableViewCell;
            }
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.tableView beginUpdates];
    if ([self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text isEqualToString:@""]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:self.activeAddDevnetIPAddressTableViewCell];
        [self.insertedIPAddresses removeObjectAtIndex:indexPath.row];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
    [self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField resignFirstResponder];
    [self.tableView endUpdates];
    return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField reason:(UITextFieldDidEndEditingReason)reason {
    if (![self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text isEqualToString:@""]) {
        if (![self.insertedIPAddresses containsObject:self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text]) {
            [self.insertedIPAddresses addObject:self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text];
        } else {
            self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text = @"";
        }
    }
    self.activeAddDevnetIPAddressTableViewCell = nil;
}


// MARK:- Navigation

- (void)showError:(NSString *)errorMessage {
}

- (IBAction)save {
    [self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField resignFirstResponder];
    //uint32_t version = [self.addDevnetVersionTableViewCell.valueTextField.text intValue];
    uint32_t protocolVersion = [self.protocolVersionTableViewCell.valueTextField.text intValue];
    uint32_t minProtocolVersion = [self.minProtocolVersionTableViewCell.valueTextField.text intValue];
    NSString *sporkAddress = [self.sporkAddressTableViewCell.valueTextField.text isEqualToString:@""] ? nil : self.sporkAddressTableViewCell.valueTextField.text;
    NSString *sporkPrivateKey = [self.sporkPrivateKeyTableViewCell.valueTextField.text isEqualToString:@""] ? nil : self.sporkPrivateKeyTableViewCell.valueTextField.text;
    uint32_t dashdPort = [self.dashdPortTableViewCell.valueTextField.text isEqualToString:@""] ? DEVNET_STANDARD_PORT : [self.dashdPortTableViewCell.valueTextField.text intValue];
    uint32_t minimumDifficultyBlocks = [self.minimumDifficultyBlocksTableViewCell.valueTextField.text isEqualToString:@""] ? 0 : [self.minimumDifficultyBlocksTableViewCell.valueTextField.text intValue];
    uint32_t dapiJRPCPort = [self.dapiJRPCPortTableViewCell.valueTextField.text isEqualToString:@""] ? DEVNET_DAPI_JRPC_STANDARD_PORT : [self.dapiJRPCPortTableViewCell.valueTextField.text intValue];
    uint32_t dapiGRPCPort = [self.dapiGRPCPortTableViewCell.valueTextField.text isEqualToString:@""] ? DEVNET_DAPI_GRPC_STANDARD_PORT : [self.dapiGRPCPortTableViewCell.valueTextField.text intValue];
    UInt256 dpnsContractID = [self.dpnsContractIDTableViewCell.valueTextField.text isEqualToString:@""] ? UINT256_ZERO : [self.dpnsContractIDTableViewCell.valueTextField.text base58ToData].UInt256;
    UInt256 dashpayContractID = [self.dashpayContractIDTableViewCell.valueTextField.text isEqualToString:@""] ? UINT256_ZERO : [self.dashpayContractIDTableViewCell.valueTextField.text base58ToData].UInt256;
    if (![sporkAddress isValidDashDevnetAddress]) {
        sporkAddress = nil;
    }
    if (![sporkPrivateKey isValidDashDevnetPrivateKey]) {
        sporkPrivateKey = nil;
    }
    if (self.chain) {
        [[DSChainsManager sharedInstance] updateDevnetChain:self.chain forServiceLocations:self.insertedIPAddresses minimumDifficultyBlocks:minimumDifficultyBlocks standardPort:dashdPort dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion sporkAddress:sporkAddress sporkPrivateKey:sporkPrivateKey];
    } else {
        NSString *identifier = self.addDevnetNameTableViewCell.valueTextField.text;
        dash_spv_crypto_network_chain_type_DevnetType *devnet_type = dash_spv_crypto_network_chain_type_devnet_type_from_identifier((char *)[identifier UTF8String]);
        //uint16_t version = [self.addDevnetVersionTableViewCell.valueTextField.text intValue];
        [[DSChainsManager sharedInstance] registerDevnetChainWithIdentifier:devnet_type
                                                        forServiceLocations:self.insertedIPAddresses
                                                withMinimumDifficultyBlocks:minimumDifficultyBlocks
                                                               standardPort:dashdPort
                                                               dapiJRPCPort:dapiJRPCPort
                                                               dapiGRPCPort:dapiGRPCPort
                                                             dpnsContractID:dpnsContractID
                                                          dashpayContractID:dashpayContractID
                                                            protocolVersion:protocolVersion
                                                         minProtocolVersion:minProtocolVersion
                                                               sporkAddress:sporkAddress
                                                            sporkPrivateKey:sporkPrivateKey];
    }
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

- (IBAction)cancel {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
