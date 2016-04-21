#!/usr/bin/perl 
use strict;
use warnings;

use v5.10.1;
use Data::Dumper;
use HTTP::Tiny;
use WWW::AUR;
use JSON;

(bless {}, __PACKAGE__)->main;

sub arg { $ARGV[0] }

sub main {
    my $self = shift;
    my $pkgname  = $self->arg || die "NodeJS or AUR package name required";
    my $aur_ver  = $self->aur_version($pkgname);
    if ($pkgname =~ m/^nodejs-/g) {
        $pkgname =~ s/^nodejs-//g;
    }

    my $url = "http://registry.npmjs.org/".$pkgname;
    my $http = HTTP::Tiny->new;
    my $res = $http->get($url);
    my $hash = from_json($res->{content});
    #print Dumper($hash);
    my $latest = $hash->{'dist-tags'}->{'latest'};
    my $versions = $hash->{'versions'};
    my $ver_hash = {
        aur_ver => $aur_ver,
        npm_ver => $versions->{$latest}->{'version'},
    };
    if ($ver_hash->{'npm_ver'} gt $ver_hash->{'aur_ver'}) {
        say "zOMFG!!!";
    }
    print Dumper($ver_hash);
    return 0;
}

sub aur_version {
    my $self = shift;
    my $name  = shift;
    my $aur  = WWW::AUR->new( basepath => '/tmp' );

    my $pkg  = $aur->find($name);
    my $ver  = $pkg->version;
    $ver =~ s/\-\d?$//;
    return $ver;

#    my $pkg  = $aur->find($name);
#    print Dumper($pkg->pkgbuild->pkgver);
#    return $pkg->pkgbuild->pkgver;
}
