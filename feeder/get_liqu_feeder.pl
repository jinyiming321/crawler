#!/usr/bin/perl
use strict;
use LWP::UserAgent;
use HTML::TreeBuilder;
use IO::Handle;
    
my $ua = LWP::UserAgent->new;
$ua->timeout(60);
$ua->env_proxy;

open(FEED,">liqu.url");
FEED->autoflush(1);

#'http://www.liqucn.com/os/android/rj/';
# http://www.liqucn.com/os/android/rj/
my @portals = (
        'http://www.liqucn.com/os/android/rj/',
        'http://www.liqucn.com/os/android/yx/',
        'http://www.liqucn.com/os/android/zt/',
       );


foreach my $portal ( @portals ){
    my $response = $ua->get($portal);

    while( not $response->is_success){
        $response=$ua->get($portal);
    }
                                         
    if ($response->is_success) {
        my $tree;

        my $webpage=$response->content;
        eval {
            $tree = HTML::TreeBuilder->new; # empty tree
            $tree->parse($webpage);
            
            my @nodes = $tree->look_down( class => 'last_cat' );
            for(@nodes){
                my @tags = $nodes[0]->find_by_tag_name('a');
                foreach my $tag(@tags){
                    next unless ref($tag);
                    print FEED $tag->attr('href')."\n";
                }
            }
        };
        if($@){
            die "fail to extract liqu  feeder url";
        }
    }
}
close(FEED);

