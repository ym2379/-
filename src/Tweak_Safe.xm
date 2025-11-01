// Tweak_Safe.xm - 安全测试版本
// 包含详细日志和错误处理

#import "WeChatRedEnvelop.h"
#import "WeChatRedEnvelopParam.h"
#import "WCPLSettingViewController.h"
#import "WCPLReceiveRedEnvelopOperation.h"
#import "WCPLRedEnvelopTaskManager.h"
#import "WCPLRedEnvelopConfig.h"
#import "WCPLRedEnvelopParamQueue.h"
#import "WCPLNewFuncAddition.h"
#import "WCPLFuncService.h"
#import "WCPLAVManager.h"
#import "WCPLAutoReplyConfig.h"

// ========== 测试用：应用启动时输出版本信息 ==========
%hook MicroMessengerAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *version = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *build = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    NSLog(@"");
    NSLog(@"========================================");
    NSLog(@"🚀 WCEnhance 插件已加载 [测试版]");
    NSLog(@"========================================");
    NSLog(@"📱 微信版本: %@ (%@)", version, build);
    NSLog(@"⚙️  iOS 版本: %@", [[UIDevice currentDevice] systemVersion]);
    NSLog(@"📱 设备型号: %@", [[UIDevice currentDevice] model]);
    NSLog(@"========================================");
    
    // 检查类是否存在
    NSLog(@"🔍 检查关键类:");
    NSLog(@"   CMessageMgr: %@", %c(CMessageMgr) ? @"✅ 存在" : @"❌ 不存在");
    NSLog(@"   CMessageWrap: %@", %c(CMessageWrap) ? @"✅ 存在" : @"❌ 不存在");
    NSLog(@"   CContactMgr: %@", %c(CContactMgr) ? @"✅ 存在" : @"❌ 不存在");
    NSLog(@"   MMServiceCenter: %@", %c(MMServiceCenter) ? @"✅ 存在" : @"❌ 不存在");
    NSLog(@"========================================");
    NSLog(@"");
    
    return result;
}

%end

// ========== 安全的消息监听 ==========
%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    NSLog(@"========== [AsyncOnAddMsg] 被调用 ==========");
    
    @try {
        // 先执行原方法
        %orig;
        
        // 记录基本信息
        NSLog(@"[Message] 类型: %u", wrap.m_uiMessageType);
        NSLog(@"[Message] 发送人: %@", wrap.m_nsFromUsr);
        NSLog(@"[Message] 接收人: %@", wrap.m_nsToUsr);
        NSLog(@"[Message] 内容长度: %lu", (unsigned long)[wrap.m_nsContent length]);
        
        // 安全调用自动回复
        if ([self respondsToSelector:@selector(wcpl_handleAutoReply:)]) {
            [self wcpl_handleAutoReply:wrap];
        } else {
            NSLog(@"[ERROR] wcpl_handleAutoReply 方法不存在");
        }
        
    } @catch (NSException *exception) {
        NSLog(@"========================================");
        NSLog(@"[EXCEPTION] 捕获异常:");
        NSLog(@"   名称: %@", exception.name);
        NSLog(@"   原因: %@", exception.reason);
        NSLog(@"   堆栈:");
        for (NSString *symbol in [exception callStackSymbols]) {
            NSLog(@"      %@", symbol);
        }
        NSLog(@"========================================");
    }
}

%new
- (void)wcpl_handleAutoReply:(CMessageWrap *)wrap {
    NSLog(@"[AutoReply] ========== 开始处理 ==========");
    
    @try {
        // 1. 检查配置
        WCPLAutoReplyConfig *config = [WCPLAutoReplyConfig sharedConfig];
        if (!config) {
            NSLog(@"[AutoReply] ❌ 配置对象为空");
            return;
        }
        
        if (!config.autoReplyEnable) {
            NSLog(@"[AutoReply] ⏸️  未启用（开关关闭）");
            return;
        }
        
        // 2. 检查消息对象
        if (!wrap) {
            NSLog(@"[AutoReply] ❌ 消息对象为空");
            return;
        }
        
        // 3. 检查消息类型
        if (![wrap respondsToSelector:@selector(m_uiMessageType)]) {
            NSLog(@"[AutoReply] ❌ 消息对象不支持 m_uiMessageType");
            return;
        }
        
        unsigned int msgType = wrap.m_uiMessageType;
        if (msgType != 1) {
            NSLog(@"[AutoReply] ⏸️  非文本消息，类型: %u", msgType);
            return;
        }
        
        // 4. 获取消息内容
        NSString *content = [wrap respondsToSelector:@selector(m_nsContent)] ? wrap.m_nsContent : nil;
        if (!content || content.length == 0) {
            NSLog(@"[AutoReply] ⏸️  消息内容为空");
            return;
        }
        
        NSLog(@"[AutoReply] 📨 收到文本消息: %@", [content substringToIndex:MIN(20, content.length)]);
        
        // 5. 获取发送人
        NSString *fromUser = [wrap respondsToSelector:@selector(m_nsFromUsr)] ? wrap.m_nsFromUsr : nil;
        NSString *toUser = [wrap respondsToSelector:@selector(m_nsToUsr)] ? wrap.m_nsToUsr : nil;
        
        if (!fromUser || !toUser) {
            NSLog(@"[AutoReply] ❌ 无法获取发送人/接收人信息");
            return;
        }
        
        // 6. 检查是否是自己发送的
        CContactMgr *contactMgr = [[%c(MMServiceCenter) defaultCenter] getService:%c(CContactMgr)];
        if (!contactMgr) {
            NSLog(@"[AutoReply] ❌ 无法获取联系人管理器");
            return;
        }
        
        CContact *selfContact = [contactMgr getSelfContact];
        if (!selfContact) {
            NSLog(@"[AutoReply] ❌ 无法获取自己的联系人信息");
            return;
        }
        
        NSString *myUsername = selfContact.m_nsUsrName;
        BOOL isReceived = [toUser isEqualToString:myUsername] && ![fromUser isEqualToString:myUsername];
        
        if (!isReceived) {
            NSLog(@"[AutoReply] ⏸️  不是接收的消息（是自己发出的）");
            return;
        }
        
        NSLog(@"[AutoReply] ✅ 这是别人发给我的消息");
        
        // 7. 检查是否是群聊
        BOOL isGroup = [fromUser hasSuffix:@"@chatroom"];
        if (isGroup) {
            NSLog(@"[AutoReply] ⏸️  群聊消息，暂不回复");
            return;
        }
        
        // 8. 检查回复间隔
        if (![config canReplyToUser:fromUser]) {
            NSLog(@"[AutoReply] ⏸️  回复间隔太短，跳过");
            return;
        }
        
        // 9. 匹配关键词
        WCPLAutoReplyRule *rule = [config matchRuleForMessage:content];
        if (!rule) {
            NSLog(@"[AutoReply] ⏸️  未匹配到关键词");
            return;
        }
        
        NSLog(@"[AutoReply] ✅ 匹配到关键词: %@", rule.keyword);
        NSLog(@"[AutoReply] 📤 准备回复: %@", rule.replyContent);
        
        // 10. 记录回复历史
        [config recordReplyToUser:fromUser];
        
        // 11. 延迟回复
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(rule.delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                switch (rule.replyType) {
                    case WCPLReplyType_Text:
                        NSLog(@"[AutoReply] 🚀 发送文本消息...");
                        [self wcpl_sendTextMessage:rule.replyContent toUser:fromUser];
                        break;
                        
                    case WCPLReplyType_Image:
                        NSLog(@"[AutoReply] 🚀 发送图片消息...");
                        [self wcpl_sendImageWithURL:rule.replyContent toUser:fromUser];
                        break;
                        
                    default:
                        NSLog(@"[AutoReply] ❌ 未知的回复类型: %ld", (long)rule.replyType);
                        break;
                }
            } @catch (NSException *exception) {
                NSLog(@"[AutoReply] ❌ 发送消息异常: %@", exception);
            }
        });
        
    } @catch (NSException *exception) {
        NSLog(@"[AutoReply] ========== 异常 ==========");
        NSLog(@"[AutoReply] 名称: %@", exception.name);
        NSLog(@"[AutoReply] 原因: %@", exception.reason);
        NSLog(@"[AutoReply] =============================");
    }
}

%new
- (void)wcpl_sendTextMessage:(NSString *)text toUser:(NSString *)username {
    NSLog(@"[Send] ========== 发送文本消息 ==========");
    
    @try {
        if (!text || !username) {
            NSLog(@"[Send] ❌ 参数为空");
            return;
        }
        
        NSLog(@"[Send] 文本: %@", text);
        NSLog(@"[Send] 接收人: %@", username);
        
        // 获取自己的信息
        CContactMgr *contactMgr = [[%c(MMServiceCenter) defaultCenter] getService:%c(CContactMgr)];
        CContact *selfContact = [contactMgr getSelfContact];
        
        if (!selfContact) {
            NSLog(@"[Send] ❌ 无法获取自己的信息");
            return;
        }
        
        // 创建消息对象
        CMessageWrap *messageWrap = [[%c(CMessageWrap) alloc] initWithMsgType:1];
        if (!messageWrap) {
            NSLog(@"[Send] ❌ 无法创建消息对象");
            return;
        }
        
        [messageWrap setM_nsFromUsr:selfContact.m_nsUsrName];
        [messageWrap setM_nsToUsr:username];
        [messageWrap setM_nsContent:text];
        [messageWrap setM_uiMessageType:1];
        [messageWrap setM_uiStatus:2];
        [messageWrap setM_uiCreateTime:(unsigned int)[[NSDate date] timeIntervalSince1970]];
        
        NSLog(@"[Send] ✅ 消息对象创建成功");
        
        // 检查发送方法是否存在
        if (![self respondsToSelector:@selector(AddLocalMsg:MsgWrap:fixTime:NewMsgArriveNotify:)]) {
            NSLog(@"[Send] ❌ AddLocalMsg 方法不存在");
            NSLog(@"[Send] ⚠️  可能微信版本不兼容，需要查找新的发送方法");
            return;
        }
        
        // 发送消息
        [self AddLocalMsg:username MsgWrap:messageWrap fixTime:YES NewMsgArriveNotify:NO];
        
        NSLog(@"[Send] ✅ 消息已发送");
        
    } @catch (NSException *exception) {
        NSLog(@"[Send] ========== 发送异常 ==========");
        NSLog(@"[Send] 名称: %@", exception.name);
        NSLog(@"[Send] 原因: %@", exception.reason);
        NSLog(@"[Send] ==============================");
    }
}

%new
- (void)wcpl_sendImageWithURL:(NSString *)imageURL toUser:(NSString *)username {
    NSLog(@"[SendImage] ========== 发送图片消息 ==========");
    
    @try {
        if (!imageURL || !username) {
            NSLog(@"[SendImage] ❌ 参数为空");
            return;
        }
        
        NSLog(@"[SendImage] 图片URL: %@", imageURL);
        NSLog(@"[SendImage] 接收人: %@", username);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @try {
                NSLog(@"[SendImage] 🔄 开始下载图片...");
                NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]];
                
                if (!imageData) {
                    NSLog(@"[SendImage] ❌ 图片下载失败");
                    return;
                }
                
                NSLog(@"[SendImage] ✅ 图片下载成功，大小: %lu bytes", (unsigned long)imageData.length);
                
                UIImage *image = [UIImage imageWithData:imageData];
                if (!image) {
                    NSLog(@"[SendImage] ❌ 图片解析失败");
                    return;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self wcpl_sendImage:image toUser:username];
                });
                
            } @catch (NSException *exception) {
                NSLog(@"[SendImage] ❌ 下载异常: %@", exception);
            }
        });
        
    } @catch (NSException *exception) {
        NSLog(@"[SendImage] ❌ 异常: %@", exception);
    }
}

%new
- (void)wcpl_sendImage:(UIImage *)image toUser:(NSString *)username {
    NSLog(@"[SendImage] 准备发送图片到本地...");
    // 图片发送逻辑...
    // 注意：图片发送可能需要不同的API，需要进一步调试
}

%end

// ========== 其他 Hook 保持不变 ==========

%hook JailBreakHelper

+ (_Bool)JailBroken {
    NSLog(@"[JailBreak] JailBroken 被调用，返回 NO");
    return NO;
}

- (_Bool)IsJailBreak {
    NSLog(@"[JailBreak] IsJailBreak 被调用，返回 NO");
    return NO;
}

%end

