package DataCheck;

use strict;
use warnings;
use Encode;
use FileHandle;
use LWP::Simple;
use Carp;
use Test::more 'no_plan';

sub CHECK_ATTR () {
    return qw(
        author
        app_url
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
    )
}

sub PRIOR_CHECK_ATTR () {
    return  qw();
}

sub NOT_CHECK(){
    0
}

sub CHECK_FUNC_SUITE (){
    1
}

sub new{
    my $class = shift;
    my %param = @_;

    my $self = [];

    # check args 'check_func' => sub {}
    foreach my $attr( CHECK_ATTR  ){
        push @{ $self->[NOT_CHECK] },$attr
            unless exists $param{check_value};
    }

    foreach my $check( keys %param ){
        $self->[CHECK_FUNC_SUITE]->{$check} = delete $param{$check};
    }

    bless $self,$class;
    return $self;
}

sub check_meta{
    my $self = shift;
    # author => 'xxx000' meta example
    my $meta = shift;
    my @args = @_;
    
    foreach my $key(keys %$meta){
        Carp::craok(
            "not exists this attr $key in check list"
        ) unless $self->[CHECK_FUNC_SUITE]->{$key};
        Carp::croak(
            "not defined attr $key check coderef,please check..."
        ) unless ref($self->[CHECK_FUNC_SUITE]->{$key}) eq 'CODE';
        my $check = $self->[CHECK_FUNC_SUITE]->{$key};
    }
}

sub check_extract_page_list{
    my ( $self,$extract_func,$page_ref,$expect ) = @_;
    # $page_ref is { html => 'string',url => 'xxx';}
    # page_list 
    # arrayref
    my $page_list =[];
    # test return value
    is(
        $extract_func->(
            undef,undef,{ web_page => $page_ref->{html} },$page_list
        ),
        # expect right return
        1,
        "test extract return value with right args parse url '$page_ref->{url}'\n "
    );

    # test page num is right
    is( scalar($page_list),$expect,"test page num is rigth with '$expect'\n");

    # test page url is valid
    map{
        is( defined( get($_) ),1,"test page valid url: '$_' \n" );
    } @{ $page_list };

    return
}

sub check_url_vaild{
    my $self = shift;
    my $url  = shift;

    return unless $url =~ m//; # TODO url regular
    return unless defined get($url);

    return 1;
}

1;

#use DataCheck;

