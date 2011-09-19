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
my @category_app_list= qw(
);

my @metas = qw(
    author 
    app_name 
    official_category 
    current_version 
    size 
    price 
    description
    apk_url 
    last_update 
    total_install_times 
    app_qr
    permission
    screenshot
    official_rating_stars
    related_app
    icon
    app_url
    trustgo_category_id
    app_url_md5
);

my %meta_rule = (
    author                  => '安丰网',
    app_name                => '\S+',
    official_rating_stars   => '\d+',
    current_version         => '\d.*',
    size                    => '\d+',
    price                   => '\d+',
    description             => '.*',
    apk_url                 => '.*apk$',
    last_update             => '\d+-\d+-\d+',
    total_install_times     => '\d+',
    app_qr                  => 'http:.*img',
    permission              => '.*',
    screenshot              => 'http.*img',
    official_category       => '\S+',
    related_app             => '.*\d+\.html',
    icon                    => '.*png',
    app_url                 => '.*html',
);

my @content_list = ();

# test category list
use LWP::Simple;
use FileHandle;
#my $wrong = get('www.sina.com.cn');
my $wrong = '<html></html>';

# get html string
for(@category_app_list){
    my $content;
    if( $_ =~ m/(\d+_\d+\.html)$/){
        my $file = $1;
        unless ( -e $file){
 	   	is( defined( $content = LWP::Simple::getstore($_,$file) ),1," lwp simple get html content from '$_' ") ;
        }
    	push @content_list,get_content($file);
    }
}

for( my $i = 0;$i < @category_app_list; $i++){
    my $url = $category_app_list[$i];
    my $content = $content_list[$i];

    &test_extract_app_info( $url,$content);
}


sub test_extract_app_info{
    my $url = shift;
    my $page = decode_utf8(shift);
    my $app_info = {};
    # testing
    is(
        &extract_app_info( undef,undef,$page,$app_info ),
        1,
        "extract app from feeder '$url' get 'Dumper $app_info' "
    );
    for(@metas){
        is( exists $app_info->{$_}, 1, "exists '$_' in app_info");
        is( defined $app_info->{$_},1, "defined '$_' with '$app_info->{$_}' in app_info");
        is( $_ =~ m/$meta_rule{$_}/,1, "'$_' => '$app_info->{$_}' match app_info rule '$meta_rule{$_}'");
    }

    # test invaild parameters
    is(
        &extract_app_info( undef,undef,$page,undef),
        0,
        'get app_info with undef app_info'
    );

    is(
        &extract_app_info( undef,undef,undef,$app_info),
        0,
        'get app_info with undef html'
    );
    is(
        &extract_app_info( undef,undef,undef,undef),
        0,
        'get app_info with undef app_info,html'
    );
}

