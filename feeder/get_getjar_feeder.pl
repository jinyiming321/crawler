#!/usr/bin/perl 
#===============================================================================
#
#         FILE: get_getjar_feeder.pl
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: JamesKing (www.perlwiki.info), jinyiming456@gmail.com
#      COMPANY: China
#      VERSION: 1.0
#      CREATED: 2011年09月25日 08时17分52秒
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use LWP::UserAgent;
use HTML::TreeBuilder;
use IO::Handle;
use Carp;
use LWP::Simple;

my $ua = LWP::UserAgent->new;
$ua->timeout(60);
$ua->env_proxy;

open(FEED,">getjar.url");
FEED->autoflush(1);

#'http://www.liqucn.com/os/android/rj/';
# http://www.liqucn.com/os/android/rj/
my $base_url = "http://www.getjar.com/mobile";
my %portals = (
# "http://www.getjar.com/categories",
    "http://www.getjar.com/mobile-education-applications-for-google-nexus-one/" =>
    "education",
    "http://www.getjar.com/mobile-social-and-messaging-applications-for-google-nexus-one/"
    => "social-and-messaging",
    "http://www.getjar.com/mobile-entertainment-applications-for-google-nexus-one/"
    => "entertainment",
    "http://www.getjar.com/mobile-finance-applications-for-google-nexus-one/" =>
    "finance",
    "http://www.getjar.com/mobile-food-applications-for-google-nexus-one/" =>
    "food",
    "http://www.getjar.com/mobile-all-games-for-google-nexus-one/" => "games",
    "http://www.getjar.com/mobile-health-applications-for-google-nexus-one/" =>
    "health",
    "http://www.getjar.com/mobile-search-applications-for-google-nexus-one/" =>
    'search',
    "http://www.getjar.com/mobile-lifestyle-applications-for-google-nexus-one/"
    => 'lifestyle',
    "http://www.getjar.com/mobile-maps-applications-for-google-nexus-one/" =>
    'maps',
    "http://www.getjar.com/mobile-music-applications-for-google-nexus-one/" =>
    'music',
    "http://www.getjar.com/mobile-news-and-weather-applications-for-google-nexus-one/"
    => 'news-and-weather',
    "http://www.getjar.com/mobile-photos-applications-for-google-nexus-one/" => 
    "photos",
    "http://www.getjar.com/mobile-productivity-applications-for-google-nexus-one/" =>
    "productivity",
    "http://www.getjar.com/mobile-religion-applications-for-google-nexus-one/" =>
    "religion",
    "http://www.getjar.com/mobile-shopping-applications-for-google-nexus-one/" =>
    "shopping",
    "http://www.getjar.com/mobile-sports-applications-for-google-nexus-one/" =>
    "sports",
    "http://www.getjar.com/mobile-travel-applications-for-google-nexus-one/" =>
    "travel",
    "http://www.getjar.com/mobile-adult-applications-for-google-nexus-one/" =>
    "adult",
);
foreach my $portal ( keys %portals ){
    my $response = $ua->get($portal);
    while( not $response->is_success){
         $response=$ua->get($portal);
    }
    if ($response->is_success) {
        my $tree;
        my $webpage=$response->content;
        eval {
            $tree = new HTML::TreeBuilder;
            $tree->parse($webpage);
            my @nodes = 
               $tree->look_down( class => 'subcat_list_label pushleft');
            for(@nodes){
                next unless ref $_;
                if( $portals{$portal} ){
                    my $feeder_url =  
                        join( 
                                "-",
                                $base_url,
                                map{ s#^\s+$##g;lc($_) }
                                split('&',$_->as_text),
                                $portals{$portal},
                            );
                    
                    $feeder_url .="-applications-for-google-nexus-one/";
                    print $feeder_url."\n";
                    print FEED $feeder_url."\n";
                }
            }
        };
        if($@){
            die "fail to $@\n";
        }
        $tree->delete;
    }
}
close(FEED);

