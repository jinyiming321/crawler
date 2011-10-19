#!/usr/bin/perl 
#===============================================================================
#
#         FILE: hello.pl
#
#        USAGE: ./hello.pl  
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
#      CREATED: 2011年09月23日 22时10分40秒
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
print "hello world";
&func;
sub func{
    my $a = 3;
    print $a;
}


