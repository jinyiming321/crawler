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
my $ua = new LWP::UserAgent;

$ua->timeout(60);
my $mobile_agent = 
        'Mozilla/5.0 (Linux; U; Android 2.1-update1; en-us; sdk Build/ECLAIR)'
        .'AppleWebKit/530.17 (KHTML, like Gecko) Version/4.0 Mobile Safari/530.17';

$ua->agent($mobile_agent);
my $res = $ua->get(shift);
open FH,'>',"apk.html";
if( $res->is_success ){
	print FH $res->content;
}else{
	die "download failed\n";
}

exit 0;
