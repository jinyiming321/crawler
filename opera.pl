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
my $task_type   = $ARGV[0];
my $task_id     = $ARGV[1];
my $conf_file   = $ARGV[2];

my $device_id   = 2459;

my $market      = 'mobilestore.opera.com';
my $url_base    = 'http://mobilestore.opera.com';
#my $downloader = new AMMS::downloader;
my $ua = new LWP::UserAgent;
$ua->max_redirect(0);
$ua->timeout(60);
my $header ;
my $res = $ua->get("http://mobilestore.opera.com/SelectDevice.jsp");
if( $res->is_success ){
    my $cookie = $res->header('set-cookie');
    # JSESSIONID=F3FC72207A474D2D96540518EEDAB26D.jvm1; 
    if( $cookie =~ m/(JSESSIONID=[^;]+);/ ){
        $header = $1.";"."handango_device_id=$device_id;";
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
 'Computer & Engineering'   => 2,
 Construction   => 2,
 'Expense Trackers'   => 2,
 Finance   => '209',
 Insurance   => '206',
 'Inventory Tracking'   => '204' ,
 Law   => '107' ,
 Other   => '0' ,
 'Project Tracking'   => '1606' ,
 'Real Estate'  => '205' ,
 Sales   => '2' ,
 Chat   => '400' ,
 Email   => '401' ,
 'Internet Browsers'   => '2210' ,
 'Phone & Fax'   => '2209' ,
 Ringtones   => '1202' ,
 SMS   => '400' ,
 'Database Programs'   => '1601' ,
 'Development Software'   => '1100' ,
 'Note Taking & Forms'   => '4' ,
 Presentations   => '1604' ,
 Spreadsheets   => '1604' ,
 'Word Processing'   => '16' ,
 'Computer Science & Engineering'   => '1,5' ,
 Dictionaries   => '103' ,
 'History and Social Sciences'   => '105' ,
 'Language Arts'   => '106,100' ,
 Math   => '109' ,
 'Physical Education and Sports'   => '1' ,
 Religion   => '111' ,
 Science   => '102' ,
 Student   => '1' ,
 Teacher   => '1' ,
 Thesaurus   => '1' ,
 'Dining Out'   => '1' ,
 Jokes   => '3' ,
 'Just for fun'   => '303' ,
 Ringtones   => '1202' ,
 'TV & Movies'   => '605,610' ,
 Action   => '823' ,
 Adventure   => '800' ,
 Board   => '802' ,
 Cards   => '803' ,
 Casino   => '804' ,
 Chess   => '810' ,
 'Game Packs'   => '8' ,
 Puzzle   => '810' ,
 Solitaire   => '8' ,
 Sports   => '814' ,
 Strategy   => '815' ,
 Trivia   => '816' ,
 Word   => '817' ,
 'Diet & Nutrition'   => '900,905' ,
 Fitness   => '901' ,
 'Personal Healthcare'   => '9' ,
 Astrology   => '1908' ,
 Astronomy   => '19' ,
 Aviation   => '19' ,
 'Food & Drink'   => '1905' ,
 Reading   => '2500' ,
 Shopping   => '17' ,
 Calculators   => '22' ,
 'Charge Capture'   => '22' ,
 'Drug Databases'   => '1000' ,
 'Patient Tracking'   => '1001' ,
 Reference   => '1' ,
 'Graphics & Images'  => '1201' ,
 'Movies & Videos'   => '12' ,
 'Music & Audio'   => '12' ,
 TV   => '12' ,
 'Budget & Expense'   => '203' ,
 'Stock Trackers'   => '202' ,
 'Address Book'   => '16' ,
 Calendar   => '1605' ,
 'Lists & Outlines'   => '16' ,
 Memo   => '16' ,
 Tasks   => '16' ,
 'Time Trackers'   => '16' ,
 'Chinese'      => 106,
 'French'       => 106,
 'German'       => 106,
 Italian        => 106,
 Japanese       => 106,
 Spanish        => 106,
 'Translation Programs' => 106,
 Automobile     => '21',
 'City Guides'  => '2100,2101',
 'Currency'     => '208',
 'GPS'          => '2106',
 'Itineraries & Schedules' => 21,
 'Lists'        => 21,
 'Maps'         => 2105,
 'Transportation' => 13,
 Weather        => 13,
 'World Time'     => 13,
 Alarms         => '2215',
 Backup         => '2200',
 Battery        => '2214',
 Clocks         => '2215',
 Conversion     => '1600',
 'Data Entry'   => '22',
 Hacks          => '22',
 Launchers      => '2204',
 Memory         => '22',
 Printing       => '22',
 Security       => '23',
 Synchronization => '22',
'Business and Professional' => '2',
'Communications' => '4',
'Development Tools' => '1100',
'Document Management' => '2207',
'Education and Reference' => '5,1',
'Entertainment' => '6',
'Games' => '8',
'Health & Fitness' => '9',
'Hobbies' => '19',
'Medical' => '10',
'Multimedia' => '7',
'Personal Finance' => '209',
'Productivity' => '16',
'Software Tools' => '22',
'Themes' => '1203',
'Translation' => '22',
'Travel' => '21',
'Utilities' => '22',
'eBooks' => '1',
);
my $dbhelper = new AMMS::DBHelper;
my $dbh = $dbhelper->connect_db;


# define a app_info mapping
# because trustgo_category_id is related with official_category
# so i remove it from this mapping
our %app_map_func = (
        author                  => sub { 'unknown' },
        app_name                => sub{
            my $html = shift;
            my $app_info = shift;

            my @nodes = $tree->look_down( 'id' => 'content' );
            return unless @nodes;
            return ($nodes[0]->find_by_tag_name('h3'))[0]->as_text;
        },
        current_version         => sub {'unknown'},
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
        last_update             => sub {"0000-00-00"},
        size                    => sub {0},
        official_rating_stars   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( alt => 'Rating' );
            return unless @nodes;
            # official_rating_stars
            # http://cdn.appia.com/pictures/mwf/cfg/27/img/rated-0-half-5.gif
            if ( my $src = $nodes[0]->attr('src') ){
                $src =~ s/half-//g;
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
        official_comment_times  => sub {
            my ( $html,$app_info ) = ( shift,pop );

            # Read Reviews(1)
            if( $html =~ m/Read.+?Reviews\((\d+)\)/s ){
                return $1
            }
            return 0
        },
        apk_url                 => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'selected_app_highlight');
            return unless @nodes;
            my @p = $nodes[0]->find_by_tag_name('p');
            my $down_link = $url_base."/".($p[0]->find_by_tag_name('a')
                    )[0]->attr('href');
            my $times = 3;
            my $apk_url;
            while( $times ){
                my $res = $ua->get( $down_link );
                if( $res->header('location') ){
                    $apk_url = $res->header('location');
                    last;
                }
                $times--;
            }
            return $apk_url || $down_link;
        },
        total_install_times     => sub {0},
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
            my $html = shift;
            my $app_info = pop;
            my $app_url_md5 = md5_hex($app_info->{app_url});
            my $sql = <<EOF;
            select information from app_extra_info 
            where app_url_md5 = '$app_url_md5'
EOF
            my $hashref = $dbh->selectrow_hashref( $sql);
            return $hashref->{information};
        },
        related_app             => undef,
        price                   => sub {
            my ( $html,$app_info ) = ( shift,pop );
            my @nodes = $tree->look_down( class => 'selected_app_highlight' );
            return unless @nodes;
            my $price = [$nodes[0]->find_by_tag_name('strong')]->[0]->as_text;
            if( $price =~ m/free/i ){
                $price = 0;
                return $price;
            }
            $price ="USD:$1" if $price =~ m/\$(.+)/;
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
die "\nplease check config parameter\n" 
    unless init_gloabl_variable( $conf_file );


if( $task_type eq 'find_app' )##find new android app
{
    my $AppFinder =
      new MyAppFind( 'MARKET' => $market, 'TASK_TYPE' => $task_type );
    $AppFinder->{DOWNLOADER}->{USERAGENT}->default_header( cookie => $header );
    $AppFinder->addHook('extract_page_list', \&extract_page_list);
    $AppFinder->addHook('extract_app_from_feeder', \&extract_app_from_feeder);
    $AppFinder->run($task_id);
}
elsif( $task_type eq 'new_app' )##download new app info and apk
{
    my $NewAppExtractor= new AMMS::NewAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $NewAppExtractor->{DOWNLOADER}->{USERAGENT}->default_header( cookie => $header );
    $NewAppExtractor->addHook('extract_app_info', \&extract_app_info);
#    $NewAppExtractor->addHook('download_app_apk',\&download_app_apk);
    $NewAppExtractor->run($task_id);
}
elsif( $task_type eq 'update_app' )##download updated app info and apk
{
    my $UpdatedAppExtractor= new AMMS::UpdatedAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $UpdatedAppExtractor->{DOWNLOADER}->{USERAGENT}->default_header( cookie => $header );
    $UpdatedAppExtractor->addHook('extract_app_info', \&extract_app_info);
#    $UpdatedAppExtractor->addHook('download_app_apk',\&download_app_apk);
    $UpdatedAppExtractor->run($task_id);
}
sub extract_page_list {
    my ( $worker, $hook, $params, $pages ) = @_;
    my $webpage     = $params->{'web_page'};
    my $total_pages = 0;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($webpage);
    $tree->eof;
    eval {
        my @nodes = $tree->look_down( id => 'pagination' );
        my $link = ( $nodes[0]->find_by_tag_name('a') )[-1]->attr('href');
        $params->{next_page_url} = $url_base.$link if $link;
        print "page link is ".$url_base . $link."\n";
     };
    return 0 if $total_pages == 0;
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
        print $@."\n";
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

    print "run extract_app_from_feeder_list ....$params->{base_url}........\n";
    eval{
        my $html = $params->{web_page};
        my $tree = new HTML::TreeBuilder;
        $tree->parse($html);
        $tree->eof;
        my @nodes = $tree->look_down( id => 'subcategory_menu' );
        my $category = ($nodes[0]->find_by_tag_name('h3'))[0]->as_text;
        my @classes = $tree->look_down( class => 'home_app' );
        foreach my $class ( @classes ){
            my $product = ( $class->find_by_tag_name('a') )[0];
            if( ( my $link = $product->attr('href') )=~ m/productId=(\d+)/i ){
                $apps->{$1} = $url_base.$link;
                print $url_base.$link."\n";
                save_extra_info( md5_hex($url_base.$link),$category );
            }
        }
    };
    if($@){
        warn $@;
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
    my $res=
        $ua->get('http://mobilestore.opera.com/ProductDetail.jsp?productId=284825');
    my @pages = ();
=pod    
    extract_page_list(
            undef,undef,{web_page=>$res->content},\@pages
    );
=cut
    my $hashref = {};
    extract_app_from_feeder( undef,undef,{ web_page => $res->content},$hashref
            );
    
    exit 0;

    
    my $apps = {};
    foreach my $page( @pages ){
        $res= $ua->get($page);
        &extract_app_from_feeder(undef,undef,{web_page=>$res->content},$apps);
    }
    my $app_num = scalar (keys %{$apps});
    print Dumper $apps;
    print "app_num is $app_num\n";
    exit 0;

    INFO:
    my $file = "opera.html";
    my $app_info = { 
        app_url =>
        'http://mobilestore.opera.com/ProductDetail.jsp?productId=284825'
    };
    
    my $r =
        $ua->get("http://mobilestore.opera.com/ProductDetail.jsp?productId=284825");
    #print $file_w $web->content;
    extract_app_info( undef,undef,$r->content,$app_info );
    use Data::Dumper;
    print Dumper $app_info;
    #    print "key => ".decode_utf8($app_info->{$_}\n";
}
sub save_extra_info{
    my $app_url_md5 = shift;
    my $data = shift;
    my $sql = "replace into app_extra_info(app_url_md5,information) values(?,?)"; 
    my $sth = $dbh->prepare($sql);
    $sth->execute($app_url_md5,$data) or warn $sth->errstr;
}


