//
//  DSPaymentRequestTests.m
//  DashSync_Tests
//
//  Created by Andrew Podkovyrin on 19/06/2018.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "DSPaymentRequest.h"
#import "DSChain.h"

@interface DSPaymentRequestTests : XCTestCase

@property (strong, nonatomic) DSChain *chain;

@end

@implementation DSPaymentRequestTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // the chain to test on
    self.chain = [DSChain mainnet];
}

// MARK: - testPaymentRequest

//TODO: test valid request with unknown arguments
//TODO: test invalid dash address
//TODO: test invalid request with unknown required arguments

- (void)testPaymentRequest
{
    DSPaymentRequest *r = [DSPaymentRequest requestWithString:@"Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy" onChain:self.chain];
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    r = [DSPaymentRequest requestWithString:@"Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emc" onChain:self.chain];
    XCTAssertFalse(r.isValidAsNonDashpayPaymentRequest);
    XCTAssertEqualObjects(@"Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emc", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy" onChain:self.chain];
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=1" onChain:self.chain];
    XCTAssertEqual(100000000, r.amount, @"[DSPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=1", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=0.00000001" onChain:self.chain];
    XCTAssertEqual(1, r.amount, @"[DSPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=0.00000001", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=21000000" onChain:self.chain];
    XCTAssertEqual(2100000000000000, r.amount, @"[DSPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=21000000", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    // test for floating point rounding issues, these values cannot be exactly represented with an IEEE 754 double
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=20999999.99999999" onChain:self.chain];
    XCTAssertEqual(2099999999999999, r.amount, @"[DSPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=20999999.99999999", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=20999999.99999995" onChain:self.chain];
    XCTAssertEqual(2099999999999995, r.amount, @"[DSPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=20999999.99999995", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=20999999.9999999" onChain:self.chain];
    XCTAssertEqual(2099999999999990, r.amount, @"[DSPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=20999999.9999999", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=0.07433" onChain:self.chain];
    XCTAssertEqual(7433000, r.amount, @"[DSPaymentRequest requestWithString:]");
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=0.07433", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    // invalid amount string
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?amount=foobar" onChain:self.chain];
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    // test correct encoding of '&' in argument value
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?label=foo%26bar" onChain:self.chain];
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?label=foo%26bar", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    // test handling of ' ' in label or message
    r = [DSPaymentRequest
         requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?label=foo bar&message=bar foo" onChain:self.chain];
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?label=foo%20bar&message=bar%20foo", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    // test bip73
    r = [DSPaymentRequest requestWithString:@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?r=https://foobar.com" onChain:self.chain];
    XCTAssertEqualObjects(@"dash:Xj74g7h8pZTzqudPSzVEL7dFxNZY95Emcy?r=https://foobar.com", r.string,
                          @"[DSPaymentRequest requestWithString:]");
    
    r = [DSPaymentRequest requestWithString:@"dash:?r=https://foobar.com" onChain:self.chain];
    XCTAssertTrue(r.isValidAsNonDashpayPaymentRequest);
    XCTAssertEqualObjects(@"dash:?r=https://foobar.com", r.string, @"[DSPaymentRequest requestWithString:]");
}

@end
