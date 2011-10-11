#!/usr/bin/perl 
#===============================================================================
#
#         FILE: re.pl
#
#        USAGE: ./re.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: JamesKing (www.perlwiki.info), jinyiming456@gmail.com
#      COMPANY: China
#      VERSION: 1.0
#      CREATED: 2011年10月09日 11时10分16秒
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Cookies;
my $ua = new LWP::UserAgent;
$ua->timeout(60);
$ua->max_redirect(0);
my $cookie_jar = new HTTP::Cookies; 
$cookie_jar->set_cookie(undef,"handango_device_id","4384",'mobilestore.opera.com',undef);
$ua->cookie_jar($cookie_jar);

my $url =
'http://mobilestore.opera.com/FreeDownload.jsp?productId=303006&shoppingUrl=';
my $res = $ua->get($url);
my $apk_url = $res->header('location');
print "apk_url is $apk_url\n";
exit 0;
