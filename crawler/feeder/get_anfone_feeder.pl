#*****************************************************************************
# *     Program Title: get_anfone_feeder.pl
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
#!/usr/bin/perl
use strict;
use LWP::UserAgent;
use HTML::TreeBuilder;
use IO::Handle;
    
my $ua = LWP::UserAgent->new;
$ua->timeout(60);
$ua->env_proxy;

open(FEED,">anfone.url");
FEED->autoflush(1);

my $apps_portal='http://anfone.com/application.html';
my $games_portal='http://anfone.com/game.html';

foreach my $portal ( $apps_portal,$games_portal){
    my $response = $ua->get($portal);

    while( not $response->is_success){
        $response=$ua->get($portal);
    }
                                         
    if ($response->is_success) {
        my $tree;
        my @node;
        my @li_kids;

        my $webpage=$response->content;
        eval {
            $tree = HTML::TreeBuilder->new; # empty tree
            $tree->parse($webpage);
            
            @node = $tree->look_down( class => 'sort-r-2col');
            @li_kids = $node[0]->content_list;

            foreach(@li_kids){
                next unless ref $_;
                my $a_tag=$_->find_by_tag_name("a");
                next unless defined $a_tag;
                my $category_number=$1 if $a_tag->attr("href")=~/(\d+)/g;
				#http://anfone.com/sort/21.html
				my $url = 'http://anfone.com/sort/'.$1.'.html';
				#$url=~ s/(.*?)(_0_1_1)/$1_${category_number}_1_1/g;
				print $url."\n";
                print FEED "$url\n";
            } 
        };
        if($@){
            die "fail to extract Hiapk feeder url";
        }
    }
}
close(FEED);

