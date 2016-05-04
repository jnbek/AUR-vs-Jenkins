#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;
use Git;
use Env qw(HOME);

( bless {}, __PACKAGE__ )->main();

sub aur { "$HOME/aur4" }

sub main {
    my $self = shift;
    my $pkbd = $ARGV[0] || die "Argument required: $0 aur-pkg_name";
    chdir $self->aur || die "Chdir failed: $!";
    my $rurl = sprintf( q{ssh+git://aur@aur.archlinux.org/%s.git}, $pkbd );
    my $repo = Git->repository( Repository => $rurl );
    say
      sprintf( "Attemping to clone %s\nUsing v%s of %s", $rurl, $repo->version, $repo->exec_path );
    $repo->command( "clone", $rurl );
    return 0;
}
