#!/usr/bin/perl 
#===============================================================================
#         FILE: get_mm_feeder.pl
#
#        USAGE: ./get_mm_feeder.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: JamesKing , jinyiming456@gmail.com
#      COMPANY: China
#      VERSION: 1.0
#      CREATED: 2011年09月24日 05时28分43秒
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use LWP::UserAgent;
use HTML::TreeBuilder;
use IO::Handle;
use Carp;
use Encode;
    
my $ua = LWP::UserAgent->new;
$ua->timeout(60);
$ua->env_proxy;

open(FEED,">mm.url");
FEED->autoflush(1);

# http://mm.10086.cn/moneditor/cs/soft/softResult.html?categoryId=&orderby=&ordertype=&categoryname=%E5%85%A8%E9%83%A8%E8%BD%AF%E4%BB%B6&appcateid=1&appcatename=%E5%B7%A5%E5%85%B7
my $apps_portal 
    =
    "http://mm.10086.cn/moneditor/cs/soft/softResult.html?categoryId=&orderby=&ordertype=&categoryname=%E5%85%A8%E9%83%A8%E8%BD%AF%E4%BB%B6&appcateid=1&appcatename=%E5%B7%A5%E5%85%B7";

    
my $app_base_url 
    =
"http://mm.10086.cn/moneditor/cs/soft/softResult.html?categoryId=&orderby=&ordertype=&categoryname=全部软件";

my $game_base_url 
    =
    "http://mm.10086.cn/moneditor/cs/game/gameResult.html?categoryId=&orderby=&ordertype=&categoryname=全部游戏";
my $theme_base_url =
"http://mm.10086.cn/moneditor/cs/mobiletheme/themeResult.html?categoryId=&orderby=&ordertype=&categoryname=全部主题";

my $games_portal =
"http://mm.10086.cn/moneditor/cs/game/gameResult.html?categoryId=&orderby=&ordertype=&categoryname=%E5%85%A8%E9%83%A8%E6%B8%B8%E6%88%8F&appcateid=15&appcatename=%E6%A3%8B%E7%89%8C";
my $themes_portal = "http://mm.10086.cn/moneditor/cs/mobiletheme/themeResult.html?categoryId=&orderby=&ordertype=&categoryname=%E5%85%A8%E9%83%A8%E4%B8%BB%E9%A2%98&appcateid=30&appcatename=%E6%A4%8D%E7%89%A9";
my $html = 'ooxx.html';
use FileHandle;
my $fh = new FileHandle(">$html")||die $@;


foreach my $portal ( 
            $apps_portal,
            $themes_portal,
            $games_portal,
            
){
    my $response = $ua->get($portal);
    while( not $response->is_success){
        $response=$ua->get($portal);
    }
                                         
    if ($response->is_success) {
        my $tree;
        my @node;
        my @li_kids;

        my $webpage=$response->content;
        print $fh $webpage;
        eval {
            $tree = HTML::TreeBuilder->new; # empty tree
            $tree->parse($webpage);
            @node = $tree->look_down( id => 'channelNavstatic' );
            Carp::croak( "not find this mark leftbar" ) unless @node;   
=pod
<ul id="channelNavstatic" style="width:600px;">
<li class="selected" appcateid="1">
<a title="工具"
href="/moneditor/cs/soft/softResult.html?categoryId=&orderby=&ordertype=&categoryname=%E5%85%A8%E9%83%A8%E8%BD%AF%E4%BB%B6&appcateid=1&appcatename=%E5%B7%A5%E5%85%B7">工具</a
=cut 
            my @tags = $node[0]->find_by_tag_name('a');
            for(@tags){
                my $link = $_->attr('href');
                print $link ."\n";
                print FEED "http://mm.10086.cn".$_->attr('href')."\n";
                print "http://mm.10086.cn".$_->attr('href')."\n";
                
            }

        
        };
        if($@){
            die "fail to extract Hiapk feeder url: $@";
        }
    }
}
close(FEED);



