//
//  DSChainsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 5/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSChainsViewController.h"
#import "DSAddDevnetViewController.h"
#import "DSChainTableViewCell.h"
#import "DSSyncViewController.h"
#import <DashSync/DashSync.h>

@interface DSChainsViewController ()

@property (strong, nonatomic) id addChainsObserver;

@end

@implementation DSChainsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self destroyDevnets];
//    This extracts ip addresses of masternodes from dash-network-configs and wraps into objc string format
    
//    grep "masternode-" malort.txt | grep -oE 'public_ip=((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' | sed "s/ /\" \"/g;s/^/@\"/;s/$/\",/"
//    [self setup333];
//    [self setupMalort];
//    [self setupKrupnik];
//    [self setupOuzo];
//    [self setupMekhong];
//    [self setupJackDaniels];
//    [self setupChacha];
    [self setupWhiteRussian];
    [self.tableView reloadData];

    self.addChainsObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainsDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          NSLog(@"Added/removed a chain");
                                                          [self.tableView reloadData];
                                                      }];
}

- (void)destroyDevnets {
    NSArray *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    for (DSChain *chain in devnetChains) {
        [[DSChainsManager sharedInstance] removeDevnetChain:chain];
    }
}

- (void)setupChacha {
    [self setupDevnetWithId:@"chacha"
               sporkAddress:@"ybiRzdGWFeijAgR7a8TJafeNi6Yk6h68ps"
            sporkPrivateKey:@"cPTms6Sd7QuhPWXWQSzMbvg2VbEPsWCsLBbR4PBgvfYRzAPazbt3"
         minProtocolVersion:70225
            protocolVersion:70225
    minimumDifficultyBlocks:1000000
           ISLockQuorumType:DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE
          ISDLockQuorumType:DEVNET_ISDLOCK_DEFAULT_QUORUM_TYPE
        chainLockQuorumType:DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE
         platformQuorumType:DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE
         masternodeSyncMode:DSMasternodeSyncMode_Mixed
                  addresses:@[
        @"34.213.73.187",
        @"35.166.223.113",
        @"34.222.70.155",
        @"54.188.28.123",
        @"52.33.126.127",
        @"34.212.132.210",
        @"54.191.175.225",
        @"54.213.218.58",
        @"34.210.252.158",
        @"34.221.203.109",
        @"52.38.9.28",
        @"34.221.123.183",
        @"35.91.217.175",
        @"34.211.90.216",
        @"35.89.101.137",
        @"52.40.174.175",
        @"34.221.153.236",
        @"54.189.17.85",
    ] walletPhrase:nil];

}

- (void)setupOuzo {
    [self setupDevnetWithId:@"ouzo"
               sporkAddress:@"yeJknC3K3bqknL1b4zV3bQJmYmFJAuHXnn"
            sporkPrivateKey:@"cTenvzwy6XNuQYHaunrbcqQ7Y2EBDKVwA266HrUbxskSpYporezT"
         minProtocolVersion:70221
            protocolVersion:70221
    minimumDifficultyBlocks:1000000
           ISLockQuorumType:DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE
          ISDLockQuorumType:DEVNET_ISDLOCK_DEFAULT_QUORUM_TYPE
        chainLockQuorumType:DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE
         platformQuorumType:DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE
         masternodeSyncMode:DSMasternodeSyncMode_Mixed
                  addresses:@[
        @"52.89.24.208",
        @"34.220.82.112",
        @"54.218.103.107",
        @"52.88.159.80",
        @"52.24.84.40",
        @"34.215.80.36",
        @"54.148.27.171",
        @"34.221.28.77",
        @"54.149.28.80",
        @"35.89.85.37",
        @"34.215.119.240",
        @"18.237.217.216",
        @"35.88.161.210",
        @"52.12.12.63",
        @"52.38.202.134",
        @"54.185.53.61",
        @"52.35.194.112",
        @"52.32.227.138",
        @"35.165.61.89",
        @"54.214.221.119",
        @"18.237.57.115",
        @"54.189.179.235",
        @"35.161.213.120",
        @"54.244.212.246",
        @"35.87.199.78",
        @"54.213.198.223",
        @"54.245.78.176",
        @"35.85.41.146",
        @"34.214.135.215",
        @"52.88.32.62",
        @"34.210.26.177",
    ] walletPhrase:nil];
}

- (void)setupMekhong {
    [self setupDevnetWithId:@"mekhong"
               sporkAddress:@""
            sporkPrivateKey:@""
         minProtocolVersion:70221
            protocolVersion:70221
    minimumDifficultyBlocks:1000000
           ISLockQuorumType:DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE
          ISDLockQuorumType:DEVNET_ISDLOCK_DEFAULT_QUORUM_TYPE
        chainLockQuorumType:DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE
         platformQuorumType:DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE
         masternodeSyncMode:DSMasternodeSyncMode_Mixed
                  addresses:@[
        @"54.188.102.153",
        @"35.87.178.188",
        @"54.212.214.116",
        @"54.202.86.176",
        @"34.221.103.87",
        @"52.13.94.19",
        @"34.219.140.215",
        @"35.87.152.160",
        @"18.237.63.137",
        @"34.221.119.130",
        @"35.89.146.129",
        @"35.88.102.15",
        @"35.167.170.103",
        @"34.217.191.74",
        @"34.223.255.60",
        @"35.163.120.168",
        @"35.86.135.83",
        @"54.218.101.162",
        @"54.188.82.45",
        @"34.220.107.143",
        @"54.187.136.25",
        @"35.87.75.98",
        @"35.88.31.194",
        @"35.167.110.124",
        @"35.85.155.162",
        @"54.190.159.245",
        @"34.221.125.132",
        @"34.221.211.221",
        @"35.89.155.236",
        @"18.236.213.113",
        @"34.211.42.195",
        @"52.13.59.213"
    ] walletPhrase:nil];
}

- (void)setup333 {
    [self setupDevnetWithId:@"333"
               sporkAddress:@"yM6zJAMWoouAZxPvqGDbuHb6BJaD6k4raQ"
            sporkPrivateKey:@"cQnP9JNQp6oaZrvBtqBWRMeQERMkDyuXyvQh1qaph4FdP6cT2cVa"
         minProtocolVersion:70221
            protocolVersion:70221
    minimumDifficultyBlocks:1000000
           ISLockQuorumType:DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE
          ISDLockQuorumType:DEVNET_ISDLOCK_DEFAULT_QUORUM_TYPE
        chainLockQuorumType:DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE
         platformQuorumType:DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE
         masternodeSyncMode:DSMasternodeSyncMode_Mixed
                  addresses:@[
        @"34.220.100.153",
        @"52.12.210.34",
        @"54.71.255.176",
        @"54.187.123.197",
        @"34.217.195.49",
        @"35.89.69.137",
        @"34.210.15.156",
        @"52.39.39.40",
        @"54.245.132.133",
        @"18.236.89.14",
        @"35.163.60.183",
        @"18.237.244.153",
    ] walletPhrase:nil];
}

- (void)setupMalort {
    [self setupDevnetWithId:@"malort"
               sporkAddress:@"yM6zJAMWoouAZxPvqGDbuHb6BJaD6k4raQ"
            sporkPrivateKey:@"cQnP9JNQp6oaZrvBtqBWRMeQERMkDyuXyvQh1qaph4FdP6cT2cVa"
         minProtocolVersion:70221
            protocolVersion:70221
    minimumDifficultyBlocks:1000000
           ISLockQuorumType:DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE
          ISDLockQuorumType:DEVNET_ISDLOCK_DEFAULT_QUORUM_TYPE
        chainLockQuorumType:DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE
         platformQuorumType:DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE
         masternodeSyncMode:DSMasternodeSyncMode_Mixed
                  addresses:@[
        @"34.211.117.176",
        @"35.89.146.98",
        @"52.26.81.223",
        @"34.222.65.245",
        @"54.213.124.14",
        @"18.237.184.197",
        @"34.222.152.243",
        @"34.222.248.102",
        @"18.237.161.253",
        @"35.87.115.28",
        @"34.219.215.20",
        @"35.88.109.177",
    ] walletPhrase:nil];
}

- (void)setupVanaheim {
    [self setupDevnetWithId:@"vanaheim"
                   sporkAddress:@"yX2ACj1usjiLPsx1LGBmn3eNkSWhrBUC5Z"
                sporkPrivateKey:@"cSYpFi9CLFuvKbCTqe4J5BpNeLFYY3EdgTUEWJiou9njrv4hULt3"
         minProtocolVersion:70221
            protocolVersion:70221
    minimumDifficultyBlocks:1000000
           ISLockQuorumType:DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE
          ISDLockQuorumType:DEVNET_ISDLOCK_DEFAULT_QUORUM_TYPE
        chainLockQuorumType:DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE
         platformQuorumType:DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE
         masternodeSyncMode:DSMasternodeSyncMode_Mixed
                      addresses:@[
        @"35.161.144.85",
        @"35.166.87.8",
        @"34.220.121.200",
        @"34.219.75.199",
        @"34.216.104.111",
        @"54.212.169.233",
        @"34.219.64.215",
        @"34.219.255.1",
        @"35.89.50.0",
        @"34.217.61.222",
        @"34.208.8.244",
        @"54.189.89.146",
        @"35.87.37.73",
        @"34.219.214.178",
        @"35.88.213.149",
        @"54.201.199.64",
        @"35.88.233.183",
        @"54.201.190.209",
        @"18.236.163.246",
        @"34.221.229.206",
        @"34.220.252.141",
        @"54.200.58.60",
        @"34.221.11.124",
        @"52.25.246.109",
        @"18.236.88.65",
        @"54.149.112.22",
        @"34.214.38.156",
        @"54.202.85.155",
        @"54.71.116.57",
        @"54.201.37.222",
        @"35.89.78.105",
    ] walletPhrase:nil];

}

- (void)setupKrupnik {
    [self setupDevnetWithId:@"krupnik"
                   sporkAddress:@"yPBtLENPQ6Ri1R7SyjevvvyMdopdFJUsRo"
                sporkPrivateKey:@"cW4VFwXvjAJusUyygeiCCf2CjnHGEpVkybp7Njg9j2apUZutFyAQ"
             minProtocolVersion:70219
                protocolVersion:70220
        minimumDifficultyBlocks:2200
           ISLockQuorumType:DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE
          ISDLockQuorumType:DEVNET_ISDLOCK_DEFAULT_QUORUM_TYPE
        chainLockQuorumType:DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE
         platformQuorumType:DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE
         masternodeSyncMode:DSMasternodeSyncMode_Mixed
                      addresses:@[
                          @"4.210.237.116",
                          @"54.69.65.231",
                          @"54.185.90.95",
                          @"54.186.234.0",
                          @"35.87.212.139",
                          @"34.212.52.44",
                          @"34.217.47.197",
                          @"34.220.79.131",
                          @"18.237.212.176",
                          @"54.188.17.188",
                          @"34.210.1.159",
                      ]
                     walletPhrase:nil];
}

- (void)setupJackDaniels {
    [self setupDevnetWithId:@"jack-daniels"
               sporkAddress:@"yYBanbwp2Pp2kYWqDkjvckY3MosuZzkKp7"
            sporkPrivateKey:@"cTeGz53m7kHgA9L75s4vqFGR89FjYz4D9o44eHfoKjJr2ArbEtwg"
         minProtocolVersion:70219
            protocolVersion:70220
    minimumDifficultyBlocks:4032
           ISLockQuorumType:LLMQType_LlmqtypeDevnet
          ISDLockQuorumType:LLMQType_LlmqtypeDevnetDIP0024
        chainLockQuorumType:LLMQType_LlmqtypeDevnet
         platformQuorumType:LLMQType_LlmqtypeDevnet
         masternodeSyncMode:DSMasternodeSyncMode_Mixed
                  addresses:@[
        @"34.220.200.8",
        @"35.90.255.217",
        @"54.218.109.249",
        @"35.91.227.162",
        @"34.222.40.218",
        @"35.88.38.193",
        @"35.91.226.251",
        @"35.160.157.3",
        @"18.237.219.248",
        @"35.91.210.71",
        @"35.89.227.73",
        @"35.90.188.155",
        @"35.91.132.97",
        @"52.26.218.0",
        @"18.236.242.154",
        @"35.87.198.41",
        @"34.220.65.60",
        @"35.90.106.60",
        @"54.200.34.46",
        @"34.221.71.106",
        @"52.40.10.67",
        @"54.245.163.29",
        @"34.222.54.201",
        @"34.211.49.161",
        @"34.222.47.179",
        @"35.91.139.106",
        @"35.89.107.148",
        @"54.202.58.56",
        @"54.212.110.64",
        @"35.89.25.223",
        @"35.91.168.239",
        @"34.219.242.157",
        @"54.245.137.49",
        @"34.222.42.179",
        @"34.220.158.197",
        @"54.70.92.75",
    ] walletPhrase:nil];
}

- (void)setupMojito {
    [self setupDevnetWithId:@"mojito"
                   sporkAddress:@"yXePLfsnJHGbM2LAWcxXaJaixX4qKs38g1"
                sporkPrivateKey:@"cS4ikCxcqorwKuGNxMfpX8paBqSjnQsqMuM8YjLvSZZd6gcp7WQg"
             minProtocolVersion:70225
                protocolVersion:70225
//    minimumDifficultyBlocks:1000000
        minimumDifficultyBlocks:4032
           ISLockQuorumType:DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE
          ISDLockQuorumType:DEVNET_ISDLOCK_DEFAULT_QUORUM_TYPE
        chainLockQuorumType:DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE
         platformQuorumType:DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE
         masternodeSyncMode:DSMasternodeSyncMode_Mixed
                      addresses:@[
        @"35.91.72.103",
        @"35.87.140.64",
        @"35.88.93.189",
        @"54.212.13.99",
        @"52.32.240.193",
        @"54.71.209.203",
        @"34.220.229.64",
        @"54.185.157.224",
        @"34.219.83.228",
        @"52.42.97.123",
        @"35.89.120.122",
        @"18.237.57.30",
        @"54.149.185.48",
        @"35.163.184.206",
        @"35.89.100.95",
        @"35.88.254.18",
        @"34.220.68.151",
        @"35.162.144.29",
    ]
               walletPhrase:nil];
}

- (void)setupWhiteRussian {
    [self setupDevnetWithId:@"white-russian"
                   sporkAddress:@"yZaEFuVfaycMzvQbHH7dgbDPJ6F2AGLqzR"
                sporkPrivateKey:@"cTvYmnZxCK7A8HekGQYMD7yuXSxVKnwgVVo7fHQrcbzckxYm2g7M"
             minProtocolVersion:70227
                protocolVersion:70227
//    minimumDifficultyBlocks:1000000
        minimumDifficultyBlocks:4032
           ISLockQuorumType:DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE
          ISDLockQuorumType:DEVNET_ISDLOCK_DEFAULT_QUORUM_TYPE
        chainLockQuorumType:DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE
         platformQuorumType:DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE
     masternodeSyncMode:DSMasternodeSyncMode_Rotation
                      addresses:@[
        @"35.85.152.110",
        @"34.209.13.56",
        @"52.42.93.34",
        @"35.87.154.139",
        @"35.92.216.172",
        @"34.222.169.49",
        @"52.27.159.100",
        @"35.90.131.248",
        @"34.211.144.169",
        @"35.163.17.85",
        @"52.26.67.115",
        @"35.92.6.130",
        @"54.191.109.168",
        @"52.39.100.224",
        @"54.200.39.51",
        @"54.185.210.60",
        @"35.89.197.145",
        @"18.246.65.63",
    ]
               walletPhrase:nil];

}

- (void)setupDevnetWithId:(NSString *)identifier
             sporkAddress:(NSString *)sporkAddress
          sporkPrivateKey:(NSString *)sporkPrivateKey
       minProtocolVersion:(uint32_t)minProtocolVersion
          protocolVersion:(uint32_t)protocolVersion
  minimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks
         ISLockQuorumType:(uint32_t)ISLockQuorumType
        ISDLockQuorumType:(uint32_t)ISDLockQuorumType
      chainLockQuorumType:(uint32_t)chainLockQuorumType
       platformQuorumType:(uint32_t)platformQuorumType
       masternodeSyncMode:(DSMasternodeSyncMode)masternodeSyncMode
                addresses:(NSArray<NSString *> *)addresses
             walletPhrase:(NSString *_Nullable)walletPhrase {
    NSString *chainID = [NSString stringWithFormat:@"devnet-%@", identifier];
    NSMutableOrderedSet<NSString *> *insertedIPAddresses = [NSMutableOrderedSet orderedSetWithArray:addresses];
    NSArray<DSChain *> *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    DSChain *chain = nil;
    for (DSChain *devnetChain in devnetChains) {
        if ([devnetChain.devnetIdentifier isEqualToString:chainID]) {
            chain = devnetChain;
            break;
        }
    }
    uint32_t dashdPort = 20001;
    uint32_t dapiJRPCPort = DEVNET_DAPI_JRPC_STANDARD_PORT;
    uint32_t dapiGRPCPort = DEVNET_DAPI_GRPC_STANDARD_PORT;
        
    UInt256 dpnsContractID = UINT256_ZERO;
    UInt256 dashpayContractID = UINT256_ZERO;
    uint32_t version = 1;

    if (chain) {
        [[DSChainsManager sharedInstance] updateDevnetChain:chain
                                                    version:version
                                        forServiceLocations:insertedIPAddresses
                                    minimumDifficultyBlocks:minimumDifficultyBlocks
                                               standardPort:dashdPort
                                               dapiJRPCPort:dapiJRPCPort
                                               dapiGRPCPort:dapiGRPCPort
                                             dpnsContractID:dpnsContractID
                                          dashpayContractID:dashpayContractID
                                            protocolVersion:protocolVersion
                                         minProtocolVersion:minProtocolVersion
                                               sporkAddress:sporkAddress
                                            sporkPrivateKey:sporkPrivateKey
                                           ISLockQuorumType:ISLockQuorumType
                                          ISDLockQuorumType:ISDLockQuorumType
                                        chainLockQuorumType:chainLockQuorumType
                                         platformQuorumType:platformQuorumType
                                         masternodeSyncMode:masternodeSyncMode];
    } else {
        chain = [[DSChainsManager sharedInstance] registerDevnetChainWithIdentifier:chainID
                                                                            version:version
                                                                forServiceLocations:insertedIPAddresses
                                                        withMinimumDifficultyBlocks:minimumDifficultyBlocks
                                                                       standardPort:dashdPort
                                                                       dapiJRPCPort:dapiJRPCPort
                                                                       dapiGRPCPort:dapiGRPCPort
                                                                     dpnsContractID:dpnsContractID
                                                                  dashpayContractID:dashpayContractID
                                                                    protocolVersion:protocolVersion
                                                                 minProtocolVersion:minProtocolVersion
                                                                       sporkAddress:sporkAddress
                                                                    sporkPrivateKey:sporkPrivateKey
                                                                   ISLockQuorumType:ISLockQuorumType
                                                                  ISDLockQuorumType:ISDLockQuorumType
                                                                chainLockQuorumType:chainLockQuorumType
                                                                 platformQuorumType:platformQuorumType
                                                                 masternodeSyncMode:masternodeSyncMode];
    }
    if (walletPhrase) {
        DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:walletPhrase setCreationDate:0 forChain:chain storeSeedPhrase:YES isTransient:NO];
        [chain registerWallet:wallet];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2 + [[[DSChainsManager sharedInstance] devnetChains] count];
}

- (DSChain *)chainForIndex:(NSInteger)index {
    if (index == 0) return [DSChain mainnet];
    if (index == 1) return [DSChain testnet];
    NSInteger devnetIndex = index - 2;
    NSArray *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    return [devnetChains objectAtIndex:devnetIndex];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSChainTableViewCell *cell = (DSChainTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"chainTableViewCell" forIndexPath:indexPath];
    DSChain *chain = [self chainForIndex:indexPath.row];
    if (cell) {
        cell.chainNameLabel.text = chain.name;
    }

    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row > 1;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@"Delete"
                                                                             handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView, void (^_Nonnull completionHandler)(BOOL)) {
                                                                                 DSChain *chain = [self chainForIndex:indexPath.row];
                                                                                 [[DSChainsManager sharedInstance] removeDevnetChain:chain];
                                                                             }];
    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:@"Edit"
                                                                           handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView, void (^_Nonnull completionHandler)(BOOL)) {
                                                                               [self performSegueWithIdentifier:@"AddDevnetSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
                                                                           }];
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, editAction]];
    config.performsFirstActionWithFullSwipe = false;
    return config;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    UITableViewCell *cell = (UITableViewCell *)sender;
    NSInteger index = [self.tableView indexPathForCell:cell].row;
    if ([segue.identifier isEqualToString:@"ChainDetailsSegue"]) {
        DSSyncViewController *syncViewController = (DSSyncViewController *)segue.destinationViewController;
        DSChain *chain = [self chainForIndex:index];
        [[DSVersionManager sharedInstance] upgradeExtendedKeysForWallets:chain.wallets
                                                             withMessage:@"Upgrade keys"
                                                          withCompletion:^(BOOL success, BOOL neededUpgrade, BOOL authenticated, BOOL cancelled){

                                                          }];
        syncViewController.chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:chain];
        syncViewController.title = chain.name;
    } else if ([segue.identifier isEqualToString:@"AddDevnetSegue"]) {
        if ([sender isKindOfClass:[UITableViewCell class]]) {
            DSAddDevnetViewController *addDevnetViewController = (DSAddDevnetViewController *)((UINavigationController *)segue.destinationViewController).topViewController;
            DSChain *chain = [self chainForIndex:index];
            addDevnetViewController.chain = chain;
        }
    }
}


@end
