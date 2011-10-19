#!/usr/bin/perl 
#===============================================================================
#         FILE: getjar.pl
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


my $market      = 'www.getjar.com';
my $url_base    = 'http://www.getjar.com';
#my $downloader  = new AMMS::Downloader;
my $login_url   = '';
my $cookie_file = '';

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
my $dbh = new AMMS::DBHelper;
my $dbi = $dbh->connect_db;

our %category_mapping=(
        'Music' => 800,
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
        author                  
        app_name
        current_version
        icon                    
        price                   
        total_install_times     
        description             
        screenshot               
        official_category       
        status                  
        size                    
        trustgo_category_id     
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

if( $task_type eq 'new_app' )##download new app info and apk
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
    $UpdatedAppExtractor->addHook('download_app_apk',\&download_app_apk);
    $UpdatedAppExtractor->run($task_id);
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

sub get_app_list{
    my $html      = shift;
    my $app_mark  = shift||'t';
    my $apps_href = shift;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    my @nodes = $tree->look_down( class => $app_mark );
    Carp::croak('not find apps nodes by this mark name')
        unless ( scalar(@nodes) );


    $tree->delete;
    return
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

sub get_author{
    return $AUTHOR;
}

sub get_trustgo_category_id{
    my $name = shift;
    return  $category_mapping{ shift @_ };
}

sub get_app_url{
    my $html = shift;

    # html_string
    # match app url from html 
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    my @nodes = $tree->look_down( class => 'down' );
    return 0 unless @nodes;
    $tree->delete;

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
    return $app_name;
}

sub get_price{ 
    return 0;
}

sub get_description{
    my $html = shift;
    my $app_info = shift;

    my @nodes = $tree->look_down( class => 'product_desciption');
    return unless @nodes;

    my $desc = $nodes[0]->as_text;
    $desc =~ s/\r//sg;
    $desc =~ s/\n//sg;
    
    return  $desc;
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
    my $cookie_file = shift;
    my $login_html  = get($login_url);

    my %info = $login_html =~ m{<input type="hidden" name="(.+?)" value="(.*?)"}sg;
    my $cookie_jar = HTTP::Cookies->new(
        file        => $cookie_file,
        autosave    => 1,
    );
#http://www.getjar.com/devicesearch?jsoncallback=jsonp1317279601246&action=dialog&type=searchPhonesJSON&query=nexus+one&itemsCount=100&nocache=96316638

    my $ua = LWP::UserAgent->new;
    my $username ="jinyiming321";
    my $pwd ="19841002";
    
    $ua->cookie_jar($cookie_jar);
    $ua->agent("Mozilla/4.0");
    
    # post form
    $ua->cookie_jar($cookie_jar);
    push @{$ua->requests_redirectable}, 'POST';
    my $res = $ua->post(
        $login_url,
        [
            login       => 'jinyiming321',
            pwd         => '19841002',
            op          => $info{op},
            formhash    => $info{formhash},
            forward     => '',
            postsubmit  => $info{postsubmit},
            remember    => 1
        ]
    );
    if( Encode::decode_utf8($res->content) =~/退出登录/s){
        return 1;
    }

    return 
}

sub get_apk_url{
    my $html = shift;
    my $sid;
    # save sid for get_permission's sid
    {
        no strict 'refs';
        ${ __PACKAGE__."::"."SID" } = $sid;
    }

    unless( -e $cookie_file ){
        Carp::croak("can't get cookie from coolapk")
            unless get_cookie($cookie_file);
    }

    my $ua = LWP::UserAgent->new;
    my $cookie_jar = HTTP::Cookies->new(
         file => $cookie_file,
    );
    $cookie_jar->load($cookie_file);
    $ua->cookie_jar($cookie_jar);
    $ua->agent("Mozilla/4.0");
    my $retry = 0;

    DOWN_LOAD_APK:
    my $apk_download_url = "http://www.coolapk.com/dl";
    # http://www.coolapk.com/dl?sid=MjU0NiwxOCwxNiwxLCw4M2RlMmExNg==&inajax=1&op=download&d=1316691530671
    # header
    #   d	1316691530671
    #   inajax	1
    #   op	download
    #   sid	MjU0NiwxOCwxNiwxLCw4M2RlMmExNg==
    # 
    my $res = $ua->post( 
        $apk_download_url,[
            sid     => $sid,
            inajax  => 1,
            op      => 'download',
            d       => 1316691530671,# a ad id,task easy
        ]
    );
    if( $res->status_line =~ m/200/ ){
		# window.location.href='\/dl?dl=1&sid=&authimg=&hash=4ef3b755'
        if( $res->content =~ m/href='(.+?)'/s ){
            my $download = $1;
            $download =~ s/\\//g;
			$download =~ s/sid=/'sid='.$sid/e;
            return $url_base.$download;
        }
    }else{
        get_cookie($cookie_file) && goto DOWN_LOAD_APK unless $retry;
        ++$retry;
        return;
    }
}

sub get_official_rating_stars{
    my $html  = shift;
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
    
    my $app_url_md5 = md5_hex($app_info->{app_url});
    my $sql = <<EOF;
    select information from app_extra_info 
    where app_url_md5 = '$app_url_md5'
EOF
    my $hashref = $dbi->selectrow_hashref( $sql);
    return $hashref->{information};
}

#-------------------------------------------------------------

sub get_current_version{
    return 'unknown'
}

sub get_app_qr{
    my $html = shift;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    my $qr;
    my @nodes = $tree->look_down( class => 'qrcode' );
    return 0 unless @nodes;

    return trim_url($url_base).$qr||undef;
}
sub get_screenshot{
    my $html = shift;
    my $app_info = shift;

    my @nodes = $tree->look_down( class => 'thumbs' );
    return unless @nodes;

    my @tags = $nodes[0]->find_by_tag_name('img');
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
    
    # a related apps 
    my $related_apps = [];
    # create a empty html tree
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    return  $related_apps;
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
    use LWP::Simple;
    my $url
        ='http://www.getjar.com/mobile/82185/pandora%C2%AE-internet-radio-for-google-nexus-one/';
    my $content = get( $url );
    my $app_info = {};
    $app_info->{app_url} = $url;
    extract_app_info( undef,undef,$content,$app_info );
    use Data::Dumper;
    print Dumper $app_info;
    #    print "key => ".decode_utf8($app_info->{$_}\n";
}
sub download_app_apk 
{
    my $self    = shift;
    my $hook_name  = shift;
    my $apk_info= shift;

    my $apk_file;
    my $md5 =   $apk_info->{'app_url_md5'};
    my $apk_dir= $self->{'TOP_DIR'}.'/'. get_app_dir( $self->getAttribute('MARKET'),$md5).'/apk';
    my $cookie_jar = HTTP::Cookies->new(
         file => $cookie_file,
    );
    $cookie_jar->load($cookie_file);

    my $downloader  = new AMMS::Downloader;
    $downloader->header({Referer=>$apk_info->{'app_url'}});
    $downloader->{USERAGENT}->cookie_jar($cookie_jar);

    if( $apk_info->{price} ne '0' ){
        $apk_info->{'status'}='paid';
        return 1;
    }
    eval { 
        rmtree $apk_dir if -e $apk_dir;
        mkpath $apk_dir;
    };
    if ( $@ )
    {
        $self->{ 'LOGGER'}->error( sprintf("fail to create directory,App ID:%s,Error: %s",
                                    $md5,$@)
                                 );
        $apk_info->{'status'}='fail';
        return 0;
    }

    $downloader->timeout($self->{'CONFIG_HANDLE'}->getAttribute('ApkDownloadMaxTime'));
    $apk_file=$downloader->download_to_disk($apk_info->{'apk_url'},$apk_dir,undef);
    if (!$downloader->is_success)
    {
        $apk_info->{'status'}='fail';
        return 0;
    }

    my $unique_name=md5_hex("$apk_dir/$apk_file")."__".$apk_file;

    rename("$apk_dir/$apk_file","$apk_dir/$unique_name");


    $apk_info->{'status'}='success';
    $apk_info->{'app_unique_name'} = $unique_name;

    return 1;
}

1;
#&run;

__END__



