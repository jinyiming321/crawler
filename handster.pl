#!/usr/bin/perl 
#===============================================================================
#         FILE: opera.pl
#        USAGE: task_type task_id configure
# for example => $0 find_app 144 ./default.cfg
#  DESCRIPTION: 
#      This is a program,which is a adaptor for the crawler of amms system,
# it can parse html meta data and support extract_page_list,extract_app_from_feeder,
# extract_app_info.Somewhere used HTML::TreeBuilder to parse html tree, handle 
# description,stars... with regular expression.
#
# REQUIREMENTS: HTML::TreeBuilder,AMMS::UpdatedAppExtractor,AMMS::Downloader,
#               AMMS::NewAppExtractor,AMMS::AppFinder,AMMS::Util
#         BUGS: send email to me, if there is any bugs.
#        NOTES: 
#       AUTHOR: James King, jinyiming456@gmail.com
#      VERSION: 1.0
#      CREATED: 2011/9/24 13:35
#     REVISION: 1.0
#===============================================================================

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


my $market      = 'handster.com';
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
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'product-thumb' );
            unless( @nodes ){
                $log->(
                    'error',
                    "can't find version"
                );
                return
            }
            return $nodes[-1]->attr('src');
        },
        screenshot              => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'product-image' );
            unless( @nodes ){
                $log->(
                    'error',
                    "can't find version"
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
            my @nodes = $tree->look_down( id => 'product-description' );
            return unless @nodes;
            my $desc = $nodes[0]->as_text;
            $desc =~ s/\r//g;
            $desc =~ s/\n//g;
            return $desc;
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
            return $hashref->{information};
        },
        related_app             => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( id => 'product-upsell' );
            return unless @nodes;
            return [ 
                map{ $_->attr('src') } 
                $nodes[0]->find_by_attribute( class => 'product-thumb')
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
    $NewAppExtractor->addHook('extract_app_info', \&extract_app_info);
    #$NewAppExtractor->addHook('download_app_apk',\&download_app_apk);
    $NewAppExtractor->run($task_id);
}
elsif( $task_type eq 'update_app' )##download updated app info and apk
{
    my $UpdatedAppExtractor= new AMMS::UpdatedAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $UpdatedAppExtractor->addHook('extract_app_info', \&extract_app_info);
#    $UpdatedAppExtractor->addHook('download_app_apk',\&download_app_apk);
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
            push @list, $type."?=".$_ foreach ( 2..$last_page_num );
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
#    use Data::Dumper;
#    print Dumper $app_info;
    $tree->delete;

    $app_info->{status} = 'success';
    if($@){
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
                        save_extra_info( 
                            md5_hex( $_[0]->attr('href') ),
                            $category
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
    my $data = shift;
    my $sql = "replace into app_extra_info(app_url_md5,information) values(?,?)"; 
    my $sth = $dbh->prepare($sql);
    $sth->execute($app_url_md5,$data) or $log->('error',"save category fail and
            app_url_md5 is $app_url_md5");
}


