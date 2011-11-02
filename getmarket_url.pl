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
use Data::Dumper;
use warnings;
use LWP::UserAgent;
use HTTP::Request;
my $ua = new LWP::UserAgent;

$ua->timeout(60);
my $mobile_agent = 'Dalvik/1.1.0 (Linux; U; Android 2.1-update1; sdk Build/ECLAIR)';

$ua->agent($mobile_agent);
=pod
$ua->max_redirect(0);
my $res = $ua->get(shift);
warn $res->header('location');
=cut
#my $request = new HTTP::Request( GET => shift );
my $res = $ua->simple_request( HTTP::Request->new(GET =>'http://download.getjar.com/downloads/wap/export-325-4ga16ki3fnyq5odd1A-gbqh005f09mgdgcg/424183/androidVersion') );
if( $res->is_redirect ){
    print Dumper $res;
}




exit 0;
