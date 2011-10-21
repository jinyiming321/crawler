#*****************************************************************************
# *     Program Title: get_soc_feeder.pl
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
    
my $ua = LWP::UserAgent->new;
$ua->timeout(60);
$ua->env_proxy;

open(FEED,">soc.url");
FEED->autoflush(1);

open(MAP,">soc_map.txt");
MAP->autoflush(1);

my $apps_portal='http://mall.soc.io/apps';
my $base = 'http://mall.soc.io/apps';

foreach my $portal ( $apps_portal){
    my $response = $ua->get($portal);

    while( not $response->is_success){
        $response=$ua->get($portal);
    }
                                         
    if ($response->is_success) {
        my $tree;
        my @nodes;
        my @tags;

        my $webpage=$response->content;
        eval {
            $tree = HTML::TreeBuilder->new; # empty tree
            $tree->parse($webpage);
            $tree->eof;

            @nodes = $tree->look_down(
                _tag  => "ul",
                class => qr/categories_list/,
            );
            foreach my $node( @nodes ){
                 @tags = $node->find_by_tag_name('a');
                 foreach my $tag( @tags ){
                     my $cate_url= $base.(split(';',$tag->attr('href') ))[0];
                     my $cate_name = $tag->as_text;
                     next if $cate_url =~ m/#sub/;
#                     my $cate_url= $base.$tag->attr('href');
                     print "$cate_url"."\n";
                     print FEED "$cate_url"."\n";
                     print MAP "'$cate_name'  => '',\n";
                 }
            }
        };
        if($@){
            die "fail to extract Hiapk feeder url";
        }
    }
}
close(FEED);
close(MAP);

