#import "HttpService.hh"

#include <iostream>

@implementation SessionDelegate

// Tells the delegate that the task finished transferring data.
- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error
{
    std::cout << __PRETTY_FUNCTION__ << std::endl;

    NSURLResponse *response = [task response];
    if (response == nil)
    {
        std::cout << "The task response is nil!" << std::endl;
        abort();
    }
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = static_cast<NSHTTPURLResponse *>(response);
        http_service_->active_task_.http_status_code_ = static_cast<int>(httpResponse.statusCode);
    } else {
        http_service_->active_task_.http_status_code_ = 200;
    }
    
    http_service_->cond_.notify_one();
}

// Tells the delegate that the remote server requested an HTTP redirect.
- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    std::cout << __PRETTY_FUNCTION__ << std::endl;
    if (http_service_->active_task_.redirects_taken_ < 1) {
        http_service_->active_task_.redirects_taken_++;
        completionHandler(request);
    } else {
        //std::this_thread::sleep_for(std::chrono::milliseconds(1));
        completionHandler(NULL);
    }
}

// Tells the delegate that the data task received the initial reply (headers) from the server.
#if 0
- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)task
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    std::cout << __PRETTY_FUNCTION__ << std::endl;
    auto it = http_service_->active_tasks_.find((__bridge void *)task);
    HTTPService::ActiveTask &activeTask = it->second;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = static_cast<NSHTTPURLResponse *>(response);
        activeTask.http_status_code_ = static_cast<int>(httpResponse.statusCode);
    } else {
        activeTask.http_status_code_ = 200;
    }
    completionHandler(NSURLSessionResponseAllow);
}
#endif

// Tells the delegate that the data task has received some of the expected data.
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    std::cout << __PRETTY_FUNCTION__ << std::endl;
}

@end

HTTPService::HTTPService()
{
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 8;
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfiguration.URLCache = nil; // disable caching
    sessionConfiguration.HTTPShouldSetCookies = NO;
    [sessionConfiguration setHTTPCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    [sessionConfiguration setHTTPCookieStorage:[NSHTTPCookieStorage sharedHTTPCookieStorage]];

    SessionDelegate *sessionDelegate = [[SessionDelegate alloc] init];
    sessionDelegate->http_service_ = this;
    session_ = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:sessionDelegate delegateQueue:queue];

    thread_ = std::thread(&HTTPService::run, this);
}

void HTTPService::start_transfer(const std::string &url)
{
    @autoreleasepool
    {
        NSString *nsUrl = [[NSString alloc] initWithBytes:url.data() length:url.size() encoding:NSUTF8StringEncoding];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:nsUrl]];
        request.HTTPShouldHandleCookies = NO;
        [request setHTTPMethod:@"GET"];
        NSURLSessionDataTask *task = [session_ dataTaskWithRequest:request];
        {
            std::lock_guard<std::mutex> lock(mutex_);
            active_task_.redirects_taken_ = 0;
            active_task_.http_status_code_ = 0;
            active_task_.session_data_task_ = task;
        }
        [task resume];
    }
}

void HTTPService::run()
{
    for (;;) {
        std::unique_lock<std::mutex> lock(mutex_);
        cond_.wait(lock);
        if (active_task_.session_data_task_.state == NSURLSessionTaskStateCompleted) {
            std::cout << "http status code: " << active_task_.http_status_code_ << std::endl;
            if (active_task_.http_status_code_ == 0) {
                std::cerr << "The http ststus code is unknown! Exiting..." << std::endl;
                abort();
            }
            lock.unlock();
            start_transfer("http://testbin.corp.youi.tv/redirect/3");
        }
    }
    
}

void HTTPService::join()
{
    thread_.join();
}
