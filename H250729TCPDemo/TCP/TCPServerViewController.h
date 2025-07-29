// TCP 通讯示例
//  Created by 123 on 2025/7/29.

#import <UIKit/UIKit.h>
#import "GCDAsyncSocket.h" // for TCP

@interface TCPServerViewController : UIViewController <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *listenSocket;
@property (nonatomic, strong) NSMutableArray<GCDAsyncSocket *> *connectedSockets;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UITextField *portTextField;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *sendButton;

// 用于包序列号
@property (nonatomic, assign) uint32_t sequenceNumber;

@end
