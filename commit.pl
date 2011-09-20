#!/usr/bin/perl

my $cmd1 = "git add .";
my $cmd2 = "git commit -m 'modify'";
my $cmd3 = "git push origin master";
system($cmd1);
system($cmd2);
system($cmd3);
