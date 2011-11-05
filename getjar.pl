#*****************************************************************************
# *     Program Title: getjar.pl
# *    
# *     Description: html parser
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
use warnings;

BEGIN{
    unshift(@INC, $1) if ($0=~m/(.+)\//);
}
use strict;
use utf8;
use warnings;
use HTML::TreeBuilder;
use Carp ;
use File::Path;
use URI::URL;
use IO::File;
use English;
use Encode qw( encode );
use File::Path;
use Digest::MD5 qw(md5_hex);

use HTTP::Status;
use HTTP::Date;
use HTTP::Request;
use HTTP::Cookies;
use LWP::UserAgent;
use LWP::Simple;

BEGIN{
    unless( $^O =~ m/win/i ){
        require AMMS::Util;
        AMMS::Util->import;
        require AMMS::AppFinder;
        AMMS::AppFinder->import;
        require AMMS::Downloader;
        AMMS::Downloader->import;
        require AMMS::NewAppExtractor;
        AMMS::NewAppExtractor->import;
        require AMMS::UpdatedAppExtractor;
        AMMS::UpdatedAppExtractor->import;
        require AMMS::DBHelper;
        AMMS::DBHelper->import;
    }       
}

# Export function for test
require Exporter;
our @ISA     = qw(Exporter);
our @EXPORT_OK  = qw(
    extract_page_list 
    extract_app_from_feeder 
    extract_app_info
);

#my $mobile_agent = 'Mozilla/5.0 (Linux; U; Android 2.2; en-us; Nexus One Build/FRF91) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1';
my $mobile_agent = 
        'Mozilla/5.0 (Linux; U; Android 2.1-update1; en-us; sdk Build/ECLAIR)'
        .'AppleWebKit/530.17 (KHTML, like Gecko) Version/4.0 Mobile Safari/530.17';
my $web_agent = 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.2 (KHTML, like Gecko)'
    .'Chrome/15.0.874.81 Safari/535.2';
my $mobile_base_url = 'http://client.getjar.com';
my $web_base_url = 'http://www.getjar.com';
my $download_base_url = 'http://download.getjar.com';
my $set_device_url =
    'http://www.getjar.com/set-user-device/?udvsName=android-os&udvsId=15103';
my $cookie_file = 'getjar_cookie.txt';

my $task_type   = $ARGV[0];
my $task_id     = $ARGV[1];
my $conf_file   = $ARGV[2];

my $market      = 'www.getjar.com';
my $url_base    = 'http://www.getjar.com';
my $logger = new AMMS::Config;
my $log = sub {
    my $level = shift;
    my $msg = shift;
    $logger->getAttribute('LOGGER')->$level($msg);
};


my $tree;
my $usage =<<EOF;
==================================================
$0 task_type task_id conf_file
for example:
    $0 find_app     10 /root/crawler/default.cfg
    $0 new_app      158 /root/crawler/default.cfg
    $0 update_app   168 /root/crawler/default.cfg
--------------------------------------------------
explain:
    task_type   - task type which like as 'find_app' 'new_app' 'update_app'
    task_id     - task_id number,you can get it from task_detail table
    conf_file   - the configure file of crawler,default is /root/crawler/default.cfg
==================================================
EOF
my $dbhelper= new AMMS::DBHelper;
my $dbi = $dbhelper->connect_db;

our %category_mapping=(
    'education' => 5, #Education
    'reference-education' => 5, # Education
    'language-education' => 5,  # Education
    'more-education' => 5,      # Education
    'social-and-messaging' => '400,18', #Chat & Instant Messaging,Social Networking
    'email-social-and-messaging' => 401,# E-Mail Clients
    'sms-and-im-social-and-messaging' => 400, # Chat & Instant Messaging,
    'social-networks-social-and-messaging' => 18, #Social Networking 
    'more-social' => 18,# Social Networking
    'entertainment' => 6,# Entertainment
    'book-entertainment' => 6,#Entertainment
    'video-entertainment' => 6,# Entertainment
    'magazine-entertainment' => 6, #Entertainment
    'movies-entertainment' => 6, # Entertainment
    'more-entertainment' => 6, # Entertainment
    'finance' => 2, # Business & Economy     
    'banking-finance' => 200, # Banking
    'quotes-finance' => 201, # Quotes
    'news-finance' => 2, #Business &Economy
    'tools-finance' => 2,#Business & Economy
    'more-finance' => 2, #Business & Economy
    'food' => 19, # Lifestyle
    'recipes-food' => 19,#Lifestyle
    'restaurants-food' => 19, #Lifestyle
    'more-food' => 19, #Lifestyle
    'all-games' => 8, # Games
    '3d-games' => 8, # Games
    'action-games' => 823, #Action Game
    'arcade-games' => 801, #Arcade Game
    'adventure-games' => 800, # Adventure Game
    'board-games' => 802, #Board Game
    'brain-training-games' => 8, #Games
    'card-and-casino-games' => '803,804', # Card Game Casino Game
    'multiplayer-games' => '824', # Multiplayer
    'puzzle-and-strategy-games' => 810, #Puzzle
    'sports-games' => 814, #Sports 
    'more-games' => 8, # Games
    'health' => 9,# Health & Fitness
    'fitness-health' => 901, # Fitness
    'medicine-health' => 9, #Health & Fitness
    'nutrition-health' => 900, # Nutition
    'more-health' => 9, # Health & Fitness
    'search' => 2211,#Search
    'lifestyle' => 19, #LifeStyle
    'celebrities-lifestyle' => 1902,# Celebrites
    'dating-lifestyle' => 1903, # Dating
    'local-events-lifestyle' => 1904, # Local Events
    'more-lifestyle' => 19, # Lifestyle
    'maps' => 2105, #Map
    'music' => 7, # Multimedia
    'concerts-music' => 7,#Multimedia
    'radio-music' => 712,# Radio
    'ringtone-music' => 1202,#Ringtones
    'music-players-music' => 714,# Music Players
    'music-news-music' => 7,# Multimedia
    'more-music' => 7,# Multimedia
    'news-and-weather' => '14,24', #  News & Magazines, Weather
    'local-news-news-and-weather' => '1400',# Local News ,Weather
    'national-news-news-and-weather' => '1401',#National News ,Weather
    'world-news-news-and-weather' => '1402', # World News
    'weather-news-and-weather' => 24,#Weather
    'more-news' => 14,# News & Magazines
    'photos' => 15,# Photography
    'view-and-edit-photos' => '1502,1505',#Editors and Viewers
    'save-and-share-photos' => 15,#Photography
    'more-photos' => 15,# Photography
    'productivity' => 16,# Productivity
    'address-book-productivity' => 16, # Productivity
    'backup-productivity' => 16,#Productivity
    'browser-productivity' => 16,#Productivity
    'calendar-productivity' => 1605,#Calendar
    'phone-tools-productivity' =>16, #Productivity
    'security-productivity' => 16,# Productivity
    'more-productivity' => 16,#Productivity
    'religion' => 26, # Religion
    'shopping' => 17, # Shopping
    'sports' => 20, # Sports
    'events-sports' => 2001,# Events Sports
    'scores-and-news-sports' => 2002,# scores
    'teams-and-players-sports' => 20,#Sports
    'more-sports' => 20,#Sports
    'travel' => 21, # Travel & Local
    'guides-and-reviews-travel' => 2100,# Guides
    'hotel-travel' => 2103,# Hotel
    'trains-travel' => 21, # Travel & Local
    'car-rental-travel' => 2104,# Car Rental
    'cruises-travel' => 21, # Travel & Local
    'flights-travel' => 21, # Travel & Local
    'taxi-travel' => 21, # Travel & Local
    'more-travel' => 21, # Travel & Local
    'adult' => 28,# Adult 
    'education-adult' => 28,# Adult
    'social-and-messaging-adult' => 28,# Adult
    'entertainment-adult' => 28,# Adult
    'finance-adult' => 28,# Adult
    'food-adult' => 28,# Adult
    'games-adult' => 28,# Adult
    'health-adult' => 28,# Adult
    'search-adult' => 28,# Adult
    'lifestyle-adult' => 28,#Adult
    'maps-adult' => 28,#Adult
    'music-adult' => 28,# Adult
    'news-and-weather-adult' => 28,# Adult
    'photos-adult' => 28,#Adult
    'productivity-adult' => 28,# Adult
    'religion-adult' => 28,# Adult
    'shopping-adult' => 28,# Adult
    'sports-adult' => 28,#Adult
    'travel-adult' => 28,# Adult
    'more-adult' => 28,# Adult
    );

# define a app_info mapping
# because trustgo_category_id is related with official_category
# so i remove it from this mapping
our %app_map_func = (
        author                  => \&get_author, 
        app_name                => \&get_app_name,
        current_version         => \&get_current_version,
        icon                    => \&get_icon,
        price                   => \&get_price,
        system_requirement      => \&get_system_requirement,
        min_os_version          => \&get_min_os_version,
        max_os_version          => \&get_max_os_version,
        resolution              => '',
        last_update             => \&get_last_update,
        size                    => \&get_size,
        official_rating_stars   => \&get_official_rating_stars,
        official_rating_times   => \&get_official_rating_times,
        official_comment_times  => \&get_official_comment_times,
        app_qr                  => \&get_app_qr,
        note                    => '',
        apk_url                 => \&get_apk_url, 
        total_install_times     => \&get_total_install_times,
        description             => \&get_description,
        official_category       => \&get_official_category,
        trustgo_category_id     => '',
        related_app             => \&get_related_app,
        screenshot               => \&get_screenshot,
        permission              => \&get_permission,
        status                  => '',
        category_id             => '',
);
# TODO get apk_url
our @app_info_list = qw(
        apk_url
        author                  
        last_update
        official_comment_times
        official_rating_stars
        app_name
        current_version
        icon                    
        price                   
        total_install_times     
        description             
        screenshot               
        size                    
        trustgo_category_id     
        official_category       
);

our $AUTHOR     = 'unknown';


if( $ARGV[-1] eq 'debug' ){
    &run;
    exit 0;
}


{
    package MyAppFind;
    use base 'AMMS::AppFinder';

    sub get_app_url {
        my $self           = shift;
        my $feeder_id_urls = shift;

        my $downloader = $self->{'DOWNLOADER'};
        my $logger     = $self->{'CONFIG_HANDLE'}->getAttribute('LOGGER');
        my $result     = {};
        my %params;
        FETCH:
        foreach my $id ( keys %{$feeder_id_urls} ) {
            my @pages;

            $result->{$id}->{'status'} = 'fail';
            $downloader->timeout(
                $self->{'CONFIG_HANDLE'}->getAttribute("WebpageDownloadMaxTime")
            );
            my $web_page = $downloader->download( $feeder_id_urls->{$id} );
            if ( not $downloader->is_success ) {
                $result->{$id}->{'status'} = 'invalid'
                  if $downloader->is_not_found;
                $logger->error( 'fail to download webpage '
                      . $feeder_id_urls->{$id}
                      . ',reason:'
                      . $downloader->error_str );
                next;
            }

            utf8::decode($web_page);
            $params{'web_page'} = $web_page;
            $params{'base_url'} = $feeder_id_urls->{$id};
            my $page = $params{'base_url'};
          LOOP: {
                my %apps;
                my $webpage;
              FEED: {
              	    my $check = sub {
              	    	require Digest::MD5;
              	    	my $page_url_md5 = Digest::MD5::md5_hex($page);
              	    	my $sql =<<EOF;
              	    	select status from feed_info 
              	    	where feed_url_md5 = ?
EOF
                        my $sth = $dbi->prepare($sql);
                        $sth->execute($page_url_md5);
                        my $hashref = $sth->fetchrow_hashref;
                        return defined($hashref) ? $hashref->{status} : '';
                    };
                    if( $check->($page) eq 'success' 
                            or 
                        $check->($page) eq 'invaild' 
                    ){
                        $page =~ s/p=(\d+)/'p='.($1+8)/e;
                        $page =~ s/i=(\d+)/'i='.($1+1)/e;
                    	$page .= "&p=8&i=2" if $page =~ m/lang=en$/;
                        redo FEED;
                    }
                    $webpage= $downloader->download($page) ;
                    if ( not $downloader->is_success ) {
                    	$log->( warn => "get page $page failed maybe network reason");
                        if ( $downloader->is_not_found ) {
                            $self->{'DB_HELPER'}
                              ->save_url_from_feeder( $id, $page, 'invalid' );
                        }
                        else {
                            $self->{'DB_HELPER'}
                              ->save_url_from_feeder( $id, $page, 'fail' );
                             next FETCH;
                        }
                    }
                }
                unless ( utf8::decode($webpage) ) {
                    $logger->error("fail to utf8 convert");
                }
                $params{'web_page'} = $webpage;
                $params{'base_url'} = $page;
                $self->invoke_hook_functions( 'extract_app_from_feeder',
                    \%params, \%apps );
                $self->{'DB_HELPER'}
                  ->save_app_into_source( $id, $self->{'MARKET'}, \%apps );
                $self->{'DB_HELPER'}
                  ->save_url_from_feeder( $id, $page, 'success' );

                $params{'next_page_url'} = undef;
                my $ret = $self->invoke_hook_functions( 'extract_page_list', \%params,
                    \@pages );
                $page = $params{'next_page_url'};
                if( $ret eq 'part' ){
                    $self->{'DB_HELPER'}
                        ->save_url_from_feeder( $id, $params{base_url}, 'fail' );
                    next FETCH;
                }
                last LOOP if not defined($page);
                redo LOOP;
            }
            $result->{$id}->{'status'} = 'success';
        }

        $self->{'RESULT'} = $result;
        return 1;
    }

    1;
}

# check args 
unless( $task_type && $task_id && $conf_file ){
    die $usage;
}

# check configure
die "\nplease check config parameter\n" 
    unless init_gloabl_variable( $conf_file );

my $mobile_downloader;
my $android_agent = 'Dalvik/1.1.0 (Linux; U; Android 2.1-update1; sdk Build/ECLAIR)';
my $android_market_ua = new LWP::UserAgent;
$android_market_ua->agent($android_agent);
$android_market_ua->timeout(60);

my $cookie_jar = new HTTP::Cookies(
  file => $cookie_file,
  autosave => 1
);

if( $task_type eq 'find_app' )# find app
{
    my $AppFinder =
      new MyAppFind( 'MARKET' => $market, 'TASK_TYPE' => $task_type );
    $AppFinder->{DOWNLOADER}{USERAGENT}->agent($web_agent);
 	$AppFinder->{DOWNLOADER}{USERAGENT}->cookie_jar($cookie_jar);
    my $res = $AppFinder->{DOWNLOADER}{USERAGENT}->get($set_device_url);
    if( $res->is_success ){
    	print "get cookie success\n";
    }else{
    	die "get cookie failed\n";
    }

#    $cookie_jar->load($cookie_file);

    $AppFinder->{DOWNLOADER}->{USERAGENT}->cookie_jar( $cookie_jar );
    $AppFinder->addHook('extract_page_list', \&extract_page_list);
    $AppFinder->addHook('extract_app_from_feeder', \&extract_app_from_feeder);
    $AppFinder->run($task_id);
}
elsif( $task_type eq 'new_app' )##download new app info and apk
{
	# set a mobile downloader to get apk download html
	$mobile_downloader = new AMMS::Downloader;
	$mobile_downloader->{USERAGENT}->agent( $mobile_agent );
    
    # defined a new app ua add cookie jar
    my $NewAppExtractor= new AMMS::NewAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $NewAppExtractor->{DOWNLOADER}{USERAGENT}->agent($web_agent);
 	$NewAppExtractor->{DOWNLOADER}{USERAGENT}->cookie_jar($cookie_jar);
    my $res = $NewAppExtractor->{DOWNLOADER}{USERAGENT}->get($set_device_url);

    if( $res->is_success ){
    	print "get cookie success\n";
    }else{
    	die "get cookie failed\n";
    }

 	$NewAppExtractor->{DOWNLOADER}{USERAGENT}->cookie_jar($cookie_jar);
    $NewAppExtractor->addHook('extract_app_info', \&extract_app_info);
    $NewAppExtractor->addHook('download_app_apk',\&download_app_apk);
    $NewAppExtractor->run($task_id);
}
elsif( $task_type eq 'update_app' )##download updated app info and apk
{
	# set a mobile downloader to get apk download html
	$mobile_downloader = new AMMS::Downloader;
	$mobile_downloader->{USERAGENT}->agent( $mobile_agent );

    my $UpdatedAppExtractor= new AMMS::UpdatedAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $UpdatedAppExtractor->{DOWNLOADER}{USERAGENT}->agent($web_agent);
 	$UpdatedAppExtractor->{DOWNLOADER}{USERAGENT}->cookie_jar($cookie_jar);
    my $res = $UpdatedAppExtractor->{DOWNLOADER}{USERAGENT}->get($set_device_url);

    if( $res->is_success ){
    	print "get cookie success\n";
    }else{
    	die "get cookie failed\n";
    }
    # load cookie
    $UpdatedAppExtractor->{DOWNLOADER}->{USERAGENT}->cookie_jar( $cookie_jar );

    $UpdatedAppExtractor->addHook('continue-test',\&continue_test );
    $UpdatedAppExtractor->addHook('extract_app_info', \&extract_app_info);
    $UpdatedAppExtractor->addHook('download_app_apk',\&download_app_apk);

    $UpdatedAppExtractor->run($task_id);
}

sub continue_test{
   my $self        = shift; 
   my $app_info    = shift;
#    $self->{'TOP_DIR'} = $self->{'CONFIG_HANDLE'}->getAttribute( 'TempFolder' );
   my $bak_dir=
       $self->{'CONFIG_HANDLE'}->getAttribute('BackupDir')
       .'/'.get_app_dir(
               $self->getAttribute('MARKET'),
               $app_info->{app_url_md5}
       );

   my $desc_file = $bak_dir."/description/".$self->{'MARKET_INFO'}->{'language'};
   use FileHandle;
   my $fh ;
   my $old_desc;
   eval{
        $old_desc = do { 
             local $/;
             $fh = new FileHandle($desc_file)||die "not exists $desc_file";
             <$fh>
        };
   };
   if($@){
       return 1;
   }
   if( $old_desc eq $app_info->{description} ){
       return 1
   }
   return 0
}

sub get_page_list{
    my $html        = shift;
    my $page_mark   = shift;
    my $pages       = shift;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    $tree->delete;
}

sub trim_url{
    my $url = shift;
    $url =~ s#/$##;
    return $url;
}

sub extract_page_list{
    # accept args ref from outside
    my $worker	= shift;
    my $hook	= shift;
    my $params  = shift;
    my $pages	= shift;

    print "run extract_page_list  from $params->{base_url} \n";
    # create a html tree and parse
    my $web = $params->{web_page};
    if( $web !~ m{</html>} ){
        $params->{next_page_url} = undef;
        return 'part'
    }
    eval{
        my $tree = new HTML::TreeBuilder;
        $tree->parse($web);
        my $page;
        if( my @nodes = (
                $tree->look_down( class => 'more_bar' ) 
              or $tree->look_down( id => 'row_right_arrow' )
            )
        ){
            my $page = $nodes[0]->find_by_tag_name('a')->attr('href');
            if( my %hash = $page =~ m/(?<=(?:[\?]|&))(\w+?)=(.+?)(?=(?:&|$))/g ){
                $page =~ s/(?:\?|&)$_=$hash{$_}//g foreach ( 'sid','lvt');
                $page =~ s/&o=top//g;
                $page =~ s/&o=new//g;
                $params->{next_page_url} = $url_base.$page;
            }
        }
    };
    return 1;
}


sub extract_app_from_feeder{
    # accept args ref from outside
    my $worker	= shift;
    my $hook	= shift;
    my $params  = shift;
    my $apps    = shift;
   
    return 0 unless ref( $params) eq 'HASH' ;
    return 0 unless ref(  $apps ) eq 'HASH' ;
    return 0 unless exists $params->{web_page};
    
    print "run extract_app_from_feeder : $params->{base_url}\n";
    my $category;
    eval{
        my $html = $params->{web_page};
        my $tree = new HTML::TreeBuilder;
        $tree->parse($html);
        $tree->eof;
        # mobile-reference-education-applications
        if( $params->{base_url} =~ m/mobile-(.+?)-applications/
            or 
            $params->{base_url} =~ m/mobile-(.+?-games)/
        ){
        	$category = $1;
        }

        my $link_regex = qr{
            mobile/(\d+)/(.+?)-for- #match appliacation ID
            (.+?)/                  #match device type
            .+?lang=(\w+)           #match language
        }sx;
        my @nodes = $tree->look_down( class => 'free_app_name' );
        return 0 unless @nodes;
=pod
<a class="free_app_name" href="/mobile/237391/muffin-knight-for-google-nexus-one/?ref=0&amp;lvt=1319717791&amp;sid=db9aejv6mjxm5r5w&amp;c=1tx0o8m55dauhsfk13&amp;f=39059456&amp;lang=en">Muffin Knight</a>
=cut
        foreach my $node( @nodes ){
            next unless ref($node);
            if( $node->find_by_tag_name('a')->attr('href') 
                    =~ m/$link_regex/o
            ){
                my ( $app_id,$app_name,$device,$lang ) = ( $1,$2,$3,$4 );
                my $app_url 
                    = $web_base_url."/mobile/".$app_id."/".$app_name
                    . "-for-".$device;
                $apps->{$1} = $app_url;
                save_extra_info( md5_hex($app_url),$category );
            }
        }

    };
    if($@){
        $apps = {};
        return 0
    }
    return 0 unless scalar(keys %{ $apps } );

    return 1;
}

sub get_author{
    return $AUTHOR;
}

sub get_trustgo_category_id{
    my $name = shift;
    return  $category_mapping{ shift @_ };
}

sub get_official_comment_times{
    my $html  = shift;
    my $node = $tree->look_down( class => "product_pref_comment_block" );
    return 0 unless ref $node;
    return $node->find_by_attribute( id => 'product_count_label' )->as_text;
}

sub get_icon{
    my $html = shift;
    my $app_info = shift;

    my @nodes = $tree->look_down( id => 'product_image_holder' );
    return unless @nodes;

    return ( $nodes[0]->find_by_tag_name('img') )[0]->attr('src');
}

sub get_app_name{
    my $html = shift;
    my $app_info = shift;
    
    my @nodes = $tree->look_down( id => 'product_title');
    return unless @nodes;
    my $app_name = [$nodes[0]->find_by_tag_name('a')]->[0]->as_text;
    $log->( warn => "can't find app_name" ) if $@;
    return $app_name;
}

sub get_price{ 
    my $html = shift;
    my $node = $tree->look_down( id => 'product_license_type' );
    return 0 unless ref($node);
    my $text = $node->as_text;
    if( $text =~ m/free/i ){
        return 0;
    }else{
        if( $text =~ m/\$([\d\.]+)/ ){
            return "USD:".$1;
        }
    }
    
    return 0;
}

sub get_description{
    my $html = shift;
    my $app_info = shift;

    my @nodes = $tree->look_down( class => 'product_desciption');
    return unless @nodes;

    my $desc = $nodes[0]->as_HTML;
    $desc =~ s/<div.+?>//g;
    $desc =~ s/<\/div>//g;
    
    return  AMMS::Util::del_inline_elements($desc);
}

sub get_size{
    return  0;
}

sub get_total_install_times{
    my $html = shift;
    my $app_info = shift;
    
    my @nodes = $tree->look_down( id => 'product_dl_count' );
    return unless @nodes;

    my $install_times = $nodes[0]->as_text;
    $install_times =~ m/([\d,]+)/;
    $install_times = $1;
    $install_times =~ s/,//g;
    return $install_times;
}

sub get_last_update{
    return "0000-00-00";
}
sub get_cookie{
    my $cookie_file = 'getjar_cookie.txt';
    my $set_url = $set_device_url;
    my $ua = new LWP::UserAgent;
    $ua->timeout(60);
    $ua->agent($web_agent);

    my $cookie_jar = HTTP::Cookies->new(
        file        => $cookie_file,
        autosave    => 1,
    );

    my $device_name = 'google-nexus-s';
    my $id = 15440;
    
    $ua->cookie_jar($cookie_jar);
    $ua->max_redirect(0);
    my $res = $ua->get( $set_url );
    if( $res->is_success ){
        print "get cookie success!\n";
        return 1
    }else{
        die "can't get cookie for getjar";
    }
}


sub get_apk_url{
    my $html = shift;
    my $app_info = shift;
=pod
    my $link_regex = qr{
            mobile/(\d+)/(.+?)-for- #match appliacation ID
            (.+?os)                  #match device type
    }sx;
=cut
    my $phone_html ;
 
    my $app_url = $app_info->{app_url};
=pod
    if( $app_url =~ m{$link_regex}o ){
    	my ( $app_id,$app_name,$device ) = ( $1,$2,$3 );
    	my $app_url 
    	    = $mobile_base_url
    	    . "/mobile/".$app_id."/"
    	    . $app_name
    	    . "-for-".$device
    	    . "/?lang=en&gjclnt=1";

        my $m_page = $mobile_downloader->download( $app_url );
        $log->( error => "download phone apk_url $app_url failed" )
            unless $mobile_downloader->is_success;
        $phone_html = decode_utf8( $m_page );

        if( $phone_html =~ m/downloadUrl\s*=\s*"(.+?)\?/s ){
        	return $1;
        }
        my $node = $tree->look_down( id => 'form_product_page' );
        return unless ref $node;
        return $node->attr('action');
        
        $log->( warn => "$app_url get apk_url failed,perhaps html is part" );
        $log->( warn => "save apk html \n $phone_html\n");
        return
    }
=cut
    my $node = $tree->look_down( id => 'form_product_page' );
    return unless ref($node);
    return $node->attr('action') ? $node->attr('action') : undef;
}

sub get_official_rating_stars{
    my $html  = shift;
    my $app_info = shift;
    my $like_node = $tree->look_down( class => "product_pref_like_block" );
    my $like_num =  $like_node->find_by_attribute( id => 'product_count_label' )->as_text;
    my $dis_node = $tree->look_down( class => 'product_pref_dislike_block' );
    my $dis_num = $dis_node->find_by_attribute( id =>
            'product_count_label')->as_text;
    $app_info->{official_rating_times} = $like_num+$dis_num;
    return 0 if $like_num == 0;
    return $like_num/($like_num+$dis_num)*10/2
}

sub kb_m{
    my $size = shift;

    # MB -> KB 
    $size = $1*1024 if( $size =~ s/([\d\.]+)(.*MB.*)/$1/i );
    $size = $1  if( $size =~ s/([\d\.]+)(.*KB.*)/$1/i );

    # return byte
    return int($size*1024);
}

sub get_official_category{
    my $html = shift;
    my $app_info = shift;
    
    if( 
    	my $hashref = $dbhelper->get_extra_info(
    	    md5_hex( $app_info->{app_url} ) 
        )
    ){
    	return $hashref->{category};
    }

    $log->( warn => "not find category from app_extra_info " );
}

#-------------------------------------------------------------

sub get_current_version{
    return  0
}

sub get_app_qr{
	return 
}
sub get_screenshot{
    my $html = shift;
    my $app_info = shift;

    my @nodes = $tree->look_down( class => 'thumbs' );
    return unless @nodes;

    my @tags = $nodes[0]->find_by_tag_name('img');
    $log->( warn => "can't find tags" ) if $@;
    return [ map{ $_->attr('src') } @tags ];
}

#-------------------------------------------------------------
sub get_permission{
    my $html = shift;

    # the list needed to return 
    my $permission = [];
    return 
}

sub get_related_app{
    my $html = shift;
    my $app_info = shift;
    my $re_apps = [];
    my @nodes = $tree->look_down( class => 'ppd_outer' );
    return unless @nodes;

    foreach my $node( @nodes ){
    	next unless ref( $node );
    	my $link = $node->attr('on_click');
    	if( $link =~ m{(/mobile.+?)/\?} ){
        	push @$re_apps,$web_base_url.$1
        }
    }
    return  $re_apps;
}

sub extract_app_info
{
    # accept args ref from outside
    my $worker	 = shift;
    my $hook	 = shift;
    my $html     = shift;
    my $app_info = shift;
    
    $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    $tree->eof;
    # create a html tree and parse
    print "extract_app_info  run \n";

    eval{
        # TODO get note 'not find'
        {
            no strict 'refs';
            foreach my $meta( @app_info_list ){
                # dymic function invoke
                # 'get_author' => sub get_author
                # 'get_price'  => sub get_price
                next unless ref($app_map_func{$meta}) eq 'CODE';
                my $ret = &{ $app_map_func{$meta} }($html,$app_info);
                if( defined($ret) ){
                    $app_info->{$meta} = $ret;
                }
            }

            if (defined($category_mapping{$app_info->{official_category}})){
                $app_info->{trustgo_category_id} 
                    =$category_mapping{$app_info->{official_category}};
            }else{
                my $str="Out of TrustGo category:".$app_info->{app_url_md5};
                open(OUT,">>/root/outofcat.txt");
                print OUT "$str\n";
                close(OUT);
                die "Out of Category";
            }
        }
    };
#    use Data::Dumper;
#    print Dumper $app_info;
    $tree->delete;

    $app_info->{status} = 'success';
    if($@){
        $app_info->{status} = 'fail';
    }

    return scalar %{$app_info};
}

sub get_content{
    my $html = shift;
    use FileHandle;
    use open ':utf8';
    my $content = do{
        local $/='</html>';
        my $fh = new FileHandle($html)||die $@;
        <$fh>
    };

    return $content;
}

sub get_system_requirement{
    my $html = shift;

   return
}

sub get_min_os_version{
    {
        no strict 'refs';
        my $min_os_version = ${ __PACKAGE__."::"."min_os_version" };
        return $min_os_version || undef;
    }
}

sub get_max_os_version{
    {
        no strict 'refs';
        my $max_os_version = ${ __PACKAGE__."::"."max_os_version" };
        return $max_os_version || undef;
    }
}

sub get_official_rating_times{
    my $html = shift;
   
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    # <span class="ratinglabel">135个评分：</span>
    my @nodes = $tree->look_down( class => 'ratinglabel' );
    return unless @nodes;

}

sub run{
    use LWP;
    use LWP::UserAgent;
    use Encode;
    use Data::Dumper;
    my $web_agent = 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.2 (KHTML, like Gecko)'
    .'Chrome/15.0.874.81 Safari/535.2';
    
    my $feeder_url =
    'http://www.getjar.com/mobile-language-education-applications-for-google-nexus-one/?o=top&p=8&i=2';
    my $cookie_jar = HTTP::Cookies->new(
         file => 'getjar_cookie.txt'
    );
    $cookie_jar->load($cookie_file);

    my $mobile_agent = 
        'Mozilla/5.0 (Linux; U; Android 2.1-update1; en-us; sdk Build/ECLAIR)'
        .'AppleWebKit/530.17 (KHTML, like Gecko) Version/4.0 Mobile Safari/530.17';
    my $ua = new LWP::UserAgent;
    $ua->agent($web_agent);
    $ua->cookie_jar( $cookie_jar );
    $ua->timeout(60);
#    my $cookie_jar = get_cookie();
    Extract_PAGE: 
    my $page_url =
        'http://www.getjar.com/mobile-all-games-for-google-nexus-one/?lang=en&o=top';
    my $feeder_res = $ua->get($feeder_url);
    if( $feeder_res->is_success ){
        use FileHandle;
        my $fh = new FileHandle(">th.html")||die $@;
        print $fh $feeder_res->content;
        extract_page_list( 
            undef,
            undef,
            { 
                web_page => Encode::decode_utf8($feeder_res->content)
            },
            []
        );
    }

    my $app_hashref = {};
    my $page_res = $ua->get($page_url);
    if( $page_res->is_success ){
        my $page = Encode::decode_utf8($page_res->content);
        extract_app_from_feeder(
            undef,
            undef,
            {
                web_page => $page,
            },
            $app_hashref
        );
        print Dumper $app_hashref;
    }
    $ua->agent($mobile_agent);
    my $app_info;
    foreach my $app_id( keys %$app_hashref ){
        my $app_res = $ua->get( $app_hashref->{$app_id} );
        if( $app_res->is_success ){
            my $content = Encode::decode_utf8($app_res->content);
            extract_app_info( undef,undef,$content,$app_info );
        }else{
            die "can't get app_url\n"
        }
    }


}

sub save_extra_info{
    my $app_url_md5 = shift;
    my $category= shift;

    $dbhelper->save_extra_info( $app_url_md5,{ category => $category } );
}

sub download_app_apk 
{
    my $self    = shift;
    my $hook_name  = shift;
    my $apk_info= shift;

    my $apk_file;
    my $md5 =   $apk_info->{'app_url_md5'};
    my $apk_dir= $self->{'TOP_DIR'}.'/'. get_app_dir( $self->getAttribute('MARKET'),$md5).'/apk';

    my $downloader  = $mobile_downloader;

    if( 
    	exists $apk_info->{apk_url}
    	    &&
        $apk_info->{apk_url} 
            &&
        $apk_info->{apk_url} !~ m/apk$/ 
    ){
    	my $res = $android_market_ua->simple_request( 
    	    HTTP::Request->new( GET => $apk_info->{apk_url} )
        );
        if( $res->is_redirect ){
    	    my $hashref = $self->{DB_HELPER}->get_extra_info($md5);
    	    if( defined $hashref ){
            	$hashref->{apk_redirect} = 
            	    substr( 
            	        $res->header('location'),
            	        index($res->header('location'),'id=')+length('id='),
            	    );
            	$self->{DB_HELPER}->save_extra_info(
            	    $md5 => $hashref 
                );
                $apk_info->{app_package_name} = $hashref->{apk_redirect};
    	        $apk_info->{status} = 'success';
            	return 1
            }
        }
        $apk_info->{status} = 'fail';
        return 0
    }
    if( $apk_info->{price} ne '0' ){
        $apk_info->{'status'}='paid';
        return 1;
    }
    eval { 
        rmtree($apk_dir) if -e $apk_dir;
        mkpath($apk_dir);
    };
    if ( $@ )
    {
        $self->{ 'LOGGER'}->error( sprintf("fail to create directory,App ID:%d,Error: %s",
                                    $md5,$EVAL_ERROR)
                                 );
        $apk_info->{'status'}='fail';
        return 0;
    }
    
    my $timeout = $self->{'CONFIG_HANDLE'}->getAttribute('ApkDownloadMaxTime');
    $timeout += int($apk_info->{size}/1024) if defined $apk_info->{size};
    $downloader->timeout($timeout);
    $apk_file=$downloader->download_to_disk($apk_info->{'apk_url'},$apk_dir,undef);

    if (!$downloader->is_success)
    {
        $apk_info->{'status'}='fail';
        return 0;
    }

    unless (check_apk_validity("$apk_dir/$apk_file") ){
        $apk_info->{'status'}='fail';
        return 0;
    }
 
    $apk_info->{apk_md5}=file_md5("$apk_dir/$apk_file");
    my $unique_name=$apk_info->{apk_md5}."__".$apk_file;


    rename("$apk_dir/$apk_file","$apk_dir/$unique_name");
 
    $apk_info->{size}=(stat("$apk_dir/$unique_name"))[7] if( $apk_info->{size}==0 );

    $apk_info->{'status'}='success';
    $apk_info->{'app_unique_name'} = $unique_name;

    return 1;
}


1;
#&run;

__END__



