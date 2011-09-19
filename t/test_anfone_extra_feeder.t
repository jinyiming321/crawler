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
    require_ok( 'anfone_for_test.pl' );
}

TEST_EXTRACT_FEEDER_FUNC:
my @category_feeder_list= qw(
    http://anfone.com/sort/1_10.html
    http://anfone.com/sort/1_13.html
    http://anfone.com/sort/2_3.html
    http://anfone.com/sort/2_4.html
);

my @content_list = ();

# test category list
use LWP::Simple;
use FileHandle;
#my $wrong = get('www.sina.com.cn');
my $wrong = '<html></html>';

# get html string
for(@category_feeder_list){
    my $content;
    if( $_ =~ m/(\d+_\d+\.html)$/){
        my $file = $1;
        unless ( -e $file){
 	   	is( defined( $content = LWP::Simple::getstore($_,$file) ),1," lwp simple get html content from '$_' ") ;
        }
    	push @content_list,get_content($file);
    }
}

for( my $i = 0;$i < @category_feeder_list; $i++){
    my $url = $category_feeder_list[$i];
    my $content = $content_list[$i];

    &test_extract_feeder_list( $url,$content,);
}

sub test_extract_feeder_list{
    my $url = shift;
    my $page = shift;
    my $params  = { web_page => $page};
    my $app_list = {};
    # testing
    is(
        &extract_app_from_feeder( undef,undef,$params,$app_list ),
        1,
        "extract app from feeder '$url' get '$app_list'"
    );
#    &test_link_vaild( $_ ) foreach ( keys %{$app_list} );
    for( keys %$app_list){
        &test_link_vaild($app_list->{$_});
    }
    is(
        &extract_app_from_feeder( undef,undef,$wrong,$app_list ),
        0,
        "extract app from feeder with wrong html get '$app_list'"
    );

    is(
        &extract_app_from_feeder( undef,undef,$params,undef),
        0,
        "extract app from feeder with undef apps_list"
    );
    is(
        &extract_app_from_feeder( undef,undef,undef,$app_list),
        0,
        "extract app from feeder with undef html"
    );
}

sub test_link_vaild{
    my $link = shift;
    is( defined( LWP::Simple::get($link) ),1," get '$link' link vaild test " );
}

