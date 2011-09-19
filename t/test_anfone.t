#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use Encode;
use FileHandle;
use Carp;
use Test::More 'no_plan';
use lib '/root/crawler';

=pod
  BEGIN { use_ok( 'Some::Module' ); }
  require_ok( 'Some::Module' );

use HTML::TreeBuilder;
use Carp ;

use AMMS::Util;
use AMMS::AppFinder;
use AMMS::Downloader;
use AMMS::NewAppExtractor;
use AMMS::UpdatedAppExtractor;

=cut

#BEGIN{unshift(@INC, $1) if ($0=~m/(.+)\//);}
BEGIN{
    # test for use module
    use_ok( 'HTML::TreeBuilder');
    use_ok( 'AMMS::Util');
    use_ok( 'AMMS::AppFinder');
    use_ok( 'AMMS::Downloader' );
    use_ok( 'AMMS::NewAppExtractor' );
    use_ok( 'AMMS::UpdatedAppExtractor' );
    use_ok( 'Carp' );
    # test_require
    require_ok( 'anfone.pl' );
}

TEST_EXTRACT_FUNC:
my @category_list= qw(
http://anfone.com/sort/1.html
http://anfone.com/sort/2.html
http://anfone.com/sort/3.html
http://anfone.com/sort/6.html
http://anfone.com/sort/7.html
http://anfone.com/sort/8.html
http://anfone.com/sort/9.html
http://anfone.com/sort/10.html
http://anfone.com/sort/11.html
http://anfone.com/sort/12.html
http://anfone.com/sort/13.html
http://anfone.com/sort/14.html
http://anfone.com/sort/15.html
http://anfone.com/sort/16.html
http://anfone.com/sort/17.html
http://anfone.com/sort/21.html
http://anfone.com/sort/22.html
http://anfone.com/sort/23.html
http://anfone.com/sort/24.html
http://anfone.com/sort/25.html
http://anfone.com/sort/26.html
http://anfone.com/sort/27.html
http://anfone.com/sort/28.html
http://anfone.com/sort/29.html
http://anfone.com/sort/30.html
http://anfone.com/sort/31.html
http://anfone.com/sort/32.html
http://anfone.com/sort/33.html
http://anfone.com/sort/34.html
http://anfone.com/sort/35.html
);

my @content_list = ();

# test category list
use LWP::Simple;
use FileHandle;
#my $wrong = get('www.sina.com.cn');
my $wrong = '<html></html>';
for(@category_list){
    my $content;
    if( $_ =~ m/(\d+\.html)$/){
        my $file = $1;
        unless ( -e $file){
 	   	is( defined( $content = LWP::Simple::getstore($_,$file) ),1," lwp simple get html content from '$_' ") ;
        }
    	push @content_list,get_content($file);
    }
}

# test extract_page_list
print "test extract_page_list";
my $page_info ={};
my @app_links = [];
for( my $i = 0 ; $i < @category_list; $i++ ){
    $page_info->{$category_list[$i]} = [];
    my $pages = {};
    is( 
        &extract_page_list( undef,undef,{'web_page'=>$content_list[$i]},$pages ),
        1,
        "extracet pagelist parse $category_list[$i],and get '$pages' "
    );
    push @{$page_info->{$category_list[$i]} },$pages;
    isnt( @$pages,0,'pagelist num ');
    is( 
        &extract_page_list( undef,undef,{'web_page'=>undef},[]),
        0,
        'undef test args'
    );
    is(
        &extract_page_list( undef,undef,{'web_page',$content_list[$i]},{} ),
        0,
        'pages hashref '
    );
    is( 
        &extract_page_list( undef,undef,{'web_page',$content_list[$i]},''),
        0,
        'pages empty'
    );
    is(
        &extract_page_list( undef,undef,{'web_page',$wrong},[] ),
        0,
        'wrong page for extract_page'
    );
    $pages = [];
    is(
        &get_page_list( $content_list[$i],'pagebar',$pages ),
        undef,
        'get page_list'
    );
}

#print Dumper $page_info;

