#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use Encode;
use FileHandle;
use Carp;
use Test::More 'no_plan';
use lib '/root/crawler';
use DataCheck;
use Getopt::Long;

#
my $test_func;
my $pl;
my $market_id;
my $usage =<<EOF;
    $0 -func extract_page_list
EOF
#my $data   = "file.dat";
#my $length = 24;
#my $verbose;
$result = GetOptions (
    "func:s" => \$test_func
    "pl:s"   => \$pl
);

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
    require_ok( $pl );
}

TEST_EXTRACT_FUNC:
my @category_list= qw(
http://anfone.com/sort/1.html
http://anfone.com/sort/2.html
);


my %page_mapping = qw(
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
use Encode;
print "test extract_page_list";
my $page_info ={};
my @app_links = [];
for( my $i = 0 ; $i < @category_list; $i++ ){
    $page_info->{$category_list[$i]} = [];
    my $pages = [];
    $content_list[$i] = decode_utf8($content_list[$i]);
    is( 
        &extract_page_list( undef,undef,{'web_page'=>$content_list[$i]},$pages ),
        1,
        "test extracet pagelist parse $category_list[$i],and get pages"
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


