#*****************************************************************************
# *     Program Title: handster.pl
# *    
# *     Description: This program has functions as below
# *         1) extract android page_url from handster feeder url.
# *         2) extract android application from every page_url.
# *         3) extrace android app information from android app html.
# *
# *     Author: Yiming Jin
# *    
# *     (C) Copyright 2011-2014 TrustGo Mobile, Inc.
# *     All Rights Reserved.
# *    
# *     This program is an unpublished copyrighted work which is proprietary
# *     to TrustGo Mobile, Inc. and contains confidential information that is not
# *     to be reproduced or disclosed to any other person or entity without
# *     prior written consent from TrustGo Mobile, Inc. in each and every instance.
# *    
# *     WARNING:  Unauthorized reproduction of this program as well as
# *     unauthorized preparation of derivative works based upon the
# *     program or distribution of copies by sale, rental, lease or
# *     lending are violations of federal copyright laws and state trade
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


my $market      = 'www.handster.com';
my $url_base    = 'http://www.handster.com';
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

our %category_mapping=(
    'Business & Finance' => '2',
    'Communication' => '4',
    'eBooks' => '1',
    'Entertainment' => '6',
    'Games' => '8',
    'Action' => '823',
    'Arcade' => '801',
    'Cards' => '803',
    'Sports' => '814',
    'Strategy' => '815',
    'Health' => '9',
    'Languages & Translators' => '106,13',
    'Multimedia' => '7',
    'Organizers' => '16',
    'Ringtones' => '1202',
    'Themes & Skins' => '1203',
    'Aircraft' => '1203',
    'Animals & Nature' => '1203',
    'Animated Today' => '1203',
    'Anime & Cartoons' => '1203',
    'Fine Arts' => '1203',
    'FlashThemes' => '1203',
    'Love' => '1203',
    'Travel & Maps' => '21',
    'Utilities' => '22',
    'Other'     => 0,
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
            my @nodes = $tree->look_down( class => 'developer' );
            return 'unknown' unless @nodes;

            return ( $nodes[0]->find_by_tag_name('a') )[0]->as_text
        },
        app_name                => sub{
            my $html = shift;
            my $app_info = shift;
            my @nodes = $tree->look_down( class => 'product-title' );
            unless( @nodes ){
                $log->( 
                    'error',
                    "can't find app_name"
                );
                return
            }
            my $app_name = $nodes[0]->as_text;
            $app_name =~ s/\s+$//g;
            return $app_name;
        },
        current_version         => sub{
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'product-title' );
            unless( @nodes ){
                $log->(
                    'error',
                    "can't find version"
                );
            }
            if( my $text = $nodes[0]->as_text ){
                $text =~ s/\r//g;
                $text =~ s/\n//g;
                $text =~ s/\s+$//g;
                if( $text =~ m/\s([\d\.]+)$/ ){
                    return $1
                }
                return 'unknown'
            }else{
                return 'unknown'
            }
        },   
        icon                    => sub {
=pod
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'product-thumb' );
            unless( @nodes ){
                $log->(
                    'error',
                    "can't find icon"
                );
                return
            }
            return $nodes[-1]->attr('src');
=cut
            my $html = shift;
            my $app_info = pop;
            my $app_url_md5 = md5_hex($app_info->{app_url});
            my $sql = <<EOF;
            select information from app_extra_info 
            where app_url_md5 = '$app_url_md5'
EOF
            my $hashref = $dbh->selectrow_hashref( $sql);
            unless ( exists $hashref->{information} ){
                $log->('error',"can't find app icon");
                return
            }
            my $icon= ( split(";",$hashref->{information}) )[1];
            return $icon;
        },
        screenshot              => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'product-image' );
            unless( @nodes ){
                $log->(
                    'error',
                    "can't find screen"
                );
                return
            }
            return [ map{ $_->attr('src') } @nodes ];
        },
        system_requirement      => undef,
        min_os_version          => undef,
        max_os_version          => undef,
        resolution              => undef,
        last_update             => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'stat' );
            return '0000-00-00' unless @nodes;
            if( $nodes[0]->as_text =~ m/(\d{4}-\d{2}-\d{2})/s ){
                return $1
            }
            return '0000-00-00'
        },  
        size                    => sub {0},
        official_rating_stars   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'rating-text' );
            return unless @nodes;
            if ( $nodes[0]->as_text =~ m{(\d+)/\d+}s ){
                return $1
            }

            return '0'
        },
        official_rating_times   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'rating-text' );
            return unless @nodes;
            if ( $nodes[0]->as_text =~ m{(\d+)\s+ratings}si ){
                return $1
            }

            return
        },
        app_qr                  => undef,
        note                    => undef,
        apk_url                 => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'download_buttons');
            unless ( @nodes ){
                $log->( 'error',"can't find download apk url button");
                return
            }
            my $tag = ( $nodes[0]->find_by_tag_name('a') )[0];
            if( (my $link = $tag->attr('href'))=~ m/download/ ){
                # http://www.handster.com/download_250_solitaire_collection.html?action=list_builds&email=
                my $free_link = $link."?action=list_builds&email=";
                return $free_link;
            }
            else{
                return $link
            }
        },
        total_install_times     => sub {
            my ( $html,$app_info ) = ( shift,pop );
            if( $html =~ m/Downloads:\s+(\d+)/s ){
                return $1
            }
            return 0
        },
        description             => sub{
            my ( $html,$app_info ) = ( shift,pop );
=pod
            my @nodes = $tree->look_down( id => 'product-description' );
            return unless @nodes;
            my $desc = $nodes[0]->as_text;
=cut    
            my $node = $tree->look_down( 
                    class => 'description',
                    sub {
                        $_[0]->as_text =~ m/Summary/is
                    }
            );
            my $desc = $node->as_HTML;
            $desc =~ s/Summary\s*://si;
            return AMMS::Util::del_inline_elements($desc);
        },
        official_category       => sub {
            my $html = shift;
            my $app_info = pop;
            my $app_url_md5 = md5_hex($app_info->{app_url});
            my $sql = <<EOF;
            select information from app_extra_info 
            where app_url_md5 = '$app_url_md5'
EOF
            my $hashref = $dbh->selectrow_hashref( $sql);
            unless ( exists $hashref->{information} ){
                $log->('error',"can't find app category");
                return
            }
            my $category = ( split(";",$hashref->{information}) )[0];
            return $category;
        },
        related_app             => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( id => 'product-upsell' );
            return unless @nodes;
            return [ 
                map{ $_->attr('href') } 
                $nodes[0]->find_by_attribute( class => 'product-details-link')
            ]
        },
        price                   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'price-value' );
            return 0 unless @nodes;
            return 0 unless $nodes[0]->find_by_tag_name('b');
            my $price = ($nodes[0]->find_by_tag_name('b'))[0]->as_text ;
            if( $price =~ m/\$(\d.+?)/ ){
                $price =~ s/\$/'USD:'/e;
                return $price;
            }else{
                return 0
            }
        },
        permission              => undef,
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
=pod
        $self->{ 'CONFIG_HANDLE' }->getAttribute('LOGGER')->error(
                sprintf("fail to save app, App URL MD5:%s, Error:%s",
                        $app_url_md5,$self->{'DB_Handle'}->errstr
=cut
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
    $NewAppExtractor->{DOWNLOADER}{USERAGENT}->max_redirect(0);
    $NewAppExtractor->addHook('extract_app_info', \&extract_app_info);
    $NewAppExtractor->addHook('download_app_apk',\&download_app_apk);
    $NewAppExtractor->run($task_id);
}
elsif( $task_type eq 'update_app' )##download updated app info and apk
{
    my $UpdatedAppExtractor= new AMMS::UpdatedAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $UpdatedAppExtractor->{DOWNLOADER}{USERAGENT}->max_redirect(0);
    $UpdatedAppExtractor->addHook('extract_app_info', \&extract_app_info);
    $UpdatedAppExtractor->addHook('download_app_apk',\&download_app_apk);
    $UpdatedAppExtractor->run($task_id);
}

sub extract_page_list{
    # accept args ref from outside
    my $worker	= shift;
    my $hook	= shift;
    my $params  = shift;
    my $pages	= shift;

    print "run extract_page_list ............\n";
    # create a html tree and parse
    my $web = $params->{web_page};
    my $downloader = new AMMS::Downloader;
    eval{
        my $tree = new HTML::TreeBuilder;
        $tree->parse($web);
        $tree->eof;
        # http://www.handster.com/themes_and_skins.htm?product_id=34379
        # http://www.handster.com/free_themes_and_skins.htm
        # free
        my @nodes = $tree->look_down( class => 'paidfree-tab' );
        unless( @nodes ){
            $log->('error',"can't find paid free tab");
            return
        }
        @$pages =  
            map{ $url_base.'/'.$_->attr('href')  }
            ( $nodes[0]->find_by_tag_name('a') );
        my @list ;
        foreach my $type( @$pages ){
            my $res = $downloader->download($type."?is_ajax=1");
            my $tree = new HTML::TreeBuilder;
            $tree->parse($res);
            $tree->eof;
            my $pager= $tree->look_down( class => 'p_pager');
            my $last_page_num = ( $pager->find_by_tag_name('a') )[-2]->as_text;
            push @list, $type."?p=".$_ foreach ( 2..$last_page_num );
        }
        push @$pages,@list if @list;
    };
    if($@){
#        print Dumper $pages;
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
        $tree->delete;
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
    eval{
        my $html = $params->{web_page};
        my $tree = new HTML::TreeBuilder;
        $tree->parse($html);
        $tree->eof;
        my $category;
        # tags main-container
        my $box = $tree->look_down( class => 'breadcrumbs' );
        $category = ( $box->find_by_tag_name('a') )[-1]->as_text;
        if( $category =~ m/free/i ){
            $category = ( $box->find_by_tag_name('a') )[-2]->as_text;
        }
        $category =~ s/&amp/&/g;
        my @nodes = $tree->look_down( 
                class => 'product-details-link',
                sub{ 
                    $_[0]->parent()->attr('product_id') 
                    &&
                    $_[0]->parent()->attr('product_id') =~ m/(\d+)/ 
                    && 
                    do{ 
                        $apps->{$1} =  $_[0]->attr('href') ;
                        my $icon = $_[0]->find_by_attribute( 
                            'class',
                            'product-thumb'
                            )->attr('src');
                        save_extra_info( 
                            md5_hex( $_[0]->attr('href') ),
                            $category,
                            $icon,
                        );
                    }
               }
        );
    };
    if($@){
        $apps = {};
        return 0
    }
    return 0 unless scalar(keys %{ $apps } );

    return 1;
}
sub save_extra_info{
    my $app_url_md5 = shift;
    my $category= shift;
    my $icon = shift;
    my $data = $category.";".$icon;
    my $sql = "replace into app_extra_info(app_url_md5,information) values(?,?)"; 
    my $sth = $dbh->prepare($sql);
    $sth->execute($app_url_md5,$data) or $log->('error',"save category fail and
            app_url_md5 is $app_url_md5");
}

sub download_app_apk 
{
    my $self    = shift;
    my $hook_name  = shift;
    my $apk_info= shift;

    my $apk_file;
    my $md5 =   $apk_info->{'app_url_md5'};
    my $apk_dir= $self->{'TOP_DIR'}.'/'. get_app_dir( $self->getAttribute('MARKET'),$md5).'/apk';

    my $downloader  = $self->{'DOWNLOADER'};
    $downloader->{USERAGENT}->max_redirect(7);

    $downloader->header({Referer=>$apk_info->{'app_url'}});

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
        $downloader->{USERAGENT}->max_redirect(0);
        return 0;
    }

    my $timeout = $self->{'CONFIG_HANDLE'}->getAttribute('ApkDownloadMaxTime');
    $timeout += int($apk_info->{size}/1024) if defined $apk_info->{size};
    $downloader->timeout($timeout);
    $apk_file=$downloader->download_to_disk($apk_info->{'apk_url'},$apk_dir,undef);
    if (!$downloader->is_success)
    {
        $apk_info->{'status'}='fail';
        $downloader->{USERAGENT}->max_redirect(0);
        return 0;
    }

    unless (check_apk_validity("$apk_dir/$apk_file") ){
        $apk_info->{'status'}='fail';
        return 0;
    }
 
    $apk_info->{apk_md5}=file_md5("$apk_dir/$apk_file");
    my $unique_name=$apk_info->{apk_md5}."__".$apk_file;


    rename("$apk_dir/$apk_file","$apk_dir/$unique_name");


    $apk_info->{'status'}='success';
    $apk_info->{'app_unique_name'} = $unique_name;

    $downloader->{USERAGENT}->max_redirect(0);
    return 1;
}


