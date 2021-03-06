#!/usr/bin/perl -w
#*****************************************************************************
# *     Program Title: get_handster_feeder.pl
# *    
# *     Description: This program is used to fetch handster.com's feeder url.
# *    
# *     Author: Yiming Jin
# *    
# *     (C) Copyright 2011-2014 TrustGo Mobile, Inc.
# *     All Rights Reserved.
# *    
# *     This program is an unpublished copyrighted work which is proprietary
# *     to TrustGo Mobile, Inc. and contains confidential information that is not
# *     to be reproduced or disclosed to any other person or entity without
# *     prior written consent from TrustGo Mobile, Inc. in each and every instance.
# *    
# *     WARNING:  Unauthorized reproduction of this program as well as
# *     unauthorized preparation of derivative works based upon the
# *     program or distribution of copies by sale, rental, lease or
# *     lending are violations of federal copyright laws and state trade
# *     secret laws, punishable by civil and criminal penalties.
#*****************************************************************************

use strict;
use Data::Dumper;
use LWP::UserAgent;
use Carp qw( croak );
use FileHandle;
use HTML::TreeBuilder;
use Encode;
use HTTP::Cookies;

my %category_mapping = (
);

my $base_url = 'http://www.handster.com';
my $cache = 'handster.html';
my $file_w = new FileHandle('>handster.url' ) or die "can't open $@";
my @url_list;

my $map_file = 'handster_mapping.txt';
my $map_w = new FileHandle(">$map_file")or die $@;
my $cookie_jar = HTTP::Cookies->new;
my $feed_w = new FileHandle(">handster.url")|| die $@;

my $ua = new LWP::UserAgent;
$ua->agent('Mozilla/5.0');
$ua->timeout(60);
my $res = $ua->get($base_url);
while( not $res->is_success ){
    $res = $ua->get( $base_url );
}

my $cookie = $res->header('set_cookie');
my $header;

if( my $html = Encode::decode_utf8($res->content) ){
    my $tree = new HTML::TreeBuilder;
    $tree->parse($html);
    $tree->eof;
    
    my @nodes = $tree->look_down( class => 'lb'  );
    Carp::croak("can't find lb label\n") unless @nodes;
    my @tags = $nodes[0]->find_by_tag_name('a');
    foreach my $tag( @tags ){
        next unless ref $tag;
        next if( $tag->attr('href') =~ m/cata/i);
        next if $tag->as_text =~ m/most|update/i;
        my $link = $tag->attr('href');
        my $class = $tag->as_text();
        # print $feed_w $tag->attr('href')."\n";
        print $feed_w "$link\n";
        print "'$class' => ''\n";
        print $map_w "'$class' => ''\n";
    }
}





    

