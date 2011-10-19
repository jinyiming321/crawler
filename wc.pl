#!/usr/bin/perl 
#===============================================================================
#
#         FILE: wc.pl
#
#        USAGE: ./wc.pl  
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
#      CREATED: 2011年10月19日 06时12分05秒
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use FileHandle;
my $fh = new FileHandle( 'wc.log')||die $@;
my $hash;
while( my $line =<$fh> ){
    if( $line =~ m/(\d+)/ ){
        $hash->{$1} = 1;
    }
}

print scalar keys %$hash;



