#
#===============================================================================
#
#         FILE: SimpleConfig.pm
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: JamesKing (www.perlwiki.info), jinyiming456@gmail.com
#      COMPANY: China
#      VERSION: 1.0
#      CREATED: 2011年11月03日 21时20分09秒
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
package AMMS::SimpleConfig;                                                                                                                                  
use strict;
use warnings;
 
sub load {
        my $self = shift;
            my $file = shift;
                open my $handle, "<:utf8", $file or die "Couldn't open config
                    file:$!";
                    my $content = do { local $/; <$handle> };
                        return $self->parse( $content, $file);
}
 
sub parse {
        my ($self,$content,$file) = @_; 
            die "Couldn't parse config file:$@"
                      unless my $config = eval "$content";
                die "Config $file does't return a hashref"
                          unless ref $config && ref $config eq "HASH";
                    return $config;
}
 
1;
