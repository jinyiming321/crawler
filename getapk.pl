#*****************************************************************************                                                                           
## *     Program Title: 
## *    
## *     Description: This program has functions as below
## *         1) 
## *         2) 
## *         3) 
## *
## *     Author: Yiming Jin
## *    
## *     (C) Copyright 2011-2014 TrustGo Mobile, Inc.
## *     All Rights Reserved.
## *    
## *     This program is an unpublished copyrighted work which is proprietary
## *     to TrustGo Mobile, Inc. and contains confidential information that is not
## *     to be reproduced or disclosed to any other person or entity without
## *     prior written consent from TrustGo Mobile, Inc. in each and every instance.
## *    
## *     WARNING:  Unauthorized reproduction of this program as well as
## *     unauthorized preparation of derivative works based upon the
## *     program or distribution of copies by sale, rental, lease or
## *     lending are violations of federal copyright laws and state trade
## *     secret laws, punishable by civil and criminal penalties.
##*****************************************************************************
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Cookies;
my $ua = new LWP::UserAgent;
my $cookie_jar = new HTTP::Cookies;
$cookie_jar->load('getjar_cookie.txt');

    
$ua->timeout(60);
$ua->cookie_jar($cookie_jar);
my $web_agent = 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.2 (KHTML, like Gecko)'
    .'Chrome/15.0.874.81 Safari/535.2';
my $mobile_agent = 
#        'Mozilla/5.0 (Linux; U; Android 2.1-update1; en-us; sdk Build/ECLAIR)'
#        .'AppleWebKit/530.17 (KHTML, like Gecko) Version/4.0 Mobile Safari/530.17';
        'Mozilla/5.0 (Linux; U; Android 2.2; en-us; Nexus One Build/FRF91) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1';

$ua->agent($mobile_agent);
#$ua->agent($web_agent);
my $res = $ua->get('http://client.getjar.com/mobile/100655/shake-baby-names-free-for-android-os/?lang=en&gjclnt=1');
open FH,'>',"apk.html";
if( $res->is_success ){
	print FH $res->content;
}else{
	die "download failed\n";
}

exit 0;
