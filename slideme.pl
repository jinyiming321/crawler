#*****************************************************************************
# *     Program Title: slideme.pl
# *    
# *     Description: 
# *         1) extract page list from feeder url
# *         2) extract app from every page url
# *         3) extract app information from app_url
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
use Data::Dumper;


BEGIN{
    unshift(@INC, $1) if ($0=~m/(.+)\//);
}
use utf8;
use HTML::TreeBuilder;
use Carp ;
use File::Path;
use URI::URL;
use IO::File;
use English;
use Encode qw( encode );
use File::Path;
use Digest::MD5 qw(md5_hex);

use LWP::Simple;

BEGIN{
    unless( $^O =~ m/win/i ){
        require AMMS::Util;
        require AMMS::AppFinder;
        require AMMS::Downloader;
        require AMMS::NewAppExtractor;
        require AMMS::UpdatedAppExtractor;
        require AMMS::DBHelper;

        AMMS::Util->import;
        AMMS::AppFinder->import;
        AMMS::Downloader->import;
        AMMS::NewAppExtractor->import;
        AMMS::UpdatedAppExtractor->import;
        AMMS::DBHelper->import;
    }       
}

my $DownLoader = new AMMS::Downloader;
# Export function for test
require Exporter;
our @ISA     = qw(Exporter);
our @EXPORT_OK  = qw(
    extract_page_list 
    extract_app_from_feeder 
    extract_app_info
);

my $task_type   = $ARGV[0];
my $task_id     = $ARGV[1];
my $conf_file   = $ARGV[2];

my $market      = 'slideme.org';
my $url_base    = 'http://slideme.org';
my $tree;

my %month_map = (
    'January'   => '01',
    'February'  => '02',
    'March'     => '03',
    'April'     => '04',
    'May'       => '05',
    'June'      => '06',
    'July'      => '07',
    'August'    => '08',
    'September' => '09',
    'October'   => '10',
    'November'  => '11',
    'December'  => '12',
);

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

our %category_mapping=(
    'Fun & Games' => '302,8',
    'E-books' => '1',
    'Entertainment' => '6',
    'Utilities' => '',
    'Educational / Reference' => '1,5',
    'Wallpapers' => '1205',
    'Lifestyle' => '19',
    'Communications' => '4',
    'Productivity' => '16',
    'Health & Fitness' => '9',
    'Music' => '7',
    'Travel' => '21',
    'Other' => '0',
    'Religion' => '26',
    'Location & Maps' => '2105,2106',
    'Social Responsibility' => '18',
    'Home & Hobby' => '19',
    'Developer / Programmer' => '1100',
    'Enterprise' => '2',
    'Collaboration' => '28',
);

my $logger = new AMMS::Config;
my $log = sub {
    my $level = shift;
    my $msg = shift;
    $logger->getAttribute('LOGGER')->$level($msg);
};

my $dbhelper = new AMMS::DBHelper;
my $dbh = $dbhelper->connect_db;

# define a app_info mapping
# because trustgo_category_id is related with official_category
# so i remove it from this mapping
our %app_map_func = (
        author                  => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'submitted' );
            $log->('error' => "can't find author") unless @nodes;
            return 
                ( $nodes[0]->find_by_tag_name('a') )[0]->as_text || 'unknown'
                
        },
        app_name                => sub{
            my $html = shift;
            my $app_info = shift;
            my @nodes = $tree->look_down( class => 'title' );
            unless( @nodes ){
                $log->( 
                    'error',
                    "can't find app_name"
                );
                return
            }
            my $app_name = $nodes[0]->as_text;
            $app_name =~ s/\s+$//g;
            $app_name =~ s/^\s+//g;
            return $app_name;
        },
        current_version         => sub{
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'version' );
            unless( @nodes ){
                $log->(
                    'error',
                    "can't find version"
                );
            }
            if( my $text = $nodes[0]->as_text ){
                $text =~ m/([\d\.]+)/s;
                return $1
            }else{
                return 'unknown'
            }
        },   
        icon                    => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'icon' );
            unless( @nodes ){
                $log->(
                    'error',
                    "can't find icon"
                );
                return
            }
            return $nodes[0]->find_by_tag_name('img')->attr('src');
        },
        screenshot              => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( 
                'class' => 'thickbox'
            );
            unless( @nodes ){
                $log->(
                    'error',
                    "can't find screen"
                );
                return []
            }
            return [ 
                map { $_->attr('href') }
                @nodes
            ]
        },
        system_requirement      =>  undef,
        min_os_version          => sub{
            my ( $html,$app_info ) = ( shift,pop );
            # match regex for system require
            if( $html 
                    =~ m/Minimum Android version:.*?Android\s+((?:\d\.\d){1})/is
            ){
                return $1;
            }
            return
        },
        max_os_version          => sub{
            my ( $html,$app_info ) = ( shift,pop );
            # match regex for system require
            if( $html 
                    =~ m/Target Android version:.*?Android\s+((?:\d\.\d){1})/is
            ){
                return $1;
            }
            return
        },
        resolution              => sub{
            my ( $html,$app_info ) = ( shift,pop );
            # match resolution
            # TODO SURE DPX
            if( $html =~ m/Minimum screen width.+?(\d+).*?dpx/ ){
                return $1;
            }
        },
        last_update             => sub {
            my ( $html,$app_info ) = ( shift,pop );

            # . Updated October 18, 2011
            if( $html =~ m/Updated\s+(\w+)\s+(\d{2}),\s+(\d{4})/s ){
                # return time-format as '2010-10-02'
                return $3.'-'.$month_map{$1}.'-'.$2;
            }
            return '0000-00-00'
        },  
        size                    => sub {0},
        official_rating_stars   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my $rating_stars = () = $html =~ m/class="on"/sg;
            return $rating_stars || '0';
        },
        official_rating_times   => undef,
        app_qr                  => sub{
            my ( $html,$app_info ) = ( shift,pop );
            my $bar = $tree->look_down( class => 'barcode' );
            $log->( error => 'not find qrcode') unless ref $bar;
            return $bar->find_by_tag_name('img')->attr('src');
        },
        note                    => undef,
        apk_url                 => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my $tag;
            my @nodes = $tree->look_down( class => 'download-button');
            unless ( @nodes ){
                @nodes = $tree->look_down( class => 'webbuy-button' );
                return $url_base.$nodes[0]->find_by_tag_name('a')->attr('href');
            }
            # http://slideme.org/mobileapp/download/620320ee-e046-11e0-b731-00505690390e.apk
            return $url_base.$nodes[0]->find_by_tag_name('a')->attr('href');
        },
        total_install_times     => sub {
            my ( $html,$app_info ) = ( shift,pop );
            # <li class="downloads">84</li>
            if( $html =~ m/"downloads">(\d+)</s ){
                return $1;
            }
            return 0
        },
        description             => sub{
            my ( $html,$app_info ) = ( shift,pop );
            my $node = $tree->look_down( class => qr/node node-mobileapp/ );
            $log->(error => 'find desc failed') unless ref($node);
            my $tag = $node->find_by_attribute( class => 'content');
            my $desc = join(
                '',
                map { $_->as_HTML }
                $tag->find_by_tag_name('p')  
            );
            return AMMS::Util::del_inline_elements($desc);
        },
        official_category       => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down(
                _tag  => 'li',
                class => 'category',
            );
            $log->( error => 'not find category of app' ) unless @nodes;
            return $nodes[0]->find_by_tag_name('a')->as_text;
        },
        related_app             => undef,
        price                   => sub {
            my ( $html,$app_info ) = ( shift,pop );

            my $tag = $tree->look_down(
                _tag    => 'div',
                class   => 'price'
            );
            $log->( error => 'not find price of app' ) unless ref($tag);
            if( my $c = $tag->as_text =~ m/Free/ ){
                return 0
            }
            elsif( $c =~ m/\$([\d\.]+)/ ){
                return 'USD:'.$1
            }
            else{
                return 0
            }
        },
        permission              => sub{
            my ( $html,$app_info ) = ( shift,pop );

            my $node = $tree->look_down( 
                _tag  => 'div',
                class => qr/field-field-uses-permission/,
            );
            $log->( error => 'not find permission') and return unless ref $node;

            # Requires permissions: 
            my $permission = $node->as_text;
            my @list = 
                grep {/\w/}
                map{  (my $temp = $_ )=~ s/^\s+//g; $temp }
                split (/\s+Requires permissions:/,$node->as_text);
            return \@list;

        },
        category_id             => undef,
);


our $AUTHOR     = 'unknown';
if( $ARGV[-1] eq 'debug' ){
    &run;
    exit 0;
}

# check args 
unless( $task_type && $task_id && $conf_file ){
    die $usage;
}

# check configure
die "\nplease check config parameter\n" 
    unless init_gloabl_variable( $conf_file );

if( $task_type eq 'find_app' )##find new android app
{
    my $AppFinder   = new AMMS::AppFinder('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $AppFinder->addHook('extract_page_list', \&extract_page_list);
    $AppFinder->addHook('extract_app_from_feeder', \&extract_app_from_feeder);
    $AppFinder->run($task_id);
}
elsif( $task_type eq 'new_app' )##download new app info and apk
{
    my $NewAppExtractor= new AMMS::NewAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    # max_redirect
    #$AppFinder->{DOWNLOADER}->{USERAGENT}->default_header( cookie => $header );
    $NewAppExtractor->addHook('extract_app_info', \&extract_app_info);
    $NewAppExtractor->run($task_id);
}
elsif( $task_type eq 'update_app' )##download updated app info and apk
{
    my $UpdatedAppExtractor= new AMMS::UpdatedAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $UpdatedAppExtractor->addHook('extract_app_info', \&extract_app_info);
    $UpdatedAppExtractor->run($task_id);
}

sub extract_page_list{
    # accept args ref from outside
    my $worker	= shift;
    my $hook	= shift;
    my $params  = shift;
    my $pages	= shift;

    my $total_page;

    my $tree = new HTML::TreeBuilder;
    print "run extract_page_list ............\n";
    eval{
        $tree->parse( $params->{web_page} );
        my $node = $tree->look_down(
                _tag  => 'li',
                class => qr/pager-last/,
        );
        $log->( 'error' => 'find last page failed') unless ref($node);
        my $tag = $node->find_by_tag_name('a');
        my $last_page = $tag->attr('href');
        # http://slideme.org/applications/category/fun-games?page=343
        if( $last_page =~ m/page=(\d+)/ ){
            $total_page = $1;
        }
        $tree->delete;
        return 0 unless $total_page;
        
        @{$pages} =  map { 
                $last_page =~ s/page=(\d+)/'page='.$_/eg;
                $url_base.$last_page
        } ( 0..$total_page);
    };
    if($@){
#        print Dumper $pages;
        $log->(error => $@);
        $tree->delete;
        return 0 unless scalar @$pages
    }
    return 1;
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
            foreach my $meta( keys %app_map_func ){
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
    $tree->delete;

    $app_info->{status} = 'success';
    if($@){
        $log->(error => $@ );
        $app_info->{status} = 'fail';
    }

    return scalar %{$app_info};
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

    print "run extract_app_from_feeder_list ............\n";
    my $tree = new HTML::TreeBuilder;
    eval{
        my $html = $params->{web_page};
        $tree->parse($html);
        $tree->eof;
        # <a href="/node/5288/reviews">Reviews</a>
        my @nodes = $tree->look_down( id => 'applications-overview' );
        $log->( 'error' => 'not find apps id') unless @nodes;

        my @app_list = $nodes[0]->look_down(
                _tag    => 'div',
                class   => qr/node-mobileapp/
        );

        foreach my $app_node( @app_list ){
            my $href = $app_node->find_by_attribute( 
                        class => 'title'
                    )->find_by_tag_name('a')->attr('href');
            my $r = $app_node->find_by_attribute( class => 'reviews'
                    )->find_by_tag_name('a')->attr('href');
            if( $r =~ m{/node/(\d+)} ){
                $apps->{$1} = $url_base.$href;
            }
        }
        $tree->delete;
    };
    if($@){
        $tree->delete;
        $apps = {};
        return 0
    }
    return 0 unless scalar(keys %{ $apps } );

    return 1;
}

sub run{
    use LWP::Simple;
    my $content;
    my $page;
    my $feeder;
    
    my $page_file = 'sliderme_page.html';
    my $feeder_file = 'slideme_feeder.html';
    my $app_info_file = 'sli_content.html';
    getstore( 'http://slideme.org/applications/category/fun-games',$page_file)
            unless -e $page_file;
    getstore(
            'http://slideme.org/applications/category/fun-games?page=0',
            $feeder_file
     ) unless -e $feeder_file;
    getstore( 'http://slideme.org/application/heroes-fight',$app_info_file )
        unless -e $app_info_file;
#    $content = get_content( 'anfone_content.html');
    $feeder = get_content( $page_file );
    $page = get_content( $feeder_file );
    my $info = get_content( $app_info_file );
#    $feeder = get_content('anfone_feeder.html');
    my $app_info = {};
    my $app_list = {};
    my $page_list = [];
    extract_page_list( undef,undef,{ web_page => $feeder},$page_list );
    use Data::Dumper;
    extract_app_from_feeder( undef,undef,{ web_page => $page} ,$app_list);
    $app_info->{app_url} = 'http://slideme.org/application/heroes-fight';
    extract_app_info( undef,undef,$info,$app_info );
    print Dumper $app_info;
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
    use Encode;
    $content = Encode::decode_utf8($content);
    return $content;
}


