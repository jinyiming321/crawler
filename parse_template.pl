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
#       AUTHOR: 
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

# use AMMS Module
use AMMS::Util;
use AMMS::AppFinder;
use AMMS::Downloader;
use AMMS::NewAppExtractor;
use AMMS::UpdatedAppExtractor;

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

my $market      = ''
my $url_base    = ''
#my $downloader  = new AMMS::Downloader;

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
die "\nplease check config parameter\n" 
    unless init_gloabl_variable( $conf_file );

# define a app_info mapping
# because trustgo_category_id is related with official_category
# so i remove it from this mapping
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
        note                    => \&get_note,
        apk_url                 => \&get_apk_url,
        total_install_times     => \&get_total_install_times,
        description             => \&get_description,
        official_category       => \&get_official_category,
        trustgo_category_id     => '',
        related_app             => \&get_related_app,
        creenshot               => \&get_screenshot,
        permission              => \&get_permission,
        status                  => ''
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

our $AUTHOR     = '酷安网';

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

    $tree->delete;
    return $icon || undef;
}

sub get_app_name{
    my $html = shift;
    my $mark = shift||'apptitle';
    my $app_name;
    
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    $tree->delete;
    return $app_name || undef;
}

sub get_price{ 
    return 0;
}

sub get_description{
    my $html = shift;

    if( $html =~ m{(应用详细介绍.*?)</div>}s ){
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
    
    if(my @date = $content =~ m/(\d{4}-\d{2}-\d{2})/sg){
        my $last_update = $date[-1];
        return $last_update;
    }
    return ;
}

sub get_apk_url{
    my $html = shift;
    my $mark = shift||'down';

    # find apk_url by html_tree
    # html content:
=pod

=cut

    return $url || undef;
}

sub get_official_rating_stars{
    my $html  = shift;
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    my @nodes = $tree->look_down( class => 'ratingstars' );
    return unless @nodes;
    my $rating_star;

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
    my @nodes = $tree->look_down( id => 'navbar' );
    return unless @nodes;
    
    my $official_category ;

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

    my $version ;

    return $version;

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
    my $qr;
    $tree->delete;

    return trim_url($url_base).$qr||undef;
}
sub get_screenshot{
    my $html = shift;
    my $mark = shift||'screen-div';

    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    # return []
    return ;
}


#-------------------------------------------------------------
sub get_permission{
    my $html = shift;
    my $mark = shift||'row';

    # the list needed to return 
    my $permission = [];
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    # find permission
    my @nodes = $tree->look_down( class => $mark );
    return [] unless @nodes;


    return $permission;
}

sub get_related_app{
    my $html = shift;
    
    # a related apps 
    my $related_apps = [];
    # create a empty html tree
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);

    my @nodes = $tree->look_down( class => 'appinfo');
    return unless @nodes;

    return  $related_apps;
}

sub extract_app_info
{
    # accept args ref from outside
    my $worker	 = shift;
    my $hook	 = shift;
    my $html     = shift;
    my $app_info = shift;

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
    my @nodes = $tree->look_down( class => 'ratinglabel' );
    return unless @nodes;
    my $rating_times;
    $tree->delete;
    return $rating_times;
}

1;
__END__




