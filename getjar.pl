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

my $mobile_agent = 
        'Mozilla/5.0 (Linux; U; Android 2.1-update1; en-us; sdk Build/ECLAIR)'
        .'AppleWebKit/530.17 (KHTML, like Gecko) Version/4.0 Mobile Safari/530.17';
my $web_agent = 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.2 (KHTML, like Gecko)'
    .'Chrome/15.0.874.81 Safari/535.2';
my $mobile_base_url = 'http://client.getjar.com';
my $web_base_url = 'http://www.getjar.com';
my $download_base_url = 'http://download.getjar.com';
my $set_device_url =
'http://www.getjar.com/set-user-device/?udvsName=google-nexus-s&udvsId=15440';
my $cookie_file = 'getjar_cookie.txt';
#get_cookie();

my $task_type   = $ARGV[0];
my $task_id     = $ARGV[1];
my $conf_file   = $ARGV[2];

my $market      = 'www.getjar.com';
my $url_base    = 'http://www.getjar.com';

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
        'reference-education' => '20',
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
        official_comment_times  => \&get_official_rating_times,
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

my $cookie_jar = HTTP::Cookies->new(
         file => $cookie_file
);
# check args 
unless( $task_type && $task_id && $conf_file ){
    die $usage;
}

# check configure
die "\nplease check config parameter\n" 
    unless init_gloabl_variable( $conf_file );

my $downloader;

if( $task_type eq 'find_app' )# find app
{
    my $AppFinder =
      new MyAppFind( 'MARKET' => $market, 'TASK_TYPE' => $task_type );
    $cookie_jar->load($cookie_file);

    $AppFinder->{DOWNLOADER}->{USERAGENT}->cookie_jar( $cookie_jar );
    $AppFinder->addHook('extract_page_list', \&extract_page_list);
    $AppFinder->addHook('extract_app_from_feeder', \&extract_app_from_feeder);
    $AppFinder->run($task_id);
}
elsif( $task_type eq 'new_app' )##download new app info and apk
{
	$downloader = new AMMS::Downloader;
	$downloader->{USERAGENT}->agent( $mobile_agent );
    my $NewAppExtractor= new AMMS::NewAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $NewAppExtractor->{DOWNLOADER}->{USERAGENT}->cookie_jar( $cookie_jar );
    $NewAppExtractor->addHook('extract_app_info', \&extract_app_info);
#    $NewAppExtractor->addHook('download_app_apk',\&download_app_apk);
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
        my $tree = new HTML::TreeBuilder;
        $tree->parse($web);
        my $page;
        if( my @nodes = (
                $tree->look_down( class => 'more_bar' ) 
              or $tree->look_down( id => 'row_right_arrow' )
            )
        ){
            my $page = $nodes[0]->find_by_tag_name('a')->attr('href');
            if( my %hash = $page =~ m/(?<=(?:[?]|&))(\w+?)=(.+?)(?=(?:&|$))/g ){
                $page =~ s/(?:\?|&)$_=$hash{$_}//g foreach ( 'sid','lvt');
                $params->{next_page_url} = $url_base.$page;
            }
        }
    };
    if($@){
#        print Dumper $pages;
        return 0 unless scalar @$pages
    }
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
    
    print "run extract_app_from_feeder_list ............\n";
    my $category;
    eval{
        my $html = $params->{web_page};
        my $tree = new HTML::TreeBuilder;
        $tree->parse($html);
        $tree->eof;
        # mobile-reference-education-applications
        if( $params->{base_url} =~ m/mobile-(.+?)-applications/ ){
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
=pod
                my $app_url 
                    = $mobile_base_url
                    . "/mobile/".$app_id."/"
                    . $app_name
                    . "-for-".$device
                    . "/?lang=".$lang."&gjclnt=1";
=cut
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
    my ( $html,$app_info ) = @_;

    my $node = $tree->look_down( id => 'product_count_label' );
    return 0 unless ref $node;

    return $node->as_text;
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

    my $link_regex = qr{
            mobile/(\d+)/(.+?)-for- #match appliacation ID
            (.+?)                  #match device type
    }sx;
    my $phone_html ;
 
    my $app_url = $app_info->{app_url};
    if( $app_url =~ m{$link_regex}o ){
    	my ( $app_id,$app_name,$device ) = ( $1,$2,$3 );
    	my $app_url 
    	    = $mobile_base_url
    	    . "/mobile/".$app_id."/"
    	    . $app_name
    	    . "-for-".$device
    	    . "/?lang=en&gjclnt=1";

        my $m_page = $downloader->download( $app_url );
        $phone_html = decode_utf8( $m_page );
        if( $phone_html =~ m/downloadUrl\s*=\s*"(.+?)\?/s ){
        	return $1;
        }
    }
    return 
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
    my $data = $category;
    my $sql = "replace into app_extra_info(app_url_md5,information) values(?,?)"; 
    my $sth = $dbi->prepare($sql);
    $sth->execute($app_url_md5,$data) or warn ( "can't replace sql $sql" );
}


1;
#&run;

__END__



