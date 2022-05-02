#include "HttpService.hh"

int main(int argc, const char * argv[])
{
    HTTPService httpService;
    httpService.start_transfer("http://testbin.corp.youi.tv/relative-redirect/3");
    httpService.join();
    return 0;
}
