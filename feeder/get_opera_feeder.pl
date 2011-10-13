#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use LWP::UserAgent;
use Carp qw( croak );
use FileHandle;
use HTML::TreeBuilder;
use Encode;
use HTTP::Cookies;

my %feeder = (
    'http://mobilestore.opera.com/AllCategories.jsp?sectionId=0&sortBy=rating&sortOrder=desc' => 1 
);
my %category_mapping = (
);

my $base_url = 'http://mobilestore.opera.com';
my $cache = 'opera.html';
my $file_w = new FileHandle('>opera.url' ) or die "can't open $@";
my @url_list;

my $map_file = 'opera_mapping.txt';
my $map_string = do {
    local $/ ='end';
    open FH,"<",$map_file ;
    <FH>
};
close FH;
my $map_w = new FileHandle(">>$map_file")or die $@;

my $ua = new LWP::UserAgent;
$ua->max_redirect(0);
$ua->timeout(60);
my $header ;
my $res = $ua->get("http://mobilestore.opera.com/SelectDevice.jsp");
if( $res->is_success ){
    my $cookie = $res->header('set-cookie');
    # JSESSIONID=F3FC72207A474D2D96540518EEDAB26D.jvm1; 
    if( $cookie =~ m/(JSESSIONID=[^;]+);/ ){
        $header = $1.";"."handango_device_id=2459;";
    }
}else{
    die "get cookie failed\n";
}
$ua->default_header( cookie => $header );

foreach my $key( keys %feeder ){
    eval{
    if( $key =~ m/http/ ){
        GET:
        if( my $res = $ua->get( $key ) ){
            my $content = $res->content;
            my $tree = new HTML::TreeBuilder;
            # block_button
            $tree->parse( Encode::decode_utf8($content) );
            $tree->eof;

            my @nodes = $tree->look_down( 'class' => 'block_button' );
            croak( "$@" ) unless @nodes;
            my @t = $nodes[0]->find_by_tag_name('a');
            for(@t){
                my $href = $_->attr('href');
                my $class = $_->attr('title');
                print $file_w $base_url.$href."\n";
#                if( my $count = grep /
#                print $map_w 
                print $file_w $base_url.$href."\n";
                print "class is $class\n";
                if( $map_string !~ m/.*?$class/s ){
                    print $map_w "'$class' => '',\n";
                }
                if( my $res= $ua->get($base_url.$href) ){
                    my $tree = new HTML::TreeBuilder;
                    my $web = Encode::decode_utf8($res->content);
                    $tree->parse( $web );
                    $tree->eof;
                    my @nodes = $tree->look_down( class => 'block_button' );
                    next unless @nodes;
                    my @t = $nodes[0]->find_by_tag_name('a');
                    foreach my $tag(@t){
                        my $title = $tag->attr('title');
                        my $link = $tag->attr('href');
                        print $file_w $base_url.$link."\n";
                        print "\t\t$title\n";
                        if( $map_string !~ m/.*?$title/s ){
                                print $map_w " '$title'   => '' ,\n";
                        }
                    }

                }
            }
        }
    }
    };
    if($@){
        warn $@
    }
}

close ( $file_w);



