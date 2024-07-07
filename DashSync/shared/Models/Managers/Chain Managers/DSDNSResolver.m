//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

//#import <ares.h>

#import <dns.h>
#import <dns_sd.h>
#import <dns_util.h>
#import "DSDNSResolver.h"
#import "NSError+Dash.h"

#define TESTNET_DNS_SEEDS @[@"testnet-seed.dashdot.io"]
//#define TESTNET_DNS_SEEDS @[@"35.92.167.154", @"52.12.116.10"]
#define MAINNET_DNS_SEEDS @[@"dnsseed.dash.org"]
#define SERVICE kDNSServiceType_AAAA

@interface DSDNSResolver ()

@property (nonatomic) BOOL dnsUpdatePending;
@property (nonatomic) NSTimeInterval dnsUpdateTimeout;

@end

@implementation DSDNSResolver

#pragma mark - Public

- (instancetype)initWithTimeout:(NSTimeInterval)timeout {
    if (!(self = [super init])) return nil;
    self.dnsUpdateTimeout = timeout;
    return self;
}

- (void)resolve:(NSString *)dnsSeed {
    if (self.dnsUpdatePending == YES) {
        return;
    } else {
        self.dnsUpdatePending = YES;
    }
    NSLog(@"[DSDNSResolver] resolve: %@", dnsSeed);
    [self resolvePrivate:dnsSeed];
}


#pragma mark - Private

- (void)resolvePrivate:(NSString *)dnsSeed {
    DNSServiceRef sdRef;
    DNSServiceErrorType err;
    const char* host = [dnsSeed UTF8String];
    if (host != NULL) {
        NSTimeInterval remainingTime = self.dnsUpdateTimeout;
        NSDate*        startTime = [NSDate date];
        err = DNSServiceQueryRecord(&sdRef, 0, 0, host, SERVICE, kDNSServiceClass_IN, processDnsReply, &remainingTime);
        NSLog(@"[DSDNSResolver] DNSServiceQueryRecord: for %d: %d, remaining time: %f", SERVICE, err, remainingTime);
        int dns_sd_fd = DNSServiceRefSockFD(sdRef);
        int nfds = dns_sd_fd + 1;
        fd_set readfds;
        int result;
        while (remainingTime > 0) {
            FD_ZERO(&readfds);
            FD_SET(dns_sd_fd, &readfds);
            struct timeval tv;
            tv.tv_sec  = (time_t)remainingTime;
            tv.tv_usec = (remainingTime - tv.tv_sec) * 1000000;
            result = select(nfds, &readfds, (fd_set*)NULL, (fd_set*)NULL, &tv);
            NSLog(@"[DSDNSResolver] result: %d", result);
            if (result == 1) {
                if (FD_ISSET(dns_sd_fd, &readfds)) {
                    err = DNSServiceProcessResult(sdRef);
                    if (err != kDNSServiceErr_NoError) {
                        NSLog(@"[DSDNSResolver] There was an error reading the DNS records.");
                        break;
                    }
                }
            } else if (result == 0) {
                NSLog(@"[DSDNSResolver] select() timed out");
                break;
            } else {
                if (errno == EINTR) {
                    NSLog(@"[DSDNSResolver] select() interrupted, retry.");
                } else {
                    NSLog(@"[DSDNSResolver] select() returned %d errno %d %s.", result, errno, strerror(errno));
                    break;
                }
            }
            NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
            remainingTime -= elapsed;
        }
        DNSServiceRefDeallocate(sdRef);
    }
}

// Function to process and print DNS resource records
void processDNSResourceRecord(dns_resource_record_t *record) {
    if (record == NULL) {
        return;
    }

    NSLog(@"[DSDNSResolver] DNS Record: name=%s, type=%u, class=%u, ttl=%u", record->name, record->dnstype, record->dnsclass, record->ttl);

    switch (record->dnstype) {
        case kDNSServiceType_A:
            printARecord(record->data.A);
            break;
        case kDNSServiceType_AAAA:
            printAAAARecord(record->data.AAAA);
            break;
        case kDNSServiceType_CNAME:
            printCNAMERecord(record->data.CNAME);
            break;
        case kDNSServiceType_SRV:
            printSRVRecord(record->data.SRV);
            break;
        case kDNSServiceType_MX:
            printMXRecord(record->data.MX);
            break;
        case kDNSServiceType_TXT:
            printTXTRecord(record->data.TXT);
            break;
        case kDNSServiceType_PTR:
            printPTRRecord(record->data.PTR);
            break;
        case kDNSServiceType_HINFO:
            printHINFORecord(record->data.HINFO);
            break;
        case kDNSServiceType_SOA:
            printSOARecord(record->data.SOA);
            break;
        case kDNSServiceType_RRSIG:
            printRRSIGRecord(record->data.DNSNULL);
            break;
        default:
            printRawResourceRecord(record->data.DNSNULL);
            NSLog(@"[DSDNSResolver] Unsupported DNS record type: %u", record->dnstype);
            break;
    }
}
static void processDnsReply(DNSServiceRef       sdRef,
                            DNSServiceFlags     flags,
                            uint32_t            interfaceIndex,
                            DNSServiceErrorType errorCode,
                            const char*         fullname,
                            uint16_t            rrtype,
                            uint16_t            rrclass,
                            uint16_t            rdlen,
                            const void*         rdata,
                            uint32_t            ttl,
                            void*               context) {
    NSLog(@"[DSDNSResolver] Reply (%@): error: %d flags: %@", [NSString stringWithCString:fullname encoding:NSUTF8StringEncoding], errorCode, printDNSServiceFlags(flags));
    NSTimeInterval* remainingTime = (NSTimeInterval*)context;
    if (errorCode != kDNSServiceErr_NoError) {
        return;
    }
    if ((flags & kDNSServiceFlagsMoreComing) == 0) {
        NSLog(@"[DSDNSResolver] Wait for update");
        *remainingTime = 0;
    }
    if ((flags & kDNSServiceFlagsMoreComing) == 0) {
        NSTimeInterval* remainingTime = (NSTimeInterval*)context;
        *remainingTime = 0;
        NSLog(@"[DSDNSResolver] All DNS responses received");
    }

    NSMutableData *rrData = [NSMutableData data];
    uint8_t                 u8;
    uint16_t                u16;
    uint32_t                u32;
    u8 = 0;
    [rrData appendBytes:&u8 length:sizeof(uint8_t)];
    u16 = htons(rrtype);
    [rrData appendBytes:&u16 length:sizeof(uint16_t)];
    u16 = htons(rrclass);
    [rrData appendBytes:&u16 length:sizeof(uint16_t)];
    u32 = htonl(ttl);
    [rrData appendBytes:&u32 length:sizeof(uint32_t)];
    u16 = htons(rdlen);
    [rrData appendBytes:&u16 length:sizeof(uint16_t)];
    [rrData appendBytes:rdata length:rdlen];

    dns_resource_record_t *record = dns_parse_resource_record([rrData bytes], (uint32_t) [rrData length]);

    if (record != NULL) {
        processDNSResourceRecord(record);
        dns_free_resource_record(record);
    }
}


// Function to print A record
void printARecord(dns_address_record_t *aRecord) {
    if (aRecord == NULL) return;
    char ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &aRecord->addr, ip, sizeof(ip));
    NSLog(@"[DSDNSResolver] Resolved IPv4 address: %s", ip);
}

// Function to print AAAA record
void printAAAARecord(dns_in6_address_record_t *aaaaRecord) {
    if (aaaaRecord == NULL) return;
    char ip[INET6_ADDRSTRLEN];
    inet_ntop(AF_INET6, aaaaRecord->addr.s6_addr, ip, sizeof(ip));
    NSLog(@"[DSDNSResolver] Resolved IPv6 address: %s", ip);
}

// Function to print CNAME record
void printCNAMERecord(dns_domain_name_record_t *cnameRecord) {
    if (cnameRecord == NULL) return;
    NSLog(@"[DSDNSResolver] CNAME: %s", cnameRecord->name);
}

// Function to print SRV record
void printSRVRecord(dns_SRV_record_t *srvRecord) {
    if (srvRecord == NULL) return;
    NSLog(@"[DSDNSResolver] SRV priority: %u, weight: %u, port: %u, target: %s", 
          srvRecord->priority,
          srvRecord->weight,
          srvRecord->port,
          srvRecord->target);
}

// Function to print MX record
void printMXRecord(dns_MX_record_t *mxRecord) {
    if (mxRecord == NULL) return;
    NSLog(@"[DSDNSResolver] MX preference: %u, exchange: %s", 
          mxRecord->preference,
          mxRecord->name);
}

// Function to print TXT record
void printTXTRecord(dns_TXT_record_t *txtRecord) {
    if (txtRecord == NULL) return;
    NSLog(@"[DSDNSResolver] TXT record:");
    for (uint32_t i = 0; i < txtRecord->string_count; i++) {
        NSLog(@"  %s", txtRecord->strings[i]);
    }
}

// Function to print PTR record
void printPTRRecord(dns_domain_name_record_t *ptrRecord) {
    if (ptrRecord == NULL) return;
    NSLog(@"[DSDNSResolver] PTR record: %s", ptrRecord->name);
}

// Function to print HINFO record
void printHINFORecord(dns_HINFO_record_t *hinfoRecord) {
    if (hinfoRecord == NULL) return;
    NSLog(@"[DSDNSResolver] HINFO CPU: %s, OS: %s",
          hinfoRecord->cpu,
          hinfoRecord->os);
}
// Function to print SOA record
void printSOARecord(dns_SOA_record_t *soaRecord) {
    if (soaRecord == NULL) return;
    NSLog(@"[DSDNSResolver] SOA mname: %s, rname: %s, serial: %u, refresh: %u, retry: %u, expire: %u, minimum: %u",
          soaRecord->mname, 
          soaRecord->rname,
          soaRecord->serial,
          soaRecord->refresh,
          soaRecord->retry,
          soaRecord->expire,
          soaRecord->minimum);
}

// Function to print RRSIG record
void printRRSIGRecord(dns_raw_resource_record_t *rawRecord) {
    if (rawRecord == NULL) return;
    NSData *bytes = [NSData dataWithBytes:rawRecord->data length:rawRecord->length];
    NSLog(@"[DSDNSResolver] RRSIG: %lu", bytes.length);
}


// Function to print raw resource record (for unsupported types)
void printRawResourceRecord(dns_raw_resource_record_t *rawRecord) {
    if (rawRecord != NULL) {
        NSLog(@"[DSDNSResolver] Raw record length: %u, data: %@", rawRecord->length, [NSData dataWithBytes:rawRecord->data length:rawRecord->length]);
    }
}







NSString* printDNSServiceFlags(DNSServiceFlags flags) {
    NSMutableString *strFlags = [NSMutableString string];
    
    if (flags & kDNSServiceFlagsMoreComing) {
        [strFlags appendString:@"kDNSServiceFlagsMoreComing"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsAdd) {
        [strFlags appendString:@"kDNSServiceFlagsAdd"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsDefault) {
        [strFlags appendString:@"kDNSServiceFlagsDefault"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsNoAutoRename) {
        [strFlags appendString:@"kDNSServiceFlagsNoAutoRename"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsShared) {
        [strFlags appendString:@"kDNSServiceFlagsShared"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsUnique) {
        [strFlags appendString:@"kDNSServiceFlagsUnique"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsBrowseDomains) {
        [strFlags appendString:@"kDNSServiceFlagsBrowseDomains"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsRegistrationDomains) {
        [strFlags appendString:@"kDNSServiceFlagsRegistrationDomains"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsLongLivedQuery) {
        [strFlags appendString:@"kDNSServiceFlagsLongLivedQuery"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsAllowRemoteQuery) {
        [strFlags appendString:@"kDNSServiceFlagsAllowRemoteQuery"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsForceMulticast) {
        [strFlags appendString:@"kDNSServiceFlagsForceMulticast"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsKnownUnique) {
        [strFlags appendString:@"kDNSServiceFlagsKnownUnique"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsReturnIntermediates) {
        [strFlags appendString:@"kDNSServiceFlagsReturnIntermediates"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsShareConnection) {
        [strFlags appendString:@"kDNSServiceFlagsShareConnection"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsSuppressUnusable) {
        [strFlags appendString:@"kDNSServiceFlagsSuppressUnusable"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsTimeout) {
        [strFlags appendString:@"kDNSServiceFlagsTimeout"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsIncludeP2P) {
        [strFlags appendString:@"kDNSServiceFlagsIncludeP2P"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsWakeOnResolve) {
        [strFlags appendString:@"kDNSServiceFlagsWakeOnResolve"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsBackgroundTrafficClass) {
        [strFlags appendString:@"kDNSServiceFlagsBackgroundTrafficClass"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsIncludeAWDL) {
        [strFlags appendString:@"kDNSServiceFlagsIncludeAWDL"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsEnableDNSSEC) {
        [strFlags appendString:@"kDNSServiceFlagsForceMulticast"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsValidate) {
        [strFlags appendString:@"kDNSServiceFlagsValidate"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsSecure) {
        [strFlags appendString:@"kDNSServiceFlagsSecure"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsInsecure) {
        [strFlags appendString:@"kDNSServiceFlagsInsecure"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsBogus) {
        [strFlags appendString:@"kDNSServiceFlagsBogus"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsIndeterminate) {
        [strFlags appendString:@"kDNSServiceFlagsIndeterminate"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsUnicastResponse) {
        [strFlags appendString:@"kDNSServiceFlagsUnicastResponse"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsValidateOptional) {
        [strFlags appendString:@"kDNSServiceFlagsValidateOptional"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsWakeOnlyService) {
        [strFlags appendString:@"kDNSServiceFlagsWakeOnlyService"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsThresholdOne) {
        [strFlags appendString:@"kDNSServiceFlagsThresholdOne"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsThresholdFinder) {
        [strFlags appendString:@"kDNSServiceFlagsThresholdFinder"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsPrivateOne) {
        [strFlags appendString:@"kDNSServiceFlagsPrivateOne"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsPrivateTwo) {
        [strFlags appendString:@"kDNSServiceFlagsPrivateTwo"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsPrivateThree) {
        [strFlags appendString:@"kDNSServiceFlagsPrivateThree"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsPrivateFour) {
        [strFlags appendString:@"kDNSServiceFlagsPrivateFour"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsPrivateFive) {
        [strFlags appendString:@"kDNSServiceFlagsPrivateFive"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagAnsweredFromCache) {
        [strFlags appendString:@"kDNSServiceFlagAnsweredFromCache"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsAllowExpiredAnswers) {
        [strFlags appendString:@"kDNSServiceFlagsAllowExpiredAnswers"];
        [strFlags appendString:@" | "];
    }
    if (flags & kDNSServiceFlagsExpiredAnswer) {
        [strFlags appendString:@"kDNSServiceFlagsExpiredAnswer"];
        [strFlags appendString:@" | "];
    }
    return strFlags;
}

@end
