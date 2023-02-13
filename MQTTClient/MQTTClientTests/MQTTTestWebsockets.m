//
//  MQTTTestWebsockets.m
//  MQTTClient
//
//  Created by Christoph Krey on 05.12.15.
//  Copyright © 2015-2017 Christoph Krey. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MQTTLog.h"
#import "MQTTTestHelpers.h"
#import "SRWebSocket.h"
#import "MQTTWebsocketTransport.h"

@interface MQTTTestWebsockets : MQTTTestHelpers <SRWebSocketDelegate>

@property (strong, nonatomic) SRWebSocket *websocket;
@property (nonatomic) BOOL next;
@property (nonatomic) BOOL abort;

@end

@implementation MQTTTestWebsockets

- (void)tearDown {
    self.session = nil;
    self.websocket = nil;
    [super tearDown];
}
- (void)testWSTRANSPORT {
    NSDictionary *parameters = MQTTTestHelpers.allBrokers[@"mosquittoWS"];
    MQTTWebsocketTransport *wsTransport = [[MQTTWebsocketTransport alloc] init];
    wsTransport.host = parameters[@"host"];
    wsTransport.port = [parameters[@"port"] intValue];
    wsTransport.tls = [parameters[@"tls"] boolValue];
    
    self.session = [[MQTTSession alloc] init];
    self.session.transport = wsTransport;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    [self.session connectWithConnectHandler:^(NSError *error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:[parameters[@"timeout"] intValue] handler:nil];
    
    XCTestExpectation *closeExpectation = [self expectationWithDescription:@""];
    [self.session closeWithDisconnectHandler:^(NSError *error) {
        XCTAssertNil(error);
        [closeExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:[parameters[@"timeout"] intValue] handler:nil];
}

- (void)testWSLowLevel {
    NSDictionary *parameters = MQTTTestHelpers.allBrokers[@"mosquittoWS"];
    BOOL usingSSL = [parameters[@"tls"] boolValue];
    UInt16 port = [parameters[@"port"] intValue];
    NSString *host = parameters[@"host"];
    
    NSString *protocol = (usingSSL) ? @"wss" : @"ws";
    NSString *portString = (port == 0) ? @"" : [NSString stringWithFormat:@":%d", (unsigned int)port];
    NSString *path = @"/mqtt";
    NSString *urlString = [NSString stringWithFormat:@"%@://%@%@%@", protocol, host, portString, path];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    
    self.websocket = [[SRWebSocket alloc] initWithURLRequest:urlRequest protocols:@[@"mqtt"]];
    self.websocket.delegate = self;
    self.abort = false;
    
    self.timedout = FALSE;
    [self performSelector:@selector(timedout:)
               withObject:nil
               afterDelay:[parameters[@"timeout"] intValue]];
    
    [self.websocket open];
    
    while (!(self.websocket.readyState == SR_OPEN) && !self.abort && !self.timedout) {
        DDLogVerbose(@"waiting for open");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    XCTAssertFalse(self.timedout);
    XCTAssertEqual(self.websocket.readyState, SR_OPEN, @"Websocket not open %ld", (long)self.websocket.readyState);
    
    MQTTMessage *connectMessage = [MQTTMessage connectMessageWithClientId:@"SRWebsocket"
                                                                 userName:nil
                                                                 password:nil
                                                                keepAlive:10
                                                             cleanSession:true
                                                                     will:NO
                                                                willTopic:nil
                                                                  willMsg:nil
                                                                  willQoS:MQTTQosLevelAtLeastOnce
                                                               willRetain:false
                                                            protocolLevel:3
                                                    sessionExpiryInterval:nil
                                                               authMethod:nil
                                                                 authData:nil
                                                requestProblemInformation:nil
                                                        willDelayInterval:nil
                                               requestResponseInformation:nil
                                                           receiveMaximum:nil
                                                        topicAliasMaximum:nil
                                                             userProperty:nil
                                                        maximumPacketSize:nil];
    
    self.timedout = FALSE;
    [self performSelector:@selector(timedout:)
               withObject:nil
               afterDelay:[parameters[@"timeout"] intValue]];
    
    [self.websocket send:connectMessage.wireFormat];
    
    self.next = false;
    while (!self.next && !self.abort && !self.timedout) {
        DDLogVerbose(@"waiting for connect");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    XCTAssertFalse(self.timedout);
    XCTAssert(self.next, @"Websocket not response");
    
    
    [self.websocket close];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSData *data = (NSData *)message;
    DDLogVerbose(@"webSocket didReceiveMessage %ld", (unsigned long)data.length);
    self.next = true;
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket{
    DDLogVerbose(@"webSocketDidOpen");
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    DDLogVerbose(@"webSocket didFailWithError: %@", [error debugDescription]);
    self.abort = true;
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    DDLogVerbose(@"webSocket didCloseWithCode: %ld %@ %d", (long)code, reason, wasClean);
    self.next = true;
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    DDLogVerbose(@"webSocket didReceivePong: %@", pongPayload);
}

- (void)connect:(MQTTSession *)session parameters:(NSDictionary *)parameters{
    self.session.delegate = self;
    self.session.userName = parameters[@"user"];
    self.session.password = parameters[@"pass"];
    
    self.event = -1;
    self.timedout = FALSE;
    [self performSelector:@selector(timedout:)
               withObject:nil
               afterDelay:[parameters[@"timeout"] intValue]];
    
    [self.session connect];
    
    while (!self.timedout && self.event == -1) {
        DDLogVerbose(@"waiting for connection");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    XCTAssertFalse(self.timedout);
    XCTAssertEqual(self.event, MQTTSessionEventConnected, @"Not Connected %ld %@", (long)self.event, self.error);
}

- (void)shutdown:(NSDictionary *)parameters {
    self.event = -1;
    self.timedout = FALSE;
    [self performSelector:@selector(timedout:)
               withObject:nil
               afterDelay:[parameters[@"timeout"] intValue]];
    
    [self.session disconnect];
    
    while (!self.timedout && self.event == -1) {
        DDLogVerbose(@"waiting for disconnect");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    XCTAssertFalse(self.timedout);
    XCTAssertEqual(self.event, MQTTSessionEventConnectionClosedByBroker, @"Not ClosedByBroker %ld %@", (long)self.event, self.error);
    
    self.session.delegate = nil;
    self.session = nil;
}



@end
