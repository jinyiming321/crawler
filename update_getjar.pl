#!/usr/bin/perl 
#===============================================================================
#
#         FILE: update_getjar.pl
#
#        USAGE: ./update_getjar.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: JamesKing (www.perlwiki.info), jinyiming456@gmail.com
#      COMPANY: China
#      VERSION: 1.0
#      CREATED: 2011年11月04日 12时19分29秒
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use DBI;
use AMMS::Util;
use HTML::TreeBuilder;
# DBI:mysql:database=$database;host=$hostname;port=$port
my $dsn = "DBI:mysql:database=AMMS;host=localhost;port=3306";
my $user = "root";
my $pass = "root";
my $dbh = DBI->connect(
        $dsn,
        $user,
        $pass,
        );

my $sth = $dbh->prepare(
        "update app_source set size,official_comment_times,official_rating_stars
        values ( ?,?,? )
        ";

my $apk_file = '';
my $page = '';

update_getjar( $apk_file,$page );

sub update_getjar{
    my $apk_file= shift;
    my $page = shift;
    my $app_dir = '';
    my $apk_file = '';
    my $size = 0;
    my $rating=0;
    my $official_rating_stars = 0;

    if( -e $apk_file ){
         $size = ( stat($apk_file) )[7] ;
    }

    my $tree = new HTML::TreeBuilder;
    $tree->parse($page);
    $tree->eof;

    my $like = $tree->look_down( class => 'product_pref_like_block' );
    warn " not find like tag" if ref $like;
    my $dislike = $tree->look_down( class => 'product_pref_dislike_block');
    warn " not find dislike tag";
    $rating = 
        $like->find_by_attribute( id => 'product_count_label')/
        (
         $like->find_by_attribute( id => 'product_count_label')
         +
         $dislike->find_by_attribute( id => 'product_count_label' )
        )*10/2;
    $official_comment_times = $tree->look_down( class =>
            'product_pref_comment_block'
    ) || 0;

    $sth->execute($size,$official_comment_times,$official_rating_stars ) or 
        warn "run sql failed";
}
        




