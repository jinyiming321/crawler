#*****************************************************************************
# *     Program Title: get_sliderme_feeder.pl
# *    
# *     Description: 
# *         1) 
# *         2) 
# *         3) 
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
use LWP::UserAgent;
use Carp qw( croak );
use FileHandle;
use HTML::TreeBuilder;
use Encode;
use HTTP::Cookies;

my $base_url = 'http://slideme.org';
my $cache = 'slideme.html';
my $file_w = new FileHandle('>slideme.html' ) or die "can't open $@";
my @url_list;

my $map_file = 'slideme_map.txt';
my $map_w = new FileHandle(">$map_file")or die $@;
my $cookie_jar = HTTP::Cookies->new;
my $feed_w = new FileHandle(">slideme.url")|| die $@;

my $ua = new LWP::UserAgent;
$ua->agent('Mozilla/5.0');
$ua->timeout(60);
my $res = $ua->get($base_url."/applications");
while( not $res->is_success ){
    $res = $ua->get( $base_url );
}

my $cookie = $res->header('set_cookie');
my $header;

if( my $html = Encode::decode_utf8($res->content) ){
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    $tree->eof;
    
    my @tags= 
        $tree->look_down( 
            id => 'block-mobileapp_solr-mobileapp_solr_categories'
        )->find_by_tag_name('a');

    Carp::croak("can't find category label\n") unless @tags;
    foreach my $tag( @tags ){
        next unless ref $tag;
        my $link = $tag->attr('href');
        my $class = $tag->as_text();
        if( $class =~ m/"([^"]+)"/){
            $class =~ s/^\s+$//g;
        }
        $class =~ s/^\s+//g;
        $class =~ s/\s+$//g;
        $class =~ s/\W+$//g;
        $class =~ s/\d+$//g;
        print "'$class' => ''\n";
        print $map_w "'$class' => ''\n";
        print $feed_w $base_url.$link."\n";
    }
}



