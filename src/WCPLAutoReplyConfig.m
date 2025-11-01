//
// WCPLAutoReplyConfig.m
// 关键词自动回复配置实现
//

#import "WCPLAutoReplyConfig.h"

// ========== WCPLAutoReplyRule 实现 ==========

@implementation WCPLAutoReplyRule

- (instancetype)init {
    if (self = [super init]) {
        _delaySeconds = 2; // 默认延迟2秒回复
    }
    return self;
}

// 编码（用于持久化）
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_keyword forKey:@"keyword"];
    [coder encodeInteger:_replyType forKey:@"replyType"];
    [coder encodeObject:_replyContent forKey:@"replyContent"];
    [coder encodeInteger:_delaySeconds forKey:@"delaySeconds"];
}

// 解码（用于持久化）
- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _keyword = [coder decodeObjectForKey:@"keyword"];
        _replyType = [coder decodeIntegerForKey:@"replyType"];
        _replyContent = [coder decodeObjectForKey:@"replyContent"];
        _delaySeconds = [coder decodeIntegerForKey:@"delaySeconds"];
    }
    return self;
}

@end

// ========== WCPLAutoReplyConfig 实现 ==========

@implementation WCPLAutoReplyConfig

+ (instancetype)sharedConfig {
    static WCPLAutoReplyConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[WCPLAutoReplyConfig alloc] init];
        [config loadConfig];
    });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _autoReplyEnable = NO;
        _rules = [NSMutableArray array];
        _replyHistory = [NSMutableDictionary dictionary];
        _minReplyInterval = 60; // 默认最小回复间隔60秒
        
        // 添加默认规则
        [self addDefaultRules];
    }
    return self;
}

// 添加默认规则示例
- (void)addDefaultRules {
    // 示例1：文本回复
    WCPLAutoReplyRule *rule1 = [[WCPLAutoReplyRule alloc] init];
    rule1.keyword = @"你好";
    rule1.replyType = WCPLReplyType_Text;
    rule1.replyContent = @"您好！有什么可以帮助您的吗？😊";
    rule1.delaySeconds = 2;
    [_rules addObject:rule1];
    
    // 示例2：文本回复
    WCPLAutoReplyRule *rule2 = [[WCPLAutoReplyRule alloc] init];
    rule2.keyword = @"在吗";
    rule2.replyType = WCPLReplyType_Text;
    rule2.replyContent = @"在的，请问有什么事情？";
    rule2.delaySeconds = 3;
    [_rules addObject:rule2];
    
    // 示例3：图片回复（需要替换为实际图片URL）
    WCPLAutoReplyRule *rule3 = [[WCPLAutoReplyRule alloc] init];
    rule3.keyword = @"价格表";
    rule3.replyType = WCPLReplyType_Image;
    rule3.replyContent = @"https://example.com/price.jpg"; // 替换为实际图片URL
    rule3.delaySeconds = 2;
    [_rules addObject:rule3];
}

// 添加规则
- (void)addRule:(WCPLAutoReplyRule *)rule {
    if (rule && rule.keyword && rule.replyContent) {
        [_rules addObject:rule];
        [self saveConfig];
    }
}

// 匹配关键词（找到第一个匹配的规则）
- (WCPLAutoReplyRule *)matchRuleForMessage:(NSString *)message {
    if (!message || message.length == 0) {
        return nil;
    }
    
    for (WCPLAutoReplyRule *rule in _rules) {
        if ([message containsString:rule.keyword]) {
            return rule;
        }
    }
    
    return nil;
}

// 检查是否可以回复（防止频繁回复）
- (BOOL)canReplyToUser:(NSString *)username {
    if (!username) {
        return NO;
    }
    
    // 检查上次回复时间
    NSDate *lastReplyDate = _replyHistory[username];
    if (lastReplyDate) {
        NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:lastReplyDate];
        if (interval < _minReplyInterval) {
            NSLog(@"[AutoReply] 距离上次回复 %@ 只有 %.0f 秒，间隔太短，不回复", username, interval);
            return NO;
        }
    }
    
    return YES;
}

// 记录回复历史
- (void)recordReplyToUser:(NSString *)username {
    if (username) {
        _replyHistory[username] = [NSDate date];
    }
}

// 加载配置
- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 加载开关状态
    _autoReplyEnable = [defaults boolForKey:@"WCPLAutoReplyEnable"];
    
    // 加载最小回复间隔
    NSInteger interval = [defaults integerForKey:@"WCPLMinReplyInterval"];
    if (interval > 0) {
        _minReplyInterval = interval;
    }
    
    // 加载规则列表
    NSData *rulesData = [defaults objectForKey:@"WCPLAutoReplyRules"];
    if (rulesData) {
        NSArray *savedRules = [NSKeyedUnarchiver unarchiveObjectWithData:rulesData];
        if (savedRules && [savedRules isKindOfClass:[NSArray class]]) {
            _rules = [savedRules mutableCopy];
        }
    }
    
    NSLog(@"[AutoReply] 配置加载完成，规则数量：%lu", (unsigned long)_rules.count);
}

// 保存配置
- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 保存开关状态
    [defaults setBool:_autoReplyEnable forKey:@"WCPLAutoReplyEnable"];
    
    // 保存最小回复间隔
    [defaults setInteger:_minReplyInterval forKey:@"WCPLMinReplyInterval"];
    
    // 保存规则列表
    NSData *rulesData = [NSKeyedArchiver archivedDataWithRootObject:_rules];
    [defaults setObject:rulesData forKey:@"WCPLAutoReplyRules"];
    
    // 立即同步
    [defaults synchronize];
    
    NSLog(@"[AutoReply] 配置已保存");
}

@end

