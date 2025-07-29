// TCP 通讯示例
//  Created by 123 on 2025/7/29.

#import <UIKit/UIKit.h> 
#import "GCDAsyncSocket.h" // for TCP

// 定义数据头结构体 (客户端需要解析)
typedef struct {
    uint32_t sync;      // 0x41564450
    uint8_t ver;
    uint8_t type;
    uint8_t reserve;
    uint8_t m_pt;
    uint32_t json_len;
    uint32_t binary_len;
    uint32_t sequence;
    uint32_t timestamp;
} __attribute__((packed)) ClientPacketHeader;

@interface TCPClientViewController : UIViewController <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *clientSocket;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UITextField *hostTextField;
@property (nonatomic, strong) UITextField *portTextField;
@property (nonatomic, strong) UIButton *connectButton;
@property (nonatomic, strong) UIButton *sendButton;

// 粘包处理缓冲区
@property (nonatomic, strong) NSMutableData *readBuffer;

@end
