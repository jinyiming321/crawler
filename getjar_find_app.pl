
#download url
BEGIN{unshift(@INC, $1) if ($0=~m/(.+)\//); $| = 1; }
use strict; 
use utf8; 
use Carp;
use HTML::TreeBuilder;
use DBI;
use Encode;
use Data::Dumper;
use Getopt::Std;
use Digest::MD5 qw(md5_hex);
use Encode;

use constant SUB_TYPE => ref sub {};
use AMMS::Util;
use AMMS::Downloader;

binmode STDOUT, ":utf8";

my $market="getjar.com";
#my $word_list="./wordlist/5000words.txt";
#$word_list=$ARGV[0] if defined $ARGV[0];

my $conf_file = $ARGV[0];

my %dbh_info = do{
    use FileHandle;
    my %hash;
    my $fh = new FileHandle($conf_file) or die $@;
    while(<$fh>){
        if(/^(mysql\S+)\t*\s*=\s*\t*(.+)/i){
            $hash{$1} = $2;
            next;
        }
    }
    close( $fh);
    %hash;
};

my $dsn =
    "dbi:mysql:database=$dbh_info{MySQLDb};host=$dbh_info{MySQLHost};port=3306";
my $user = $dbh_info{MySQLUser};
my $pass = $dbh_info{MySQLPasswd};

my @feeder_url = (
    'http://www.getjar.com/mobile-music-applications-for-android-os',
);

my $dbh = DBI->connect( $dsn,$user,$pass ) or die $@;
$dbh->do( "set names 'utf8'");

my $downloader;
my $base_url = "http://www.getjar.com";
my @page_list;
my $apps_hashref = {};
$downloader = new AMMS::Downloader;
$downloader->timeout(120);

foreach my $feeder_url( @feeder_url ){
    my $content ;
    $content = $downloader->download($feeder_url);   
    push @page_list,$feeder_url;
    extract_app_list( $content );
    find_pages( $downloader,decode_utf8($content),\@page_list );
}

print Dumper \@page_list;

die "get page list failed" if @page_list == 0;

insert_app_source();

sub extract_app_list{
    my $content = shift;
    my $tree = new HTML::TreeBuilder;
    eval{
        $tree->parse( 
            decode_utf8( $content )
        ) or die "can't parse ";
        $tree->eof;

        my $category =
            ($tree->look_down( class => 'category_label'))[0]->as_text;

        my @nodes = $tree->look_down( class => 'free_app_name' );
        return unless @nodes;
        
        foreach (@nodes){
            my $href = $_->attr('href');
            my $app_url = $base_url.$href;
            $app_url =~ m!(.+?mobile/(\d+)/.+?)\?!i;
            my $self_id = $1;
            $apps_hashref->{$2} = $1;
            save_extra_info( md5_hex($1),$category );
        }
    };
    if( $@ ){
        warn $@;
        $tree->delete;
        return 0;
    }
    $tree->delete;
    return 0 if scalar ( keys %$apps_hashref );
    return 1;
}

sub find_pages{
    my ( $downloader,$page_arrayref,$content ) = ( shift,pop,shift );
    my $tree = new HTML::TreeBuilder;
    $tree->parse($content);
    $tree->eof;

    # find more tag;
    # div id="appsmore" class="more_bar"
    my @nodes = $tree->look_down( id => 'appsmore' );

    return unless @nodes;
    my $next_page =
        $base_url.[$nodes[0]->find_by_tag_name('a')]->[0]->attr('href');
    # ref=0&lvt=1318045707&sid=84dg0023wqkqbjr4
    $tree->delete;

    push @{$page_arrayref},$next_page;
    
    while( my $content = $downloader->download($next_page) ){
        extract_app_list( $content );
        my $subtree = new HTML::TreeBuilder;
        $subtree->parse($content);
        $subtree->eof;
        eval{
            my @nodes = $subtree->look_down( id => 'row_right_arrow');
            my @tags = $nodes[0]->find_by_tag_name('a');
            $next_page = $base_url.$tags[0]->attr('href');
            push @{$page_arrayref},$next_page;
            $subtree->delete;
        };
        my $error = $@;
        if( $error ){
            $subtree->delete;
            last;
        }
    }
    return 1;
}

sub insert_app_source{
    my 	$sql='insert into app_source set '.
            ' app_url_md5=?'.
            ',app_self_id=?'.
            ',market_id=18'.
            ',feeder_id=0'.
            ',app_url=?'.
            ',status="undo"';
    print "sql is : $sql\n";
    my $sth = $dbh->prepare($sql);

    foreach (keys %$apps_hashref ){
        my $app_self_id=$_;
        chomp($app_self_id);
        my $app_url = $apps_hashref->{$_};
        $sth->execute(md5_hex($app_url),$app_self_id,$app_url) or warn 
            $sth->errstr;
        print "run sql finish\n";
    }
}

sub save_extra_info{
    my $app_url_md5 = shift;
    my $data = shift;
    my $sql = "replace into app_extra_info(app_url_md5,information) values(?,?)"; 
    my $sth = $dbh->prepare($sql);
    $sth->execute($app_url_md5,$data) or warn $sth->errstr;
}


exit 1;

