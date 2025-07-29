// TCP 通讯示例
//  Created by 123 on 2025/7/29.

#import "TCPClientViewController.h"

@interface TCPClientViewController ()

@end

@implementation TCPClientViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    [self setupUI];

    self.clientSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    self.readBuffer = [NSMutableData data]; // 初始化缓冲区
}

- (void)setupUI {
    self.hostTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, 150, 30)];
    self.hostTextField.placeholder = @"服务器IP (e.g., 127.0.0.1)";
    self.hostTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.hostTextField.text = @"127.0.0.1"; // Default host
    [self.view addSubview:self.hostTextField];

    self.portTextField = [[UITextField alloc] initWithFrame:CGRectMake(180, 100, 100, 30)];
    self.portTextField.placeholder = @"端口 (e.g., 12345)";
    self.portTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.portTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.portTextField.text = @"12345"; // Default port
    [self.view addSubview:self.portTextField];

    self.connectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.connectButton.frame = CGRectMake(20, 150, 100, 30);
    [self.connectButton setTitle:@"连接服务器" forState:UIControlStateNormal];
    [self.connectButton addTarget:self action:@selector(connectToServer) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.connectButton];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(140, 150, 100, 30);
    [self.sendButton setTitle:@"发送消息" forState:UIControlStateNormal];
    [self.sendButton addTarget:self action:@selector(sendMessageToServer) forControlEvents:UIControlEventTouchUpInside];
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

- (void)connectToServer {
    NSString *host = self.hostTextField.text;
    uint16_t port = (uint16_t)[self.portTextField.text intValue];

    NSError *error = nil;
    if ([self.clientSocket connectToHost:host onPort:port error:&error]) {
        [self logMessage:[NSString stringWithFormat:@"[客户端] 尝试连接到 %@:%hu...", host, port]];
        self.connectButton.enabled = NO;
    } else {
        [self logMessage:[NSString stringWithFormat:@"[客户端] 连接失败: %@", error.localizedDescription]];
    }
}

// 客户端也可以向服务器发送数据
- (void)sendMessageToServer {
    NSString *message = @"Hello from Client! This is a simple message.";
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    [self.clientSocket writeData:data withTimeout:-1 tag:0];
    [self logMessage:[NSString stringWithFormat:@"[客户端] 向服务器发送数据: %@", message]];
}

#pragma mark - GCDAsyncSocketDelegate

// 连接成功
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [self logMessage:[NSString stringWithFormat:@"[客户端] 成功连接到服务器: %@:%hu", host, port]];
    self.sendButton.enabled = YES;
    // 连接成功后，立即开始持续读取数据
    [sock readDataWithTimeout:-1 tag:0];
}

// 接收到数据
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    // 将接收到的数据追加到缓冲区
    [self.readBuffer appendData:data];
    [self logMessage:[NSString stringWithFormat:@"[客户端] 本次收到原始数据，长度: %lu 字节。当前缓冲区总长度: %lu 字节。",
                               (unsigned long)data.length, (unsigned long)self.readBuffer.length]];

    // 尝试从缓冲区中解析完整的数据包
    [self parsePacketsFromBuffer];

    // GCDAsyncSocket 在 readDataWithTimeout:-1 tag:0 的情况下，
    // 会在数据到达后继续监听。所以这里不需要再次调用 readData。
    
    // 显式地再次调用 readDataWithTimeout，确保持续监听
        // 虽然通常不是必须的，但可以作为诊断和容错手段
        [sock readDataWithTimeout:-1 tag:0];
}

// 数据发送完成
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    [self logMessage:[NSString stringWithFormat:@"[客户端] 数据发送完成 Tag: %ld", tag]];
}

// 断开连接
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    [self logMessage:[NSString stringWithFormat:@"[客户端] 与服务器断开连接. 错误: %@", err.localizedDescription]];
    self.connectButton.enabled = YES;
    self.sendButton.enabled = NO;
    [self.readBuffer setLength:0]; // 清空缓冲区
}


#pragma mark - Packet Parsing Logic (粘包处理核心)

- (void)parsePacketsFromBuffer {
    while (self.readBuffer.length >= 24) { // 至少有头部的大小
        NSData *headerData = [self.readBuffer subdataWithRange:NSMakeRange(0, 24)];
        ClientPacketHeader currentHeader;
        [headerData getBytes:&currentHeader length:sizeof(ClientPacketHeader)];

        // 检查同步标识 (小端序)
        // 0x41564450 对应的 ASCII 是 "AVDP"
        // 直接比较，因为服务器也是按小端序发送这个数值，客户端也是小端序读取
        if (currentHeader.sync != 0x41564450) {
            [self logMessage:[NSString stringWithFormat:@"[客户端解析] 错误: 缓冲区中同步标识不匹配 (接收到: 0x%x)。可能数据损坏或协议错误。尝试移除一个字节重新同步。", currentHeader.sync]];
            // 找到错误的字节并移除，或者直接清空缓冲区并断开连接以避免无限循环
            // 这里我们采取更温和的策略：跳过第一个字节，尝试重新同步
            [self.readBuffer replaceBytesInRange:NSMakeRange(0, 1) withBytes:NULL length:0];
            continue; // 继续循环，尝试从下一个字节开始解析
        }

        // JSON_LEN 和 BINARY_LEN 字段也应该是小端序，直接使用即可。
        // 在iOS/macOS (小端序系统) 上，直接读取 uint32_t 就是正确的值。
        uint32_t jsonLen = currentHeader.json_len;
        uint32_t binaryLen = currentHeader.binary_len;

        NSUInteger totalPacketLength = 24 + jsonLen + binaryLen;

        [self logMessage:[NSString stringWithFormat:@"[客户端解析] 头部解析结果: SYNC=0x%x, Ver=%u, Type=%u, JSON Len=%u, Binary Len=%u, Sequence=%u, Total Packet Len=%lu",
                           currentHeader.sync, currentHeader.ver, currentHeader.type, jsonLen, binaryLen, currentHeader.sequence, (unsigned long)totalPacketLength]];


        if (self.readBuffer.length >= totalPacketLength) {
            // 缓冲区中有完整的包
            NSData *fullPacketData = [self.readBuffer subdataWithRange:NSMakeRange(0, totalPacketLength)];

            [self logMessage:[NSString stringWithFormat:@"[客户端解析] 从缓冲区中提取到完整数据包 (当前Seq: %u).", currentHeader.sequence]];

            // 提取 JSON 数据
            if (jsonLen > 0) {
                NSRange jsonRange = NSMakeRange(24, jsonLen);
                NSData *jsonData = [fullPacketData subdataWithRange:jsonRange];
                NSError *jsonError = nil;
                NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&jsonError];
                if (jsonError) {
                    [self logMessage:[NSString stringWithFormat:@"[客户端解析] JSON 数据解析失败: %@", jsonError.localizedDescription]];
                } else {
                    [self logMessage:[NSString stringWithFormat:@"[客户端解析] 解析JSON数据: %@", jsonDict]];
                }
            } else {
                [self logMessage:@"[客户端解析] 数据包中无JSON数据。"]; // 改用logMessage
            }

            // 提取二进制数据
            if (binaryLen > 0) {
                NSRange binaryRange = NSMakeRange(24 + jsonLen, binaryLen);
                NSData *binaryData = [fullPacketData subdataWithRange:binaryRange];
                NSString *binaryContent = [[NSString alloc] initWithData:binaryData encoding:NSUTF8StringEncoding];
                if (binaryContent) {
                    [self logMessage:[NSString stringWithFormat:@"[客户端解析] 解析二进制数据: %@", binaryContent]];
                } else {
                     [self logMessage:[NSString stringWithFormat:@"[客户端解析] 接收二进制数据 (长度: %lu 字节)，但无法解析为UTF8字符串。", (unsigned long)binaryData.length]];
                }
            } else {
                [self logMessage:@"[客户端解析] 数据包中无二进制数据。"]; // 改用logMessage
            }

            // 从缓冲区中移除已处理的数据
            [self.readBuffer replaceBytesInRange:NSMakeRange(0, totalPacketLength) withBytes:NULL length:0];
            [self logMessage:[NSString stringWithFormat:@"[客户端解析] 成功处理一个数据包，缓冲区剩余长度: %lu 字节。", (unsigned long)self.readBuffer.length]]; // 改用logMessage
            
            // 继续循环，看缓冲区中是否还有下一个完整包
        } else {
            // 缓冲区中数据不足以构成一个完整的包，等待更多数据
            [self logMessage:@"[客户端解析] 缓冲区数据不足以构成完整数据包，等待更多数据..."]; // 改用logMessage
            break; // 跳出循环，等待下一个 didReadData 回调
        }
    }
}

@end
