// TCP 通讯示例
//  Created by 123 on 2025/7/29.

#import "TCPServerViewController.h"

// 定义数据头结构体 (与客户端保持一致)
typedef struct {
    uint32_t sync;      // 0x41564450 ("AVDP")
    uint8_t ver;        // 0x01
    uint8_t type;       // Data packet type
    uint8_t reserve;    // Reserved
    uint8_t m_pt;       // Mark bit + payload type
    uint32_t json_len;  // JSON data length (little-endian)
    uint32_t binary_len; // Binary data length (little-endian)
    uint32_t sequence;  // Packet sequence number (little-endian)
    uint32_t timestamp; // Timestamp (little-endian)
} __attribute__((packed)) PacketHeader;

// Helper方法：构建数据头NSData
NSData* buildPacketHeaderData(uint32_t jsonLen, uint32_t binaryLen, uint32_t sequence) {
    NSMutableData *headerData = [NSMutableData dataWithCapacity:24];

    // SYNC: 0x41564450 ("AVDP") - 小端序是 50 44 56 41 (直接写入就是小端序)
    uint32_t sync = 0x41564450;
    [headerData appendBytes:&sync length:sizeof(sync)];

    // VER: 0x01
    uint8_t ver = 0x01;
    [headerData appendBytes:&ver length:sizeof(ver)];

    // TYPE: (placeholder, e.g., 0x01 for generic data)
    uint8_t type = 0x01;
    [headerData appendBytes:&type length:sizeof(type)];

    // RESERVE: (placeholder, e.g., 0x00)
    uint8_t reserve = 0x00;
    [headerData appendBytes:&reserve length:sizeof(reserve)];

    // M+PT: (placeholder, e.g., 0x00)
    uint8_t m_pt = 0x00;
    [headerData appendBytes:&m_pt length:sizeof(m_pt)];

    // JSON_LEN: (little-endian)
    uint32_t le_jsonLen = jsonLen;
    [headerData appendBytes:&le_jsonLen length:sizeof(le_jsonLen)];

    // BINARY_LEN: (little-endian)
    uint32_t le_binaryLen = binaryLen;
    [headerData appendBytes:&le_binaryLen length:sizeof(le_binaryLen)];

    // SEQUENCE: (little-endian)
    uint32_t le_sequence = sequence;
    [headerData appendBytes:&le_sequence length:sizeof(le_sequence)];

    // TIMESTAMP: (little-endian, current Unix timestamp in seconds)
    uint32_t timestamp = (uint32_t)[[NSDate date] timeIntervalSince1970];
    uint32_t le_timestamp = timestamp;
    [headerData appendBytes:&le_timestamp length:sizeof(le_timestamp)];

    return headerData;
}

@interface TCPServerViewController ()

@end

@implementation TCPServerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.connectedSockets = [NSMutableArray array];
    self.sequenceNumber = 0; // 初始化序列号

    [self setupUI];

    self.listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (void)setupUI {
    self.portTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, 200, 30)];
    self.portTextField.placeholder = @"监听端口 (e.g., 12345)";
    self.portTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.portTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.portTextField.text = @"12345"; // Default port
    [self.view addSubview:self.portTextField];

    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.startButton.frame = CGRectMake(240, 100, 100, 30);
    [self.startButton setTitle:@"启动服务器" forState:UIControlStateNormal];
    [self.startButton addTarget:self action:@selector(startServer) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.startButton];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(20, 150, 100, 30);
    [self.sendButton setTitle:@"发送数据" forState:UIControlStateNormal];
    [self.sendButton addTarget:self action:@selector(sendData) forControlEvents:UIControlEventTouchUpInside];
    self.sendButton.enabled = NO; // Disable initially
    [self.view addSubview:self.sendButton];

    self.logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 200, self.view.frame.size.width - 40, self.view.frame.size.height - 220)];
    self.logTextView.editable = NO;
    self.logTextView.layer.borderWidth = 1.0;
    self.logTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    [self.view addSubview:self.logTextView];
}

- (void)logMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logTextView.text = [self.logTextView.text stringByAppendingFormat:@"%@\n", message];
        [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length, 0)];
    });
}

- (void)startServer {
    NSError *error = nil;
    uint16_t port = (uint16_t)[self.portTextField.text intValue];

    if ([self.listenSocket acceptOnPort:port error:&error]) {
        [self logMessage:[NSString stringWithFormat:@"[服务器] 启动成功，监听端口: %hu", port]];
        self.startButton.enabled = NO;
        self.sendButton.enabled = YES;
    } else {
        [self logMessage:[NSString stringWithFormat:@"[服务器] 启动失败: %@", error.localizedDescription]];
    }
}

- (void)sendData {
    // 1. 准备 JSON 数据 (增加内容使其更大)
    NSDictionary *jsonDict = @{
        @"message": @"This is a large JSON message",
        @"timestamp_sent": @([[NSDate date] timeIntervalSince1970]),
        @"source": @"TCP Server",
        @"sequence": @(self.sequenceNumber),
    };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingPrettyPrinted error:&jsonError]; // PrettyPrinted makes it larger for testing

    if (jsonError) {
        [self logMessage:[NSString stringWithFormat:@"[服务器] JSON 数据序列化失败: %@", jsonError.localizedDescription]];
        return;
    }

    // 2. 准备二进制数据 (增加内容使其更大)
    NSMutableString *longBinaryString = [NSMutableString string];
    [longBinaryString appendFormat:@"Binary Data string to increase the binary payload size. "];
    NSData *binaryData = [longBinaryString dataUsingEncoding:NSUTF8StringEncoding];

    // 3. 构建数据头
    uint32_t jsonLength = (uint32_t)jsonData.length;
    uint32_t binaryLength = (uint32_t)binaryData.length;

    self.sequenceNumber++; // 每次发送数据包，序列号递增

    NSData *headerData = buildPacketHeaderData(jsonLength, binaryLength, self.sequenceNumber);

    // 4. 合并数据头、JSON 数据和二进制数据，形成完整的原始数据包
    NSMutableData *fullPacket = [NSMutableData dataWithData:headerData];
    if (jsonData.length > 0) {
        [fullPacket appendData:jsonData];
    }
    if (binaryData.length > 0) {
        [fullPacket appendData:binaryData];
    }

    [self logMessage:[NSString stringWithFormat:@"[服务器] 完整数据包长度: %lu 字节 (Header: %lu, JSON: %u, Binary: %u)",
                       (unsigned long)fullPacket.length, (unsigned long)headerData.length, jsonLength, binaryLength]];

    // --- 模拟粘包处理：将一个完整数据包拆分成两个部分发送 ---
    // 为了更真实地模拟，确保第一部分至少包含整个头部
    NSUInteger firstPartLength;
    if (fullPacket.length > 24) {
        firstPartLength = 24 + (fullPacket.length - 24) / 2; // 头部 + 剩余数据的一半
    } else {
        firstPartLength = fullPacket.length / 2; // 如果包很小，也拆分
    }
    
    // 确保 firstPartLength 至少是 1，并且不超过 fullPacket.length - 1
    if (firstPartLength == 0 && fullPacket.length > 0) firstPartLength = 1;
    if (firstPartLength >= fullPacket.length) firstPartLength = fullPacket.length - 1;


    NSData *firstPart = [fullPacket subdataWithRange:NSMakeRange(0, firstPartLength)];
    NSData *secondPart = [fullPacket subdataWithRange:NSMakeRange(firstPartLength, fullPacket.length - firstPartLength)];

    [self logMessage:[NSString stringWithFormat:@"[服务器] 拆分后第一部分长度: %lu 字节, 第二部分长度: %lu 字节",
                       (unsigned long)firstPart.length, (unsigned long)secondPart.length]];

    if (self.connectedSockets.count > 0) {
        for (GCDAsyncSocket *socket in self.connectedSockets) {
            [self logMessage:[NSString stringWithFormat:@"[服务器] 向客户端 %@ 发送数据包 (Seq: %u). 模拟拆分成两部分发送。",
                              socket.connectedHost, self.sequenceNumber]];
            
            // 第一次发送
            [socket writeData:firstPart withTimeout:-1 tag:100]; // Tag 100 for first part
            [self logMessage:[NSString stringWithFormat:@"[服务器] 发送第一部分完成 (长度: %lu 字节)", (unsigned long)firstPart.length]];
            
            // 延迟一点时间再发送第二部分，这非常重要，可以增加 TCP 分包的可能性
           dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ // 将延迟从 0.5s 改为 2.0s
               // 确保 socket 仍然连接着，否则写入会失败
               if (socket.isConnected) {
                   [socket writeData:secondPart withTimeout:-1 tag:101]; // Tag 101 for second part
                   [self logMessage:[NSString stringWithFormat:@"[服务器] 发送第二部分完成 (长度: %lu 字节)", (unsigned long)secondPart.length]];
               } else {
                   [self logMessage:[NSString stringWithFormat:@"[服务器] 客户端 %@ 已断开，未能发送第二部分。", socket.connectedHost]];
               }
           });
        }
        
    } else {
        [self logMessage:@"[服务器] 没有连接的客户端，无法发送数据。"];
    }
}

#pragma mark - GCDAsyncSocketDelegate

// 有新的客户端连接
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    [self logMessage:[NSString stringWithFormat:@"[服务器] 接受新连接来自: %@:%hu", newSocket.connectedHost, newSocket.connectedPort]];
    [self.connectedSockets addObject:newSocket];
    // 服务器通常只发送，但如果客户端会发数据，这里可以开始读
    // [newSocket readDataWithTimeout:-1 tag:0]; // 如果需要接收客户端数据
}

// 数据发送完成
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    [self logMessage:[NSString stringWithFormat:@"[服务器] 数据发送完成 Tag: %ld 给: %@:%hu", tag, sock.connectedHost, sock.connectedPort]];
}

// 客户端断开连接
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    [self logMessage:[NSString stringWithFormat:@"[服务器] 客户端断开连接: %@:%hu, 错误: %@", sock.connectedHost, sock.connectedPort, err.localizedDescription]];
    [self.connectedSockets removeObject:sock];
}

// 读取到数据 (服务器接收客户端数据) - 这里只是示例，服务器主要职责是发送
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *receivedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (receivedString) {
        [self logMessage:[NSString stringWithFormat:@"[服务器] 从客户端 %@:%hu 接收到数据: %@", sock.connectedHost, sock.connectedPort, receivedString]];
    } else {
        [self logMessage:[NSString stringWithFormat:@"[服务器] 从客户端 %@:%hu 接收到非UTF8编码数据 (长度: %lu 字节)", sock.connectedHost, sock.connectedPort, (unsigned long)data.length]];
    }
    // 继续读取数据
    [sock readDataWithTimeout:-1 tag:0];
}

@end
