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
    unshift(@INC, $1) if ($0=~m/(.+)\//); $|=1;
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

my $task_type   = $ARGV[0];
my $task_id     = $ARGV[1];
my $conf_file   = $ARGV[2];


my $market      = 'mobilestore.opera.com';
my $url_base    = 'http://mobilestore.opera.com';
#my $downloader = new AMMS::downloader;
my $ua = new LWP::UserAgent;
$ua->timeout(60);
my $header ;
my $res = $ua->get("http://mobilestore.opera.com/SelectDevice.jsp");
if( $res->is_success ){
    my $cookie = $res->header('set-cookie');
    # JSESSIONID=F3FC72207A474D2D96540518EEDAB26D.jvm1; 
    if( $cookie =~ m/(JSESSIONID=[^;]+);/ ){
        $header = $1.";"."handango_device_id=2433;";
    }
}else{
    die "get cookie failed\n";
}
print $header."\n";
$ua->default_header(cookie => $header);

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
    "games"    =>'',
);

# define a app_info mapping
# because trustgo_category_id is related with official_category
# so i remove it from this mapping
our %app_map_func = (
        author                  => 'unknown',
        app_name                => sub{
            my $html = shift;
            my $app_info = shift;

            my @nodes = $tree->look_down( 'id' => 'content' );
            return unless @nodes;
            return ($nodes[0]->find_by_tag_name('h3'))[0]->as_text;
        },
        current_version         => 'unknown',
        icon                    => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'selected_image' );
            return unless @nodes;           
            return ($nodes[0]->find_by_tag_name('img'))[0]->attr('src');
        },
        screenshot              => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'selected_image' );
            return unless @nodes;           
            my $link = ( $nodes[0]->find_by_tag_name('a') )[0]->attr('href');
            my $screen_page = $ua->get( $url_base.$link );
            if( $screen_page->is_success ){
                my $tree = new HTML::TreeBuilder;
                $tree->parse($screen_page->content);
                $tree->eof;
                my @nodes = $tree->look_down( id => 'screenshots' );
                return [ map { $_->attr('src') } $nodes[0]->find_by_tag_name('img') ] ;
            }else{
                die $@;
            }
            return 
        },
        system_requirement      => undef,
        min_os_version          => undef,
        max_os_version          => undef,
        resolution              => undef,
        last_update             => "0000-00-00",
        size                    => 0,
        official_rating_stars   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( alt => 'Rating' );
            return unless @nodes;
            if ( my $src = $nodes[0]->attr('src') ){
                $src =~ m/rated-(.+?)\.gif/;
                my $temp = $1;
                $temp =~ s/-/./;
                return $temp;
            }

            return
        },
        official_rating_times   => undef,
        app_qr                  => undef,
        note                    => undef,
        apk_url                 => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( alt => 'Free Download' );
            return unless @nodes;
            return $url_base.$nodes[0]->parent()->attr('href');
        },
        total_install_times     => 0,
        description             => sub{
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'selected_app' );
            return unless @nodes;
            my $desc = ( $nodes[0]->find_by_tag_name('p') )[-1]->as_text;
            $desc =~ s/\r//g;
            $desc =~ s/\n//g;
            return $desc;
        },
        official_category       => sub {
            # TODO get from app_extra_info
        },
        related_app             => undef,
        price                   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'selected_app_highlight' );
            return unless @nodes;
            my $price = [$nodes[0]->find_by_tag_name('strong')]->[0]->as_text;
            if( $price =~ m/free/i ){
                $price = 0;
            }
            return $price;
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
    $NewAppExtractor->addHook('download_app_apk',\&download_app_apk);
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
    eval{
        get_page_list( $web,undef,$pages );
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
        get_app_list( $html,undef,$apps );
    };
    if($@){
        $apps = {};
        return 0
    }
    return 0 unless scalar(keys %{ $apps } );

    return 1;
}
sub run{
    use LWP::Simple;
    goto INFO;
    #my $content = get('http://www.coolapk.com/apk-3433-panso.remword/');
    # my $content = get('http://www.coolapk.com/apk-2450-com.runningfox.humor/');
    my $content = get('http://www.coolapk.com/game/shoot/');
    my @pages = ();
    extract_page_list(undef,undef,{web_page=>$content},\@pages);
    use Data::Dumper;
    print Dumper \@pages;
    exit 0;

    use Data::Dumper;
    print Dumper \@pages;
    
    my $apps = {};
    foreach my $page( @pages ){
        $content = get($page);
        &extract_app_from_feeder(undef,undef,{web_page=>$content},$apps);
    }
    my $app_num = scalar (keys %{$apps});
    print Dumper $apps;
    print "app_num is $app_num\n";
    exit 0;
    my $html = 'coolapk-htc.html';
    use FileHandle;
    my $fh = new FileHandle(">>$html")||die $@;
    $fh->print($content);
    $fh->close;
    INFO:
    my $file = "opera.html";
    my $app_info = { 
        app_url =>
        'http://mobilestore.opera.com/ProductDetail.jsp?productId=303006'
    };
    
    my $r =
        $ua->get("http://mobilestore.opera.com/ProductDetail.jsp?productId=303006");
    #print $file_w $web->content;
    extract_app_info( undef,undef,$r->content,$app_info );
    use Data::Dumper;
    print Dumper $app_info;
    #    print "key => ".decode_utf8($app_info->{$_}\n";
}
