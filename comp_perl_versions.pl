#!/usr/bin/env perl 

use v5.10.1;
use strict;
use warnings;

use WWW::AUR;
use Data::Dumper;
use MetaCPAN::Client;

( bless {}, __PACKAGE__ )->main();

sub arg { $ARGV[0] }

sub mcpan {
    shift->{'__mcpan_object'} ||= do { MetaCPAN::Client->new() }
}

sub main {
    my $self     = shift;
    my $pkgname  = $self->arg || die "AUR package name required";
    my $aur_hash = $self->aur_info($pkgname);
    my $upstream_ver = $self->parse_perl( $aur_hash->{'name'} );
    my $ver_hash     = {
        aur4_hash => $aur_hash->{'ver'},
        cpan_hash => $upstream_ver,
    };
    print Dumper($ver_hash);

    return 0;
}

sub parse_perl {
    my $self        = shift;
    my $pkbd_url    = shift;
    my $cpan_module = $pkbd_url;
    $cpan_module =~ s#/$##;
    $cpan_module =~ s/^.+\/(.*)/$1/;
    my $mod_obj = eval { $self->mcpan->release($cpan_module) };
    my $mod_ver = $mod_obj->version_numified;
    return $mod_ver;
}

sub aur_info {
    my $self = shift;
    my $name = shift;
    my $aur  = WWW::AUR->new( basepath => '/tmp' );

    my $pkg = $aur->find($name);
    my $ver = $pkg->version;
    $ver =~ s/\-\d?$//;
    return {
        ver  => $ver,
        name => $pkg->url,
    };
}
