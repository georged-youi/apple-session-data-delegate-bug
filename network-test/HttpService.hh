#import <Cocoa/Cocoa.h>

#include <thread>
#include <string>

NS_ASSUME_NONNULL_BEGIN

class HTTPService;

@interface SessionDelegate : NSObject<NSURLSessionDataDelegate>
{
@public
    HTTPService *http_service_;
}
@end

class HTTPService
{
public:
    HTTPService();
    void start_transfer(const std::string &url);
    void run();
    void join();
    
    struct ActiveTask
    {
        NSURLSessionDataTask *session_data_task_;
        int redirects_taken_;
        int http_status_code_;
    };
    
    std::thread thread_;
    std::mutex mutex_;
    std::condition_variable cond_;
    NSURLSession *session_;
    ActiveTask active_task_;
};

NS_ASSUME_NONNULL_END
