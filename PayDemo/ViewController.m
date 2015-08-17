

#import "ViewController.h"
#import "STPAPIClient+ApplePay.h"
#import "STPCard.h"
#import "AFNetworking.h"

// replace this with your own merchant id configured on apple developer portal
NSString * const merchantIdentifier = @"merchant.com.42works.ZoneTickets";

@interface ViewController ()
@property (nonatomic) STPCard * stripeCard;
@end




@implementation ViewController
{
    NSString * amount;
    NSString * description;
    NSString * configId;
}





- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus status))completion
{
    NSLog(@"Payment was authorized: %@", payment);
    
    [self handlePaymentAuthorizationWithPayment:payment completion:completion];
    
}

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller
{
    NSLog(@"Finishing payment view controller");
    
    // hide the payment window
    [controller dismissViewControllerAnimated:TRUE completion:nil];
}

- (IBAction)checkOut:(id)sender
{
    // [Crittercism beginTransaction:@"checkout"];
    
    if([PKPaymentAuthorizationViewController canMakePayments]) {
        
        NSLog(@"Woo! Can make payments!");
        
        if (amount && description && ![self containEmptyAndBlankspacesonlyinTextField:amount] && ![self containEmptyAndBlankspacesonlyinTextField:description]) {
            if ([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:@[PKPaymentNetworkAmex, PKPaymentNetworkMasterCard, PKPaymentNetworkVisa]]) {
                PKPaymentRequest *request = [[PKPaymentRequest alloc] init];
                
                
                
                PKPaymentSummaryItem *total = [PKPaymentSummaryItem summaryItemWithLabel:@"Grand Total"
                                                                                  amount:[NSDecimalNumber decimalNumberWithString:amount]];
                
                request.paymentSummaryItems = @[total];
                request.countryCode = @"US";
                request.currencyCode = @"USD";
                request.supportedNetworks = @[PKPaymentNetworkAmex, PKPaymentNetworkMasterCard, PKPaymentNetworkVisa];
                request.merchantIdentifier = merchantIdentifier;
                request.merchantCapabilities = PKMerchantCapabilityEMV;
                
                PKPaymentAuthorizationViewController *paymentPane = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:request];
                paymentPane.delegate = self;
                [self presentViewController:paymentPane animated:TRUE completion:nil];
            }else
            {
                UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"" message:@"No credit or debit cards are currently configured on this device. Please add a debit or a credit card in Passbook to proceed." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Open Settings", nil];
                [alert show];
            }
            

        }else{
            [self showAlertWithTitle:@"Please check amount and description"];
        }
        
        
    } else {
        NSLog(@"This device cannot make payments");
        _payButton.hidden = YES;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //Initialize amount and description here
    amount = @"2";
    description = @"Tickets";
    
    // This value is configured at server end.Change only if it is required.
    configId = @"Zoneticketsios";
    
    
    
    if(![PKPaymentAuthorizationViewController canMakePayments]) {
        
        
        
        
        
        NSLog(@"This device cannot make payments");
        _payButton.hidden = YES;
    }
//    self.stripeCard = [[STPCard alloc] init];
//    self.stripeCard.name = @"Harry";
//    self.stripeCard.number = @"4000000000000002";
//    self.stripeCard.cvc = @"123";
//    self.stripeCard.expMonth = [@"12" integerValue];
//    self.stripeCard.expYear = [@"2016" integerValue];
//    [[STPAPIClient sharedClient]createTokenWithCard:self.stripeCard completion:^(STPToken* token, NSError* error) {
//        if(error)
//        {
//            NSLog(@"Error === %@",error);
//            
//        }else{
//            NSLog(@"STP token === %@",token);
//            [self createBackendChargeWithToken:token];
//        }
//    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex==1) {
        [self openSettings];
    }
}
- (void)openSettings
{
    BOOL canOpenSettings = (UIApplicationOpenSettingsURLString != NULL);
    if (canOpenSettings) {
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        [[UIApplication sharedApplication] openURL:url];
    }
}
- (void)handlePaymentAuthorizationWithPayment:(PKPayment *)payment
                                   completion:(void (^)(PKPaymentAuthorizationStatus))completion {
    
    [[STPAPIClient sharedClient]createTokenWithPayment:payment completion:^(STPToken *token, NSError *error) {
        if (error) {
            completion(PKPaymentAuthorizationStatusFailure);
            [self addLog:@"STPToken Error" withDescription:error.description];
            [self showAlertWithTitle:@"Unable to get STP Token"];
            
            return;
        }
        /*
         We'll implement this below in "Sending the token to your server".
         Notice that we're passing the completion block through.
         See the above comment in didAuthorizePayment to learn why.
         */
        [self createBackendChargeWithToken:token completion:completion];
    }];
    

}
- (void)createBackendChargeWithToken:(STPToken *)token
                          completion:(void (^)(PKPaymentAuthorizationStatus))completion {
    NSString * tokenString = [[NSString stringWithFormat:@"%@",token] componentsSeparatedByString:@" "][0];
     if (amount && description && ![self containEmptyAndBlankspacesonlyinTextField:amount] && ![self containEmptyAndBlankspacesonlyinTextField:description]) {
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    NSDictionary *parameters = @{@"configId": configId,
                                 @"transactionAmount":amount,
                                 @"description":description,
                                 @"token":tokenString};
    [manager POST:@"http://208.74.19.152:8085/zoneswebservices/ws/StripeTransaction.json" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"JSON: %@", responseObject);
        
        if ([[[responseObject objectForKey:@"stripeTransaction"] valueForKey:@"status"]boolValue]) {
            [self addLog:@"transactionSuccessful" withDescription:[[responseObject objectForKey:@"stripeTransaction"] string]];
            [self showAlertWithTitle:@"Transaction Successful"];
            completion(PKPaymentAuthorizationStatusSuccess);
            
        }else{
            
            [self addLog:@"transactionFailed" withDescription:[[responseObject objectForKey:@"stripeTransaction"] string]];
            [self showAlertWithTitle:@"Transaction Failed"];
            completion(PKPaymentAuthorizationStatusFailure);
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        [self addLog:@"Error" withDescription:error.description];
        [self showAlertWithTitle:@"Transaction Failed"];
        completion(PKPaymentAuthorizationStatusFailure);
        
    }];
     }
     else{
                  [self showAlertWithTitle:@"Please check amount and description"];
              }
}
//- (void)createBackendChargeWithToken:(STPToken *)token
//{
//    NSString * tokenString = [[NSString stringWithFormat:@"%@",token] componentsSeparatedByString:@" "][0];
//     if (amount && description && ![self containEmptyAndBlankspacesonlyinTextField:amount] && ![self containEmptyAndBlankspacesonlyinTextField:description]) {
//    
//    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
//    NSDictionary *parameters = @{@"configId": @"Zoneticketsios",
//                                 @"transactionAmount":@"2",
//                                 @"description":@"Tickets",
//                                 @"token":tokenString};
//    [manager POST:@"http://208.74.19.152:8085/zoneswebservices/ws/StripeTransaction.json" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
//        NSLog(@"JSON: %@", responseObject);
//        
//        if ([[[responseObject objectForKey:@"stripeTransaction"] valueForKey:@"status"]boolValue]) {
//            [self showAlertWithTitle:[NSString stringWithFormat:@"Transaction Successful: %@",[[responseObject objectForKey:@"stripeTransaction"] valueForKey:@"transactionId"]]];
//           
//        }else{
//            [self showAlertWithTitle:@"Transaction Failed"];
//        }
//        
//    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//        NSLog(@"Error: %@", error);
//        [self showAlertWithTitle:@"Transaction Failed"];
//
//    }];
//     }else{
//         [self showAlertWithTitle:@"Please check amount and description"];
//     }
//}

-(void)showAlertWithTitle:(NSString *)string
{
    UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"" message:string delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
    [alert show];
}


-(BOOL)containEmptyAndBlankspacesonlyinTextField:(NSString  *)string
{
    NSString *rawString = string;
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *trimmed = [rawString stringByTrimmingCharactersInSet:whitespace];
    if ([trimmed length] == 0) {
        return YES;
    }else{
        return NO;
    }
}

-(void)addLog:(NSString *)type withDescription:(NSString *)descr
{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    NSDictionary *parameters = @{@"type": type,
                                 @"description":descr,
                                 @"appName":@"ZoneTickets"};
    [manager POST:@"https://sandboxlogger42works.herokuapp.com/log/addLog" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"JSON: %@", responseObject);
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        
        
    }];

}



@end
