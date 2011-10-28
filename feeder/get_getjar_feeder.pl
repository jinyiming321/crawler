#*****************************************************************************
# *     Program Title: get_getjar_feeder.pl
# *    
# *     Description: get feeder url
# *    
# *     Author: Yiming Jin
# *    
# *     (C) Copyright 2011-2014 TrustGo Mobile, Inc.
# *     All Rights Reserved.  
# *                           
# *     This program is an unpublished copyrighted work which is proprietary
# *     to TrustGo Mobile, Inc. and contains confidential information that is
# *     not to be reproduced or disclosed to any other person or entity without
# *     prior written consent from TrustGo Mobile, Inc. in each and every
# *     instance.
# *    
# *     WARNING:  Unauthorized reproduction of this program as well as                                                              
# *     unauthorized preparation of derivative works based upon the
# *     program or distribution of copies by sale, rental, lease or
# *     secret laws, punishable by civil and criminal penalties.
#*****************************************************************************

use strict;
use LWP::UserAgent;
use HTML::TreeBuilder;
use IO::Handle;
use Encode ;    
my $ua = LWP::UserAgent->new;
$ua->agent('Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.81 Safari/535.2');
$ua->timeout(60);
$ua->env_proxy;

open(FEED,">getjar.url");
FEED->autoflush(1);

open(MAP,">getjar_map.txt");
MAP->autoflush(1);

my @apps_portal
    =
    (
     'http://www.getjar.com/mobile-education-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-social-and-messaging-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-entertainment-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-finance-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-food-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-all-games-for-google-nexus-s',
     'http://www.getjar.com/mobile-health-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-search-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-lifestyle-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-maps-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-music-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-news-and-weather-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-photos-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-productivity-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-religion-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-shopping-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-sports-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-travel-applications-for-google-nexus-s',
     'http://www.getjar.com/mobile-adult-applications-for-google-nexus-s'
    );
my $base = 'http://www.getjar.com';

my $category_page;

foreach my $port ( @apps_portal ){
    my $res = $ua->get($port);
    while( not $res->is_success ){
        $res = $ua->get($port);
    }
    
    my $tree = new HTML::TreeBuilder;
    $tree->parse( Encode::decode_utf8($res->content) );
    $tree->eof;
    
    my @nodes = $tree->look_down( id => 'subcat_row');
    warn "not sub category" unless @nodes;
    foreach my $node( @nodes ){
        if( ! ref($node) ){
            print $port."/?ref=0&lang=en&o=top\n";
            print $port."/?ref=0&lang=en&o=new\n";
            print FEED $1."?ref=".$2."&lang=en&o=top\n";
            print FEED $1."?ref=".$2."&lang=en&o=new\n";
        
            if( $port =~ m/mobile-(.+?)-applications/){
                print "'$1' => '',\n";
                print MAP "'$1' => '',\n";
            }
        }
        my $href = $base.$node->parent()->attr('href');
        if( $href =~ m/(.+?)\?ref=(\d+)/ ){
            print $1."?ref=".$2."&lang=en&o=top\n";
            print $1."?ref=".$2."&lang=en&o=new\n";
            print FEED $1."?ref=".$2."&lang=en&o=top\n";
            print FEED $1."?ref=".$2."&lang=en&o=new\n";
        }
        if( $href =~ m/mobile-(.+?)-applications/){
            print "'$1' => '',\n";
            print MAP "'$1' => '',\n";
        }
    }
    
    
}

