//
// WCPLAutoReplyConfig.h
// 关键词自动回复配置
//

#import <Foundation/Foundation.h>

// 回复类型枚举
typedef NS_ENUM(NSInteger, WCPLReplyType) {
    WCPLReplyType_Text = 1,      // 文本回复
    WCPLReplyType_Image = 2,     // 图片回复
};

// 关键词规则
@interface WCPLAutoReplyRule : NSObject

@property (nonatomic, strong) NSString *keyword;        // 关键词
@property (nonatomic, assign) WCPLReplyType replyType;  // 回复类型
@property (nonatomic, strong) NSString *replyContent;   // 回复内容（文本内容或图片URL）
@property (nonatomic, assign) NSInteger delaySeconds;   // 延迟回复秒数（防检测）

@end

// 自动回复配置管理
@interface WCPLAutoReplyConfig : NSObject

@property (nonatomic, assign) BOOL autoReplyEnable;              // 是否启用自动回复
@property (nonatomic, strong) NSMutableArray<WCPLAutoReplyRule *> *rules;  // 关键词规则列表
@property (nonatomic, strong) NSMutableDictionary *replyHistory; // 回复历史（防止频繁回复）
@property (nonatomic, assign) NSInteger minReplyInterval;        // 最小回复间隔（秒）

+ (instancetype)sharedConfig;

// 添加规则
- (void)addRule:(WCPLAutoReplyRule *)rule;

// 匹配关键词
- (WCPLAutoReplyRule *)matchRuleForMessage:(NSString *)message;

// 检查是否可以回复（防止频繁回复同一个人）
- (BOOL)canReplyToUser:(NSString *)username;

// 记录回复历史
- (void)recordReplyToUser:(NSString *)username;

// 配置持久化
- (void)loadConfig;
- (void)saveConfig;

@end

