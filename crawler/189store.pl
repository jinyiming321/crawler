#!/usr/bin/perl 
#===============================================================================
#
#         FILE: 189store.pl
#        USAGE: ./189store.pl
#  DESCRIPTION:
#      This is a program,which is a adaptor for the crawler of amms system,
# it can parse html meta data and support extract_page_list,extract_app_from_feeder,
# extract_app_info.Somewhere used HTML::TreeBuilder to parse html tree, handle
# description,stars... with regular expression.
#
# REQUIREMENTS: HTML::TreeBuilder,AMMS::UpdatedAppExtractor,AMMS::Downloader,
#               AMMS::NewAppExtractor,AMMS::AppFinder,AMMS::Util
#         BUGS: send email to me, if there is any bugs.
#        NOTES: add support for related app,screenshot,
#       AUTHOR: zhihong zhnag, zhihong.zhang@trustgo.com
#      COMPANY: Trustgo
#      VERSION: 1.0
#      CREATED: 2011/9/19 0:10:31
#     REVISION: 1.0
#===============================================================================

use strict;
use warnings;

BEGIN { unshift( @INC, $1 ) if ( $0 =~ m/(.+)\// ); }
use strict;
use utf8;
use warnings;
use HTML::TreeBuilder;
use Carp;
use HTML::Entities;
use Data::Dumper;
use MIME::Base64;
use Cwd;
use File::Spec;
use File::Path;
use IO::File;
use LWP::UserAgent;
use HTTP::Cookies;
use JSON;

use AMMS::Util;
use AMMS::AppFinder;
use AMMS::Downloader;
use AMMS::NewAppExtractor;
use AMMS::UpdatedAppExtractor;

my $task_type = $ARGV[0];
my $task_id   = $ARGV[1];
my $conf_file = $ARGV[2];

my $market   = 'www.189store.com';
my $url_base = 'http://www.189store.com';
my $login_key;
my $ua          = LWP::UserAgent->new;
my $cookie_file = File::Spec->catfile( getcwd(), "189store.cookie" );
my $cookie_jar  = HTTP::Cookies->new( file => $cookie_file, autosave => 1 );
$cookie_jar->{ignore_discard} = 1;
$ua->cookie_jar($cookie_jar);

#my $downloader  = new AMMS::Downloader;

my $usage = <<EOF;
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

# check args
unless ( $task_type && $task_id && $conf_file ) {
    die $usage;
}

# check configure
die "\nplease check config parameter\n"
  unless init_gloabl_variable($conf_file);

# define a app_info mapping
# because trustgo_category_id is related with official_category
# so i remove it from this mapping
# modify record :
# 	2011-09-19 add support for screenshot related_app official_rating_starts
our @app_info_list = qw(
  description
  price
  icon
  screenshot
  current_version
  size
  apk_url
);

our %category_mapping = (
    '角色扮演' => 812,
    '动作射击' => '821,823',
    '竞技棋牌' => '814,803',
    '趣味休闲' => '8',
    '应用工具' => 22,
    '信息资讯' => 14,
    '娱乐休闲' => '6',
    '动态壁纸' => 1205,
    '人物卡通' => 1203,
    '风景明胜' => 1203,
    '动物植物' => 1203,
    '科技社会' => 1203,
    '名站导航' => 22,
    '综合资讯' => 14,
    '娱乐综艺' => '1405',
    '音乐'       => 709,
    '视频'       => 707,
    '播放器'    => 701,
    '漫画'       => 3,
    '阅读器'    => 2218,
    '书籍'       => 1,
    '有声读物' => 6,
);

our $AUTHOR = '天翼空间';

if ( $task_type eq 'find_app' )    ##find new android app
{
    my $AppFinder =
      new AMMS::AppFinder( 'MARKET' => $market, 'TASK_TYPE' => $task_type );
    $AppFinder->addHook( 'extract_page_list',       \&extract_page_list );
    $AppFinder->addHook( 'extract_app_from_feeder', \&extract_app_from_feeder );
    $AppFinder->run($task_id);
}
elsif ( $task_type eq 'new_app' )    ##download new app info and apk
{
    my $NewAppExtractor = new AMMS::NewAppExtractor(
        'MARKET'    => $market,
        'TASK_TYPE' => $task_type
    );
    $NewAppExtractor->addHook( 'extract_app_info', \&extract_app_info );
    $NewAppExtractor->addHook('download_app_apk',\&download_app_apk);
    $NewAppExtractor->run($task_id);
}
elsif ( $task_type eq 'update_app' )    ##download updated app info and apk
{
    my $UpdatedAppExtractor = new AMMS::UpdatedAppExtractor(
        'MARKET'    => $market,
        'TASK_TYPE' => $task_type
    );
    $UpdatedAppExtractor->addHook( 'extract_app_info', \&extract_app_info );
    $UpdatedAppExtractor->run($task_id);
}

sub init_html_parser {
    my $html = shift;
    my $tree = new HTML::TreeBuilder;

    $tree->parse($html);

    return $tree;
}

sub get_page_list {
    my $html      = shift;
    my $page_mark = shift;
    my $pages     = shift;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    my ($page_info) = ( $html =~ /searchPage\(([^)]+)\)/ );
    $page_info =~ s/'//g;
    $page_info = decode_entities($page_info);
    my ( $base, $type, $start_page, $end_page ) = split /,/, $page_info;
    @{$pages} =
      map { $url_base . $base . "&page=" . $_; } $start_page .. $end_page;
    print Dumper($pages);
    $tree->delete;
}

sub trim_url {
    my $url = shift;
    $url =~ s#/$##;
    return $url;
}

sub extract_page_list {

    # accept args ref from outside
    my $worker = shift;
    my $hook   = shift;
    my $params = shift;
    my $pages  = shift;

    print "run extract_page_list ............\n";

    # create a html tree and parse
    my $web = $params->{web_page};
    eval { &get_page_list( $web, undef, $pages ); };
    if ($@) {
        print Dumper($pages);
        return 0 unless scalar @$pages;
    }
    return 1;
}

sub get_app_list {
    my $html      = shift;
    my $app_mark  = shift;
    my $apps_href = shift;
    if ( my @links =
        $html =~
m#div class="dianpu_sy_zgtj_nr_k2">.+?"(index\.php\?app=goods&id=\d+)"#gs
      )
    {
        for (@links) {
            if ( $_ =~ m/(\d+)/ ) {
                $apps_href->{$1} = trim_url($url_base) . "/" . $_;
            }
        }
        return 1;
    }
    return 0;
}

sub extract_app_from_feeder {

    # accept args ref from outside
    my $worker = shift;
    my $hook   = shift;
    my $params = shift;
    my $apps   = shift;

    return 0 unless ref($params) eq 'HASH';
    return 0 unless ref($apps)   eq 'HASH';
    return 0 unless exists $params->{web_page};

    print "run extract_app_from_feeder_list ............\n";

    return 0 if ref($params) ne 'HASH';
    return 0 unless exists $params->{web_page};
    eval {
        my $html = $params->{web_page};
        get_app_list( $html, undef, $apps );
    };
    if ($@) {
        warn( 'extract_app_from_feeder failed' . $@ );
        $apps = {};
        return 0;
    }
    return 0 unless scalar( %{$apps} );

    return 1;
}

sub get_app_url {
    my $html = shift;

    # html_string
    # match app url from html
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    my $node = $tree->look_down( id => 'goods_id' );
    return 0 unless $node;
    my $url = "/index.php?app=goods&id=" . $node->attr("value");
    $tree->delete;

    return trim_url($url_base) . $url;
}

sub get_icon {
    my $html = shift;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    my @nodes = $tree->look_down( class => "yyxq_right_top_left_kang" );
    return unless @nodes;
    my $icon = $nodes[0]->look_down( "_tag", "img" )->attr("src");

    $tree->delete;
    return $icon || undef;
}

sub get_price {
    my $html = shift;
    if ( $html =~ /应用价格(?:.*?)<span\s+(?:[^>]+)>(.*?)<\/span>/ ) {
        my $price_info = $1;
        if ( $price_info =~ /免费/ ) {
            return 0;
        }
        elsif ( $price_info =~ /(\d+)元/ ) {
            my $price = "RMB:" . $1;
            return $price;
        }
    }
    return 0;
}

sub get_description {
    my $html = shift;
    my $mark = shift;

    my $tree = HTML::TreeBuilder->new;
    $tree->parse($html);

    my @nodes = $tree->look_down( class => "yyxq_se_top_kang_nr1" );
    return unless @nodes;
    my $description = $nodes[0]->as_text;

    return $description;
}

sub get_apk_url {
    my $html = shift;
    my $mark = shift || 'down';

}

sub get_official_rating_stars {
    my $html = shift;

    # find stars for app
    # html_string:
    if ( $html =~ m/dylevel(\d{1,2})/s ) {
        return $1 / 2;
    }

    return undef;
}

sub kb_m {
    my $size = shift;

    # MB -> KB
    $size = $1 * 1024 if ( $size =~ s/([\d\.]+)(.*MB.*)/$1/ );
    $size = $1        if ( $size =~ s/([\d\.]+)(.*KB.*)/$1/ );

    # return byte
    return int( $size * 1024 );
}

#-------------------------------------------------------------

=head
 app_info:
	-author
	-app_url
	-app_name
	-icon
	-price
	-system_requirement
	-min_os_version
	-max_os_version
	-resolution
	-last_update
	-size
	-official_rating_stars
	-official_rating_times
	-app_qr
	-note
	-apk_url
	-total_install_times
	-official_rating_times
	-description
	-official_category
	-trustgo_category_id
	-related_app
	-creenshot
	-permission
	-status
 app_feeder
	category_id
=cut

sub get_current_version {
    my $html = shift;
    my $web  = shift;

    # mark is class => 'info'
    my $mark = shift || 'info';

    # find app install time and app info l-list
    # in this market,install time is in list[4]
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    my @nodes = $tree->look_down( class => $mark );

    my @list      = $nodes[0]->find_by_tag_name('li');
    my $version_s = $list[1]->as_text;

    #print $version_s;
    $version_s =~ m/软件版本(.*?)(\d\S+)/s;
    $tree->delete;
    return $2 || undef;
}

sub get_app_qr {
    return undef;
}

sub get_screenshot {
    my $html = shift;
    my $mark = shift || 'switch4';

    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    my @nodes = $tree->look_down( id => $mark );
    return [] unless @nodes;
    @nodes = $nodes[0]->look_down( class => "container" );
    my @tags = $nodes[0]->find_by_tag_name('a');

    #retrun a arrayref
    return [ map { $_->attr("href") } @tags ];
}

sub extract_app_info {

    # accept args ref from outside
    my $worker   = shift;
    my $hook     = shift;
    my $html     = shift;
    my $app_info = shift;

    # create a html tree and parse
    print "extract_app_info  run \n";

    my $tree = HTML::TreeBuilder->new;
    $tree->parse($html);

    #category and trustgo_category_id
    my $category = $tree->look_down( class => "main_wz_weizi" );
    my @nodes = $category->find_by_tag_name("a");
    $app_info->{official_category} = $nodes[2]->as_text;
    if ( defined $category_mapping{ $app_info->{official_category} } ) {
        $app_info->{trustgo_category_id} =
          $category_mapping{ $app_info->{official_category} };
    }

    #app_name
    my $category_text = decode_entities( $category->as_HTML );
    if ( $category_text =~ />([^>]+)<\/div>/ ) {
        $app_info->{app_name} = $1;
    }

    #official_rating_stars
    if ( $html =~ m/dylevel(\d{1,2})/s ) {
        $app_info->{official_rating_stars} = $1 / 2;
    }

    #total_install_times
    if ( $html =~ /下载次数.+?"txt_blue">(\d+)<\/span>/s ) {
        my $install_times = $1;
        $app_info->{total_install_times} = $install_times;
    }

    #last_update
    if( $html =~ /发布时间(?:.*?)(\d{4}-\d{1,2}-\d{1,2})/s){
        $app_info->{last_update} = $1;
    }
    #last_update
=pod
    if ( $html =~ m/发布时间<\/strong>(.*?)<strong>/ms ) {
        my $time_stamp = rtrim($1);
        $app_info->{last_update} = $time_stamp;
    }
=cut

    eval {

        # TODO get note 'not find'
        {
            no strict 'refs';
            foreach my $meta (@app_info_list) {

                # dymic function invoke
                # 'get_author' => sub get_author
                # 'get_price'  => sub get_price
                my $ret = $app_info->{$meta} =
                  &{ __PACKAGE__ . "::get_" . $meta }($html);
                if ( defined($ret) ) {
                    $app_info->{$meta} = $ret;
                }
                next;
            }

            if (
                defined( $category_mapping{ $app_info->{official_category} } ) )
            {
                $app_info->{trustgo_category_id} =
                  $category_mapping{ $app_info->{official_category} };
            }
            else {
                my $str = "Out of TrustGo category:" . $app_info->{app_url_md5};
                open( OUT, ">>/root/outofcat.txt" );
                print OUT "$str\n";
                close(OUT);
                die "Out of Category";
            }
        }
    };

    #current_version apk_url

    &get_app_info_by_ajax($app_info);

    #    use Data::Dumper;
    #    print Dumper $app_info;

    $app_info->{status} = 'success';
    if ($@) {
        $app_info->{status} = 'fail';
    }

    return scalar %{$app_info};
}

sub get_content {
    my $html = shift;
    use FileHandle;
    use open ':utf8';
    my $content = do {
        local $/ = '</html>';
        my $fh = new FileHandle($html) || die $@;
        <$fh>;
    };

    return $content;
}

sub get_app_info_by_ajax {
    my $app_info = shift;
    my $url      = $app_info->{app_url};
    my ($id) = ( $url =~ /id=(\d+)/ );
    my $request_url =
"http://www.189store.com/index.php?app=download&act=info&id=$id&type=1&isBrew=0&chargeType=3";
    if ( ! &get_login) {
        &post_login;
    }
    my $res = $ua->get($request_url);
    if ( $res->is_success ) {
        my $content = decode_json( $res->content );
        &process_app_info_ajax_content( $content->{html}, $app_info );
    }
    else {
        print "get download info error, response status", $res->status_line;
    }
}

sub download_app_apk {

    my $self      = shift;
    my $hook_name = shift;
    my $apk_info  = shift;

    my $apk_file;
    my $md5 = $apk_info->{'app_url_md5'};
    my $apk_dir =
      $self->{'TOP_DIR'} . '/'
      . get_app_dir( $self->getAttribute('MARKET'), $md5 ) . '/apk';
    my $cookie_jar = HTTP::Cookies->new( file => $cookie_file, );
    $cookie_jar->{ignore_discard} = 1;
    $cookie_jar->load($cookie_file);

    my $downloader = new AMMS::Downloader;
    $downloader->header( { Referer => $apk_info->{'app_url'} , Host => $market} );
    $downloader->{USERAGENT}->agent("Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.1 (KHTML, like Gecko) Chrome/14.0.835.186");
    $downloader->{USERAGENT}->max_redirect(1);
    $downloader->{USERAGENT}->cookie_jar($cookie_jar);

    if ( $apk_info->{price} ne '0' ) {
        $apk_info->{'status'} = 'paid';
        return 1;
    }
    eval {
        rmtree $apk_dir if -e $apk_dir;
        mkpath $apk_dir;
    };
    if ($@) {
        $self->{'LOGGER'}->error(
            sprintf( "fail to create directory,App ID:%s,Error: %s", $md5, $@ )
        );
        $apk_info->{'status'} = 'fail';
        return 0;
    }
    $downloader->timeout(
        $self->{'CONFIG_HANDLE'}->getAttribute('ApkDownloadMaxTime') );
    $apk_file =
      $downloader->download_to_disk( $apk_info->{'apk_url'}, $apk_dir, undef );
    if ( !$downloader->is_success ) {
        $apk_info->{'status'} = 'fail';
        return 0;
    }

    my $unique_name = md5_hex("$apk_dir/$apk_file") . "__" . $apk_file;

    rename( "$apk_dir/$apk_file", "$apk_dir/$unique_name" );

    $apk_info->{'status'}          = 'success';
    $apk_info->{'app_unique_name'} = $unique_name;

    return 1;
}

sub process_app_info_ajax_content {
    my ( $content, $app_info ) = @_;
    $content =~ s/\\(\\)?(?!u)//g;
    $content =~ s/\\u([0-9a-fA-F]{4})/pack("U",hex($1))/ge;
    $content =~ s/(<table.*?<\/table>).*/$1/;
    my $tree = HTML::TreeBuilder->new;
    $tree->parse($content);
    my @tr_tags = $tree->look_down( "_tag", "tr" );

    #may have many version and apk_urls,what to do ?
    my @platforms;
    my @versions;
    my @file_size;
    my @down_urls;
    foreach my $tr (@tr_tags) {
        my @td_tags = $tr->find_by_tag_name("td");
        next if not scalar(@td_tags);
        push @platforms, $td_tags[2]->as_text if ref $td_tags[2];
        push @versions,  $td_tags[3]->as_text if ref $td_tags[3];
        push @file_size, $td_tags[4]->as_text if ref $td_tags[4];
        if(ref $td_tags[5]){
            my $down_load_url = $td_tags[5]->find_by_tag_name("a");
            push @down_urls, $url_base."/".$down_load_url->attr("href") if ref $down_load_url;
        }
    }
    $app_info->{current_version} = $versions[0];
    $app_info->{size} = &kb_m($file_size[0]);
    $app_info->{apk_url} = $down_urls[0] if $app_info->{price} eq "0";
}

sub get_login {
    my $res_login = $ua->get(
"http://www.189store.com/index.php?app=ajax&act=getUserInfo&js=1&ReturnURL="
    );
    if ( $res_login->is_success ) {
        if ( $res_login->content =~ /mall_user_logout/m ) {
            return 1;
        }
        elsif ( $res_login->content =~ /value="?([^"]+)"?>/) {
            $login_key = $1;
            return 0;
        }
    }else{
    
        print $res_login->error_as_HTML;
    }

}

sub post_login {
    my $url = "http://www.189store.com/index.php?app=member&act=login";
    my $res = $ua->post(
        $url,
        [
            user_name => encode_base64( '13851576936' . $login_key ),
            password  => encode_base64( 'stone801213' . $login_key ),
            is_ajax   => 1,
            ReturnURL => '',
        ]
    );
    if ( $res->status_line =~ /200/ ) {
        print $res->content, "\n";
    }

}

1;
__END__
