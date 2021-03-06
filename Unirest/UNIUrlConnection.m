/*
 The MIT License
 
 Copyright (c) 2013 Mashape (http://mashape.com)
 
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "UNIUrlConnection.h"

@implementation UNIUrlConnection {
    NSURLConnection *connection;
    NSHTTPURLResponse *response;
    NSMutableData *responseData;
}

@synthesize request, queue, completionHandler;

+ (UNIUrlConnection *)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void(^)(NSURLResponse *response, NSData *data, NSError *error))completionHandler
{
    UNIUrlConnection *result = [[UNIUrlConnection alloc] init];
    result.request = request;
    result.queue = queue;
    result.completionHandler = completionHandler;
    result->responseData = [NSMutableData data];
    [result start];
    return result;
}

- (void)dealloc
{
    [self cancel];
}

- (void)start
{
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [connection scheduleInRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
    if (connection) {
        [connection start];
    } else {
        if (completionHandler) completionHandler(nil, nil, nil); completionHandler = nil;
    }
}

- (void)cancel
{
    [connection cancel]; connection = nil;
    completionHandler = nil;
}

- (void)connection:(NSURLConnection *)_connection didReceiveResponse:(NSHTTPURLResponse *)_response
{
    response = _response;
}

- (void)connection:(NSURLConnection *)_connection didReceiveData:(NSData *)data
{
    if (!responseData) {
        responseData = [NSMutableData dataWithData:data];
    } else {
        [responseData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)_connection
{
    connection = nil;
    if (completionHandler) {
        void(^b)(NSURLResponse *response, NSData *data, NSError *error) = completionHandler;
        completionHandler = nil;
        [queue addOperationWithBlock:^{b(self->response, self->responseData, nil);}];
    }
}

- (void)connection:(NSURLConnection *)_connection didFailWithError:(NSError *)error
{
    connection = nil;
    if (completionHandler) {
        void(^b)(NSURLResponse *response, NSData *data, NSError *error) = completionHandler;
        completionHandler = nil;
        [queue addOperationWithBlock:^{b(self->response, self->responseData, error);}];
    }
}

    

#ifdef PIN_TO_SSL

// Copyright  https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning#iOS
-(BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace*)space
{
    return [[space authenticationMethod] isEqualToString: NSURLAuthenticationMethodServerTrust];
}


- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([[[challenge protectionSpace] authenticationMethod] isEqualToString: NSURLAuthenticationMethodServerTrust])
    {
        do
        {
            SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
            if(nil == serverTrust)
                break; /* failed */
            
            OSStatus status = SecTrustEvaluate(serverTrust, NULL);
            if(!(errSecSuccess == status))
                break; /* failed */
            
            SecCertificateRef serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0);
            if(nil == serverCertificate)
                break; /* failed */
            
            CFDataRef serverCertificateData = SecCertificateCopyData(serverCertificate);
            if(nil == serverCertificateData)
                break; /* failed */
            
            const UInt8* const data = CFDataGetBytePtr(serverCertificateData);
            const CFIndex size = CFDataGetLength(serverCertificateData);
            NSData* cert1 = [NSData dataWithBytes:data length:(NSUInteger)size];
            
            NSData* cert2 = [self dataFromHexString:[[[PIN_TO_SSL stringByReplacingOccurrencesOfString:@"<" withString:@""]stringByReplacingOccurrencesOfString:@">" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""]];
            
            if(nil == cert1 || nil == cert2)
                break; /* failed */
            
            const BOOL equal = [cert1 isEqualToData:cert2];
            if(!equal)
                break; /* failed */
            
            // The only good exit point
            return [[challenge sender] useCredential: [NSURLCredential credentialForTrust: serverTrust]
                          forAuthenticationChallenge: challenge];
        } while(0);
        
        // Bad dog
        return [[challenge sender] cancelAuthenticationChallenge: challenge];
    }
}




- (NSData *)dataFromHexString:(NSString *)string
{
    // Converts the NSData string representation back into NSData object
    const char *chars = [string UTF8String];
    int i = 0, len = (int)string.length;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:len / 2];
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte;
    
    while (i < len)
    {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        [data appendBytes:&wholeByte length:1];
    }
    return data;
}

#endif

@end
