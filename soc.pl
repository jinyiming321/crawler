#*****************************************************************************
# *     Program Title: soc.pl
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
use HTML::Entities;
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

my $market      = 'mall.soc.io';
my $url_base    = 'http://mall.soc.io';
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

            my @nodes = $tree->look_down( class => 'title2' );
            unless( @nodes ){
            	$log->( warn => "can't find author name" );
            	return "unknown"
            }
            my $tag = $nodes[0]->find_by_tag_name('a');
            return ref($tag) ? $tag->as_text : "unknown";
        },
        app_name                => sub{
            my $html = shift;
            my $app_info = shift;
            
            my @nodes = $tree->look_down( class => 'title1' );
            unless( @nodes ){
                $log->( 
                    'warn',
                    "can't find app_name"
                );
                return
            }
            return ref($nodes[0]) ? $nodes[0]->as_text : undef;
        },
        current_version         => sub{
            my ( $html,$app_info ) = ( shift,pop );
            
            my $regex = qr/Version.*?<span.*?>([\d\.]+)\S+?<\/span>/s;
            if( $html =~ m/$regex/o ){
            	return $1;
            }
            
        },   
        icon                    => sub {
            my ( $html,$app_info ) = ( shift,pop );

            my @nodes = $tree->look_down( class => 'info_app_icon' );
            unless( @nodes ){
                $log->(
                    'warn',
                    "can't find icon"
                );
                return
            }
            return $nodes[0]->find_by_tag_name('img')->attr('src');
        },
        screenshot              => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( 
                'class' => 'app_photo'
            );
            unless( @nodes ){
                $log->(
                    'warn',
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
            return undef
        },
        max_os_version          => sub{
        	return undef
        },
        resolution              => sub{
        	return undef
        },
        last_update             => sub {
            my ( $html,$app_info ) = ( shift,pop );

            return '0000-00-00'
        },  
        size                    => sub {0},
        official_rating_stars   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my $rating_stars = () = $html =~ m/class="star_info star_info_on"/sg;
            return $rating_stars ;
        },
        official_rating_times   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my $node = $tree->look_down( id => 'vtCount' );
            return 0 unless ref($node);
            if( $node->as_text =~ m/\((\d+)\)/s ){
            	return $1
            }
            return 0
        },
        app_qr                  => sub{
            my ( $html,$app_info ) = ( shift,pop );
            my $bar = $tree->look_down( class => 'sidebar' );
            unless( ref($bar) ){
            	$log->( warn => "can't find app_qr node" );
            	return
            }
            return $bar->find_by_tag_name('img')->attr('src');
        },
        note                    => undef,
        apk_url                 => sub {
            # todo
        },
        total_install_times     => sub {
            my ( $html,$app_info ) = ( shift,pop );
            # <li class="downloads">84</li>
            if( $html =~ m/Installs:.*?class="title3">(\d+)<\/td>/s ){
                return $1;
            }
            return 0
        },
        official_comment_times  => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my $node = $tree->look_down( class => 'info_app_comments' );
            return 0 unless ref($node);
            
            my @tags = $node->find_by_tag_name('a');
            return scalar(@tags) || 0;
        },
        description             => sub{
            my ( $html,$app_info ) = ( shift,pop );

            my $node = $tree->look_down( 
                _tag   => 'div',
                class  => qr/(\w+?_description)/
            );
            unless( ref($node) ){
            	$log->( warn => "can't find description" );
            	return
            }
            my $desc = $node->as_HTML;
            $desc =~ s/<div.*?>//g;
            $desc =~ s#</div>##g;
            return AMMS::Util::del_inline_elements($desc);
        },
        official_category       => sub {
            my ( $html,$app_info ) = ( shift,pop );
            # <a href="/category/185" title="Games &amp; Entertainment::Adventure &amp; Roleplay">Games &amp; Entertainment...</a>
            my $node = $tree->look_down( 
                _tag => 'a',
                href => qr{/category/\d+},
            );
            unless( ref($node) ){
            	return "Ebooks";
            }
            return ( split('::',$node->attr('title') ) )[-1];
        },
        related_app             => sub {
            my ( $html,$app_info ) = ( shift,pop );

            my $node = $tree->look_down( class => 'front_slider' );
            unless ( ref($node) ){
            	$log->( warn => "can't find related_app " );
            	return [];
            }
            return [
                grep {/\S+/}
                map{ ( split(';',$url_base.$_->attr('href')) )[0] }
                $node->find_by_attribute( class => 'app_title' )
            ]
        },
        price                   => sub {
            my ( $html,$app_info ) = ( shift,pop );

            my $tag = $tree->look_down(
                class   => 'info_app_buy'
            );
            unless( ref($tag) ){
            	return 0
            }
            my $p = $tag->as_text;
            if( $p =~ m/\$([\d\.]+)/ ){
                return 'USD:'.$1
            }
            return 0
        },
        permission              => sub{
            return undef
        },
        category_id             => undef,
);


#our $AUTHOR     = 'unknown';
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
                warn(   'fail to download webpage '
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
                    $webpage= $downloader->download($page);
                    if ( not $downloader->is_success ) {
                        if ( $downloader->is_not_found ) {
                            $self->{'DB_HELPER'}
                              ->save_url_from_feeder( $id, $page, 'invalid' );
                        }
                        else {
                            $self->{'DB_HELPER'}
                              ->save_url_from_feeder( $id, $page, 'fail' );
                        }
                        #redo FEED;
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
                $self->invoke_hook_functions( 'extract_page_list', \%params,
                    \@pages );
                $page = $params{'next_page_url'};
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

if( $task_type eq 'find_app' )##find new android app
{    
    my $AppFinder   = new MyAppFind('MARKET'=>$market,'TASK_TYPE'=>$task_type);
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
    my ( $worker, $hook, $params, $pages ) = @_;
    my $webpage     = $params->{'web_page'};
    my $base_page = $params->{base_page};
    my $match = 0;
    if( $base_page =~ m/page=(\d+)/ ){
        $match = int($1);
    }
    my $total_pages = 0;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($webpage);
    $tree->eof;
    eval {
        my $node = $tree->look_down( class => 'controls_buttons_cat');
        my $link = ( $node->find_by_tag_name('a') )[-2]->attr('href');
        $link =~ m/page=(\d+)/;
        my $link_num = int($1);
        if( $link_num == $match ){
            $params->{next_page_url} = undef;
        }else{
        	my $temp = $url_base;
        	$temp .= "?page=0" if index( $base_page,'page' ) == -1;
            $temp =~ s/page=(\d+)/'page='.($1+1)/e;
            $params->{next_page_url} = $temp;
        }
    };
    if( $@ ){
        return 0
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
        $log->(warn => $@ );
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
        my @nodes = $tree->look_down( class => 'app_box' );
        $log->( 'warn' => 'not find apps id') unless @nodes;

        foreach my $app_node( @nodes ){
            next unless ref $app_node;
            my $app_link = 
                ( 
                    split( 
                        ';',
                        $app_node->find_by_tag_name('a')->attr('href')
                ) )[0];
            if( $app_link =~ m{/([^\/]+)$} ){
                $apps->{$1} = $url_base.$app_link;
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
    
    my $page_file = 'sco_page.html';
    my $feeder_file = 'sco_t_feeder.html';
    my $app_info_file = 'sco_angry_book.html';
    getstore( 'http://mall.soc.io/category/184',$page_file)
            unless -e $page_file;
    getstore(
            'http://mall.soc.io/category/184?page=1',
            $feeder_file
     ) unless -e $feeder_file;
    getstore(
            'http://mall.soc.io/books/2787595',$app_info_file )
        unless -e $app_info_file;
#    $content = get_content( 'anfone_content.html');
    $feeder = get_content( $page_file );
    $page = get_content( $feeder_file );
    my $info = get_content( $app_info_file );
#    $feeder = get_content('anfone_feeder.html');
    my $app_info = {};
    my $app_list = {};
    my $page_list = [];
    extract_page_list( undef,undef,{ web_page => $feeder,base_page => 
            'http://mall.soc.io/category/184'
        },$page_list );
    use Data::Dumper;
    print Dumper $page_list;
    extract_app_from_feeder( undef,undef,{ web_page => $page} ,$app_list);
    print Dumper $app_list;
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


