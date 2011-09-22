#!/usr/bin/perl 
#===============================================================================
#
#         FILE: coolapk
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

=pod
# use AMMS Module
use AMMS::Util;
use AMMS::AppFinder;
use AMMS::Downloader;
use AMMS::NewAppExtractor;
use AMMS::UpdatedAppExtractor;
=cut

# Export function for test
require Exporter;
our @ISA     = qw(Exporter);
our @EXPORT  = qw(
    extract_page_list 
    extract_app_from_feeder 
    extract_app_info
);

my $task_type   = $ARGV[0];
my $task_id     = $ARGV[1];
my $conf_file   = $ARGV[2];

my $market      = 'www.coolapk.com';
my $url_base    = 'http://www.coolapk.com';
#my $downloader  = new AMMS::Downloader;

my $login_url = 'http://www.coolapk.com/do.php?ac=login';
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

# check args 
unless( $task_type && $task_id && $conf_file ){
    die $usage;
}

# check configure
=pod
die "\nplease check config parameter\n" 
    unless init_gloabl_variable( $conf_file );
=cut

# define a app_info mapping
# because trustgo_category_id is related with official_category
# so i remove it from this mapping
# modify record :
# 	2011-09-19 add support for screenshot related_app official_rating_starts
our %app_map_func = (
        author                  => \&get_author, 
        app_name                => \&get_app_name,
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
        apk_url                 => \&get_apk_url, #TODO write cookie code
        total_install_times     => \&get_total_install_times,
        description             => \&get_description,
        official_category       => \&get_official_category,
        trustgo_category_id     => '',
        related_app             => \&get_related_app,
        creenshot               => \&get_screenshot,
        permission              => \&get_permission,
        status                  => '',
        category_id             => '',
);

our @app_info_list = qw(
        author                  
        app_name                
        icon                    
        price                   
        system_requirement      
        min_os_version          
        max_os_version          
        resolution              
        last_update             
        size                    
        official_rating_stars   
        official_rating_times   
        app_qr                  
        note                    
        apk_url                 
        total_install_times     
        official_rating_times   
        description             
        official_category       
        trustgo_category_id     
        related_app             
        creenshot               
        permission              
        status                  
        category_id             
    );

our %category_mapping=(
    "系统管理"    => 2206,
    "网络浏览"    => 2210,
    "影音媒体"    => 7,
    "文字输入"    => 2217,
    "安全防护"    => 23,
    "社区聊天"    => "400,18",
    "信息查询"    => 22,
    "导航地图"    => "13,2105",
    "通讯辅助"    => 2209,
    "阅读资讯"    => "14,1",
    "生活常用"    => 19,
    "财务工具"    => 2, 
    "学习办公"    => "5,16",
    "其他分类"    => 0,
    "主题图像"    => 1203,
    "棋牌游戏"    => 802,
    "益智休闲"    => 806,
    "体育运动"    => 814,
    "竞速游戏"    => 811,
    "射击游戏"    => 821,
    "角色扮演"    => 812,
    "冒险游戏"    => 800,
    "模拟经营"    => 813,
    "策略塔防"    => 815,
    "养成游戏"    => 813,
    "格斗游戏"    => 825,
    "飞行游戏"    => 826,
    "其他游戏"    => 8,
    "音乐游戏"    => 809,
    "动作游戏"    => 823,
	);

our $PAGE_MARK  = 'pagebar';
our $IMG        = 'img';
our $SRC        = 'src';
our $LINK_TAG   = 'a';
our $LINK_HREF  = 'href';
our $APPS_MARK  = 't';
our $APP_MARK   = 'col2';
our $AUTHOR     = '酷安网';
our $ICON_MARK  = 'brief';
our $DESC_MARK  = 'screen';
our $SIZE_MARK  = 'info';

=pod
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
    $NewAppExtractor->run($task_id);
}
elsif( $task_type eq 'update_app' )##download updated app info and apk
{
    my $UpdatedAppExtractor= new AMMS::UpdatedAppExtractor('MARKET'=>$market,'TASK_TYPE'=>$task_type);
    $UpdatedAppExtractor->addHook('extract_app_info', \&extract_app_info);
    $UpdatedAppExtractor->run($task_id);
}
=cut


sub FIRST_NODE			(){		0		}

sub init_html_parser{
    my $html = shift;
    my $tree = new HTML::TreeBuilder;

    $tree->parse($html);

    return $tree;
}

sub get_page_list{
    my $html        = shift;
    my $page_mark   = shift;
    my $pages       = shift;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    # <a href="/apk/downloads/list-56/?p=56&sort=lastdown">最末页</a>

    my @nodes = $tree->look_down( id => 'pagelist' );
    Carp::croak('not find page_make : pagelist ') unless scalar(@nodes);

    my @tags = $nodes[0]->find_by_tag_name('a');
    return unless @tags;
    my $last_page = $tags[-1]->attr('href');

    ( my $needed_s_url = $last_page ) =~ s/list-(\d+)/'list-'.'$num'/e;
    my $total = $1;
    $needed_s_url =~ s/p=\d+/'p='.'$num'/e;

    # save pages to pages arrayref
    @{ $pages } = map {
        ( my $temp = $needed_s_url ) =~ s/\$num/$_/g; 
        trim_url($url_base).$temp;
    } (1..$total);
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
        &get_page_list( $web,undef,$pages );
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

    map{
    my @tags = $_->find_by_tag_name('a');
    # <a target="_blank" href="/apk-3965-com.lingdong.quickpai.compareprice.ui.acitvity/">?ì??1o?????÷</a>
    return unless @tags;

    foreach my $tag(@tags){
        my $link = $tag->attr('href');
        $link =~ m/apk-(\d+)/;
        $apps_href->{$1} = trim_url($url_base).$link;
    }
    } @nodes;

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
    return 0 if ref($params) ne 'HASH';
    return 0 unless exists $params->{web_page};

    eval{
    	my $html = $params->{web_page};
        get_app_list( $html,'t',$apps );
    };
    if($@){
        warn('extract_app_from_feeder failed'.$@);
        $apps = {};
	    return 0
    }
    return 0 unless scalar( %{ $apps } );
	
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
    my @tags = $nodes[0]->find_by_tag_name('img');
    my $src = $tags[0]->attr('src');

    # img string
    # <img src="/qrcode/18387.jpg">
    $tree->delete;

    if( $src =~ m{/(\d+)\.jpg}i ){
        return trim_url($url_base).'/soft/'.$1.'.html';
    }

    return undef;
}

sub get_icon{
    my $html = shift;
    
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
#    return unless @nodes;

    #look down brief label;
    my @nodes = $tree->look_down( class => 'apptitle');
    return unless @nodes;

    my @tags = $nodes[0]->find_by_tag_name('img');
    my $icon = $url_base.$tags[0]->attr('src');

    # delete what I have done
    $tree->delete;
    return $icon || undef;
}

sub get_app_name{
    my $html = shift;
    my $mark = shift||'apptitle';
    
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    # find app name for app_info
    # html_string:
    # mark class = "qnav"
=pod
<div class="apptitle">
<img class="applo
<h1>MyBackup Pro:全能备份专家 3.0.0已付费版</h1>
=cut
    my @nodes = $tree->look_down( class => $mark );
    return unless @nodes;

    my @tags = $nodes[0]->find_by_tag_name('h1');
    my $app_name = $tags[0]->as_text;

    # delete what I ever done
    $tree->delete;
    return $app_name || undef;
}

sub get_price{ 
    return 0;
}

sub get_description{
    my $html = shift;

=pod
start 应用详细介绍 
end   酷安网点评
<div class="appinfo1">
<h2>应用详细介绍 · · ·</h2>
<div>
<p>点心桌面DXHome DXR是创新工场推出的一款适用于安卓系统的桌面软件，内置海量超炫桌面主题，以及丰富桌面滑屏特效。</p>
<p> 功能特性：</p>
<p> 1、 丰富炫酷桌面主题（点击菜单-主题更换）</p>
<p> 2、 屏幕切换特效（点击菜单&mdash;桌面设置&mdash;滑屏效果）</p>
<p> 3、 应用管理（抽屉中，长按应用图标即弹出操作菜单，轻拖删除或添加至桌面）</p>
<p> 4、 文件夹操作（将桌面图标拖动重叠，可快速新建文件夹）</p>
<p>
<p>1、新增 主题推荐小部件-打开主题推荐，海量主题滚滚而来！</p>
<p></p>
<p> </p>
<p>2、新增 快乐女生、老北京，植物大战僵尸主题！</p>
<p></p>
<p> </p>
<p>3、优化 编辑状态UI</p>
<p></p>
<p> </p>
<p>4、优化 抽屉滑动性能</p>
<p></p>
<p> </p>
<p>5、修复 多处“强制关闭”问题</p>
</div>
<h2>酷安网点评 · · ·</h2>
=cut
    if( $html =~ m{(应用详细介绍.*?)</div>}s ){
        #( my $desc = $1 ) = ~ s/[\000-\037]//g;
        my $desc = $1;
        $desc =~ s/[\000-\037]//g;
        $desc =~ s/<h\d+>//g;
        $desc =~ s/<\/h\d+>//g;
        $desc =~ s/<br>//g;
        $desc =~ s/<\/br>//g;
        $desc =~ s/<br\s+\/>/\n/g;
        $desc =~ s/\r//g;
        $desc =~ s/\n//g;
        $desc =~ s/<p>//g;
        $desc =~ s#</p>##g;
        $desc =~ s#<h2>##g;
        $desc =~ s#</h2>##g;
        return $desc;
    }

    return 
}

sub get_size{
    my $html = shift;
    # mark is class => 'info'
    my $mark = shift||'appdetails';

=pod
<span>
<em>大小：</em>
3.06 MB
</span>
=cut
    if( $html =~ m{em>大小.*?(\d.*?MB)}s ){
        my $size = $1;
        return kb_m($size);
    }
    return 
}

sub get_total_install_times{
    my $html = shift;
=pod
<span class="alt">
约2100次下载，
<a target="_self" href="#comment">11次评论</a>
=cut
    if( $html =~ m/(\d+)次下载/s){
        my $install_times = $1;
        return $install_times;
    }

    return undef;
}

sub get_last_update{
    my $html = shift;
=pod
<h2>更新记录 · · ·</h2>
<div class="changelog">
<span>
2010-09-04
<em>收录版本：0.7付费版</em>
=cut
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    my @nodes = $tree->look_down( class => 'changelog' );
    return unless @nodes;
    
    my @tags = $nodes[0]->find_by_tag_name('span');
    my $content = $tags[0]->as_text;
    $tree->delete;

    if(my @date = $content =~ m/(\d{4}-\d{2}-\d{2})/sg){
        my $last_update = $date[-1];
        return $last_update;
    }
    return ;
}

sub get_cookie{
    my $cookie_file = shift;

    my $login_html  = get($login_url);

    my %info = $login_html =~ m{<input type="hidden" name="(.+?)" value="(.*?)"}sg;
    my $cookie_jar = HTTP::Cookies->new(
        file        => $cookie_file,
        autosave    => 1,
    );

    my $ua = LWP::UserAgent->new;
    my $username ="jinyiming321";
    my $pwd ="19841002";
    
    $ua->cookie_jar($cookie_jar);
    $ua->agent("Mozilla/4.0");
    #$res = $ua->get($url);
    
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
    use Encode;
    if(Encode::decode_utf8($res->content) =~/登录成功/){
        return 1;
    }

    return 
}

sub get_apk_url{
    my $html = shift;

    # <img src="/qr.php?sid=MjU0NiwxOCwxNiwxLCw4M2RlMmExNg==" class="qrcode">
    # <img class="qrcode" src="/qr.php?sid=MjU0NiwxOCwxNiwxLCw4M2RlMmExNg==">
    $html =~ m{img class="qrcode".*?sid=(\w+?==)}s;
    my $sid = $1;
    {
        no strict 'refs';
        ${ __PACKAGE__."::"."SID" } = \$sid;
    }

    use HTTP::Request;
    use HTTP::Cookies;
    use LWP::UserAgent;
    use LWP::Simple;

    my $cookie_file = 'cookie.coolapk';
    unless( -e $cookie_file ){
        return unless get_cookie();
    }

    my $ua = LWP::UserAgent->new;
    
    $ua->cookie_jar($cookie_file);
    $ua->agent("Mozilla/4.0");
    get_cookie($cookie_file) unless -e $cookie_file;
    my $retry = 0;
    DOWN_LOAD_APK:
    $ua->cookie_jar($cookie_file);

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
            d       => 1316691530671,
        ]
    );
    # {"type":"js","success":true,"data":"window.location.href='\/dl?dl=1&sid=MjU0NiwxOCwxNiwxLCw4M2RlMmExNg==&authimg=&hash=1f5ed7b6';","dataTarget":"","msg":"\u5f00\u59cb\u4e0b\u8f7d..","msgTarget":"","alert":false}
    if( $res->status_line =~ m/200/ ){
        if( $res->content =~ m/href='(.+?)&/s ){
            my $download = $1;
            $download =~ s/\\//g;
            return $url_base.$download;
        }
    }else{
        get_cookie && goto DOWN_LOAD_APK unless $retry;
        ++$retry;
        return;
    }
}

sub get_official_rating_stars{
    my $html  = shift;
    # find stars for app
    # html_string:
=pod
<span class="ratingstars" rank="4.0" star="4" style="background-position: 0px -80px;">
    <a class="s1" params="id=3446&star=1" onclick="doAjaxPost(this,'voteapk');" href="javascript:;"></a>
    <a class="s2" params="id=3446&star=2" onclick="doAjaxPost(this,'voteapk');" href="javascript:;"></a>
    <a class="s3" params="id=3446&star=3" onclick="doAjaxPost(this,'voteapk');" href="javascript:;"></a>
    <a class="s4" params="id=3446&star=4" onclick="doAjaxPost(this,'voteapk');" href="javascript:;"></a>
    <a class="s5" params="id=3446&star=5" onclick="doAjaxPost(this,'voteapk');" href="javascript:;"></a>
    <em>4.0</em>
</span>
=cut
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    my @nodes = $tree->look_down( class => 'ratingstars' );
    return unless @nodes;

    my @tags = $nodes[0]->find_by_tag_name('em');
    my $rating_star = $tags[0]->as_text();

    return $rating_star ||undef;
}

sub kb_m{
    my $size = shift;

    # MB -> KB 
    $size = $1*1024 if( $size =~ s/([\d\.]+)(.*MB.*)/$1/ );
    $size = $1  if( $size =~ s/([\d\.]+)(.*KB.*)/$1/ );

    # return byte
    return int($size*1024);
}

sub get_official_category{
    my $html = shift;

    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
=pod
<div id="navbar">
<a href="http://www.coolapk.com/">酷安网</a>
&gt;
<a href="/apk/">Android软件</a>
&gt;
<a href="/apk/themes/">主题美化</a>
&gt; Go Launcher桌面 1.41
=cut

    my @nodes = $tree->look_down( id => 'navbar' );
    return unless @nodes;
    
    my @tags = $tree->find_by_tag_name('a');
    my $official_category = $tags[2]->as_text;

    return $official_category||'unknown';
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

sub get_current_version{
    my $html = shift;
    my $web  = shift;
    # mark is class => 'info'
    my $mark = shift||'info';

    # find app install time and app info l-list
    # in this market,install time is in list[4]
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    my @nodes = $tree->look_down( class => $mark );

    my @list = $nodes[0]->find_by_tag_name('li');
    my $version_s = $list[1]->as_text ;
    #print $version_s;
    $version_s =~ m/软件版本(.*?)(\d\S+)/s;
    $tree->delete;
    return $2||undef;
}

sub get_app_qr{
    my $html = shift;
    my $mark = shift||'down';

    # html sinppet
=pod
<img src="/qr.php?sid=MzQ0NiwxOCw2LDEsLGNiNDdkOTcx" class="qrcode">
=cut
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    my @nodes = $tree->look_down( class => 'qrcode' );
    return 0 unless @nodes;

    # fetch img from this snippet
    my $qr = $nodes[0]->attr('src');
    $tree->delete;

    return trim_url($url_base).$qr||undef;
}
sub get_screenshot{
    my $html = shift;
    my $mark = shift||'screen-div';

    # screenshot is 'screen-div'
    # fetch src
    # html_string
=pod
=cut
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    my @nodes = $tree->look_down( id => 'screencount');
    (my $count = $nodes[0]->as_text) =~ m{\d+/(\d+)};
    $count = $1;
=pod
<div id=> 'screenpreview'
<img alt="截图预览" src="/~/uploads/allimg/110906/2_110906145600_1.jpg" style="width: 240px; display: inline; height: 360px;">
=cut
    my @img= [$tree->look_down( id => 'screenpreview' )]->[0]
        ->find_by_tag_name('img');
    my $src = $img[0]->attr('src');
    return [ map{
            $src =~ s#(\d+)(?=jpg)#$count#e;
            trim_url($url_base).$src;
        }(1..$count)
    ]
}


#-------------------------------------------------------------
sub get_permission{
    my $html = shift;
    my $mark = shift||'row';

    # the list needed to return 
    my $permission = [];
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    use HTTP::Request;
    use HTTP::Cookies;
    use LWP::UserAgent;
    use LWP::Simple;
    my $sid = ${__PACKAGE__."::"."SID"};
    ${__PACKAGE__."::"."APP_URL"} =~ m/(\d+)/;
    my $app_id = $1;
    my $cookie_file = 'cookie.coolapk';
    unless( -e $cookie_file ){
        return unless get_cookie();
    }

    my $ua = LWP::UserAgent->new;
    
    $ua->cookie_jar($cookie_file);
    $ua->agent("Mozilla/4.0");
    get_cookie($cookie_file) unless -e $cookie_file;
    my $retry = 0;
    DOWN_LOAD_PERM:
    $ua->cookie_jar($cookie_file);

    my $perm_download_url = "http://www.coolapk.com/do";
    # http://www.coolapk.com/do.php?ac=ajax&inajax=1&op=viewpermissions&d=1316693842750
    # header
    #   d	1316691530671
    #   inajax	1
    #   op	download
    #   sid	MjU0NiwxOCwxNiwxLCw4M2RlMmExNg==
    # 
    my $res = $ua->post( 
        $perm_download_url,[
            ac      => 'ajax',
            id      => $app_id,
            sid     => $sid,
            inajax  => 1,
            op      => 'viewpermissions',
            d       => 1316691530671,
        ]
    );
    if( $res->status_line =~ m/200/ ){
        # TODO GET PERMISSION
        return $permission;
    }else{
        get_cookie && goto DOWN_LOAD_APK unless $retry;
        ++$retry;
        return;
    }

    return $permission;
}

sub get_related_app{
    my $html = shift;
    
    # a related apps 
    my $related_apps = [];
    # create a empty html tree
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

=pod
div class="appinfo">
    <p>
    <em>免费</em>
    <strong>
    <a target="_blank" href="/apk-4018-com.icbc/">工行手机银行 1.0.0.1</a>
</strong>
=cut
    my @nodes = $tree->look_down( class => 'appinfo');
    return unless @nodes;

    for(@nodes){
        push (
            @{ $related_apps },
            $url_base.[$_->find_by_tag_name('a')]->[0]->attr('href')
        );
    }

    return  $related_apps;
}

sub extract_app_info
{
    # accept args ref from outside
    my $worker	 = shift;
    my $hook	 = shift;
    my $html     = shift;
    my $app_info = shift;
    
    { 
        no strict 'refs';
        *{ __PACKAGE__."::"."APP_URL" } = \$app_info->{app_url};
    }

    # create a html tree and parse
    print "extract_app_info  run \n";
    use Encode;
    $html = Encode::decode_utf8($html);

    eval{
        # TODO get note 'not find'
        {
            no strict 'refs';
            foreach my $meta( @app_info_list ){
                # dymic function invoke
                # 'get_author' => sub get_author
                # 'get_price'  => sub get_price
                next unless ref($app_map_func{$meta}) eq 'CODE';
                my $ret = &{ $app_map_func{$meta} }($html);
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

sub run{
    use LWP::Simple;
    my $content = get('http://www.anfone.com/soft/19389.html');
=pod
    my $worker	 = shift;
    my $hook	 = shift;
    my $html     = shift;
    my $app_info = shift;
=cut
    my $app_info = {};
    extract_app_info( undef,undef,$content,$app_info );

}
sub get_system_requirement{
    my $html = shift;

    {
        no strict 'refs';
=pod
<em>支持ROM：</em>
1.6/2.0/2.1/2.2/2.3
=cut
        if($html =~ m{支持ROM.+?(\d+.+?)</span>}s){
            my $rom_version = $1;
            my @versions = split('/',$rom_version);
            if( scalar @versions ){
                ${ __PACKAGE__."::"."min_os_version" } = $versions[0];
                ${ __PACKAGE__."::"."max_os_version" } = $versions[-1];
            }
            return $rom_version;
        }
    }
    return
}

sub get_min_os_version{
    {
        no strict 'refs';
        my $min_os_version = ${ __PACKAGE__."::"."min_os_version" };
        return ref($min_os_version) ? $$min_os_version : undef;
    }
}

sub get_max_os_version{
    {
        no strict 'refs';
        my $max_os_version = ${ __PACKAGE__."::"."max_os_version" };
        return ref($max_os_version) ? $$max_os_version : undef;
    }
}

sub get_official_rating_times{
    my $html = shift;
   
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    # <span class="ratinglabel">135个评分：</span>
    my @nodes = $tree->look_down( class => 'ratinglabel' );
    return unless @nodes;

    $nodes[0]->as_text =~ m/(\d+)/;
    my $rating_times = $1;
    $tree->delete;
    return $rating_times;
}

1;
__END__



