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

my $games_portal = $game_base_url."&appcateid=17&appcatename=体育";
my $themes_portal = "&appcateid=29&appcatename=动物";



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
        eval {
            $tree = HTML::TreeBuilder->new; # empty tree
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
                print FEED "http://mm.10086.cn".$_->attr('href');
            }

        
        };
        if($@){
            die "fail to extract Hiapk feeder url: $@";
        }
    }
}
close(FEED);



