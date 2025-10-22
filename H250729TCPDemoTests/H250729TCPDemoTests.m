#import <XCTest/XCTest.h>
#import <Foundation/Foundation.h>

// 模拟输入流类，用于测试
@interface MockInputStream : NSInputStream
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, assign) NSUInteger readPosition;
@property (nonatomic, assign) BOOL isOpen;
@end

@implementation MockInputStream

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        _data = [data mutableCopy] ?: [[NSMutableData alloc] init];
        _readPosition = 0;
        _isOpen = NO;
    }
    return self;
}

- (void)open {
    self.isOpen = YES;
}

- (void)close {
    self.isOpen = NO;
}

- (BOOL)hasBytesAvailable {
    return self.isOpen && (self.readPosition < self.data.length);
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (!self.isOpen || self.readPosition >= self.data.length) {
        return 0;
    }
    
    NSUInteger availableBytes = self.data.length - self.readPosition;
    NSUInteger bytesToRead = MIN(len, availableBytes);
    
    [self.data getBytes:buffer range:NSMakeRange(self.readPosition, bytesToRead)];
    self.readPosition += bytesToRead;
    
    return bytesToRead;
}

- (void)appendData:(NSData *)data {
    [self.data appendData:data];
}

@end

// 模拟输出流类，用于测试
@interface MockOutputStream : NSOutputStream
@property (nonatomic, strong) NSMutableData *writtenData;
@property (nonatomic, assign) BOOL isOpen;
@end

@implementation MockOutputStream

- (instancetype)init {
    self = [super init];
    if (self) {
        _writtenData = [[NSMutableData alloc] init];
        _isOpen = NO;
    }
    return self;
}

- (void)open {
    self.isOpen = YES;
}

- (void)close {
    self.isOpen = NO;
}

- (BOOL)hasSpaceAvailable {
    return self.isOpen;
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    if (!self.isOpen) {
        return -1;
    }
    
    [self.writtenData appendBytes:buffer length:len];
    return len;
}

@end
@interface P2PConnection : NSObject
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, strong) NSMutableData *receivedData;

- (instancetype)initWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;
- (NSData *)blockingReadDataWithTimeout:(NSTimeInterval)timeout;
- (NSData *)blockingReadDataOfLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout;
- (void)writeData:(NSData *)data;
- (void)close;
@end

@implementation P2PConnection

- (instancetype)initWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    self = [super init];
    if (self) {
        _inputStream = inputStream;
        _outputStream = outputStream;
        _isConnected = YES;
        _receivedData = [[NSMutableData alloc] init];
        
        [_inputStream open];
        [_outputStream open];
    }
    return self;
}

- (NSData *)blockingReadDataWithTimeout:(NSTimeInterval)timeout {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSMutableData *data = [[NSMutableData alloc] init];
    uint8_t buffer[1024];
    
    while ([NSDate date].timeIntervalSince1970 < timeoutDate.timeIntervalSince1970) {
        if ([self.inputStream hasBytesAvailable]) {
            NSInteger bytesRead = [self.inputStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead > 0) {
                [data appendBytes:buffer length:bytesRead];
                break; // 读取到数据后返回
            } else if (bytesRead < 0) {
                NSLog(@"读取错误: %@", self.inputStream.streamError);
                break;
            }
        }
        
        // 短暂休眠避免过度占用 CPU
        [NSThread sleepForTimeInterval:0.01];
    }
    
    return [data copy];
}

- (NSData *)blockingReadDataOfLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSMutableData *data = [[NSMutableData alloc] init];
    uint8_t buffer[1024];
    
    while (data.length < length && [NSDate date].timeIntervalSince1970 < timeoutDate.timeIntervalSince1970) {
        if ([self.inputStream hasBytesAvailable]) {
            NSUInteger remainingBytes = length - data.length;
            NSUInteger bytesToRead = MIN(remainingBytes, sizeof(buffer));
            
            NSInteger bytesRead = [self.inputStream read:buffer maxLength:bytesToRead];
            if (bytesRead > 0) {
                [data appendBytes:buffer length:bytesRead];
            } else if (bytesRead < 0) {
                NSLog(@"读取错误: %@", self.inputStream.streamError);
                break;
            }
        }
        
        [NSThread sleepForTimeInterval:0.01];
    }
    
    return [data copy];
}

- (void)writeData:(NSData *)data {
    if (self.outputStream.hasSpaceAvailable) {
        [self.outputStream write:data.bytes maxLength:data.length];
    }
}

- (void)close {
    [self.inputStream close];
    [self.outputStream close];
    self.isConnected = NO;
}

@end

// 单元测试类
@interface P2PBlockingReadTests : XCTestCase
@property (nonatomic, strong) P2PConnection *connection;
@property (nonatomic, strong) MockInputStream *mockInputStream;
@property (nonatomic, strong) MockOutputStream *mockOutputStream;
@end

@implementation P2PBlockingReadTests

- (void)setUp {
    [super setUp];
    
    // 创建模拟的输入输出流
    self.mockInputStream = [[MockInputStream alloc] initWithData:nil];
    self.mockOutputStream = [[MockOutputStream alloc] init];
    
    // 初始化 P2P 连接
    self.connection = [[P2PConnection alloc] initWithInputStream:self.mockInputStream
                                                    outputStream:self.mockOutputStream];
}

- (void)tearDown {
    [self.connection close];
    self.connection = nil;
    [super tearDown];
}

// 测试基本的阻塞读取功能
- (void)testBlockingReadDataBasic {
    XCTestExpectation *expectation = [self expectationWithDescription:@"数据读取完成"];
    
    // 在后台线程添加测试数据
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:0.1]; // 模拟延迟
        
        NSString *testString = @"Hello P2P World!";
        NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
        [self.mockInputStream appendData:testData];
        
        [expectation fulfill];
    });
    
    // 等待数据准备好
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    // 执行阻塞读取
    NSData *receivedData = [self.connection blockingReadDataWithTimeout:2.0];
    
    // 验证读取的数据
    XCTAssertNotNil(receivedData, @"应该读取到数据");
    XCTAssertGreaterThan(receivedData.length, 0, @"读取的数据长度应该大于0");
    
    NSString *receivedString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(receivedString, @"Hello P2P World!", @"读取的数据内容应该匹配");
}

// 测试指定长度的阻塞读取
- (void)testBlockingReadDataOfLength {
    XCTestExpectation *expectation = [self expectationWithDescription:@"指定长度数据读取完成"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:0.1];
        
        NSString *testString = @"1234567890ABCDEFGHIJ"; // 20 字节
        NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
        [self.mockInputStream appendData:testData];
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    
    // 只读取前 10 个字节
    NSData *receivedData = [self.connection blockingReadDataOfLength:10 withTimeout:2.0];
    
    XCTAssertNotNil(receivedData, @"应该读取到数据");
    XCTAssertEqual(receivedData.length, 10, @"读取的数据长度应该是 10 字节");
    
    NSString *receivedString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(receivedString, @"1234567890", @"读取的数据内容应该是前10个字符");
}

// 测试读取超时场景
- (void)testBlockingReadTimeout {
    // 不写入任何数据，测试超时情况
    NSDate *startTime = [NSDate date];
    NSData *receivedData = [self.connection blockingReadDataWithTimeout:1.0];
    NSDate *endTime = [NSDate date];
    
    NSTimeInterval elapsed = [endTime timeIntervalSinceDate:startTime];
    
    XCTAssertNotNil(receivedData, @"即使超时也应该返回数据对象");
    XCTAssertEqual(receivedData.length, 0, @"超时时应该返回空数据");
    XCTAssertGreaterThanOrEqual(elapsed, 1.0, @"应该等待至少1秒超时时间");
    XCTAssertLessThan(elapsed, 1.2, @"超时时间不应该过长");
}

// 测试多次连续读取
- (void)testMultipleBlockingReads {
    // 预先准备三条消息
    for (int i = 1; i <= 3; i++) {
        NSString *testString = [NSString stringWithFormat:@"Message %d", i];
        NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
        [self.mockInputStream appendData:testData];
        
        // 添加分隔符
        if (i < 3) {
            NSData *separator = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
            [self.mockInputStream appendData:separator];
        }
    }
    
    // 连续读取数据
    NSMutableArray *receivedMessages = [[NSMutableArray alloc] init];
    
    // 由于我们的模拟流会一次性读取所有数据，我们需要手动分割
    NSData *allData = [self.connection blockingReadDataWithTimeout:1.0];
    NSString *allString = [[NSString alloc] initWithData:allData encoding:NSUTF8StringEncoding];
    NSArray *messages = [allString componentsSeparatedByString:@"\n"];
    
    XCTAssertGreaterThanOrEqual(messages.count, 3, @"应该接收到至少3条消息");
    XCTAssertEqualObjects(messages[0], @"Message 1", @"第一条消息内容正确");
    XCTAssertEqualObjects(messages[1], @"Message 2", @"第二条消息内容正确");
    XCTAssertEqualObjects(messages[2], @"Message 3", @"第三条消息内容正确");
}

// 测试大数据块读取
- (void)testLargeDataBlockingRead {
    // 创建一个较大的测试数据 (1KB)
    NSMutableString *largeString = [[NSMutableString alloc] init];
    for (int i = 0; i < 100; i++) {
        [largeString appendString:@"0123456789"];
    }
    
    NSData *largeData = [largeString dataUsingEncoding:NSUTF8StringEncoding];
    [self.mockInputStream appendData:largeData];
    
    NSData *receivedData = [self.connection blockingReadDataOfLength:1000 withTimeout:3.0];
    
    XCTAssertNotNil(receivedData, @"应该读取到大数据块");
    XCTAssertEqual(receivedData.length, 1000, @"读取的数据长度应该是1000字节");
}

// 性能测试
- (void)testBlockingReadPerformance {
    // 预先准备测试数据
    NSString *testString = @"Performance Test Data";
    NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
    
    [self measureBlock:^{
        // 每次测试前重置模拟输入流
        self.mockInputStream = [[MockInputStream alloc] initWithData:testData];
        [self.mockInputStream open];
        self.connection.inputStream = self.mockInputStream;
        
        NSData *receivedData = [self.connection blockingReadDataWithTimeout:1.0];
        XCTAssertNotNil(receivedData);
        XCTAssertGreaterThan(receivedData.length, 0);
    }];
}

@end
