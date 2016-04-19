#!/usr/bin/env perl 

use strict;
use version;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Jenkins::API;
use Env qw(HOME);
use YAML qw(LoadFile);

our $version = qv(0.2.0);

( bless {}, __PACKAGE__ )->main();

sub conf_file { "$HOME/etc/jenkins.yaml" }

sub build_path { "$HOME/aur_management/build_root/" }

sub aur_path { "$HOME/aur4" }

#Dummy subs cuz I'm lazy...
sub trigger   { shift->{'trigger'}; }
sub verbose   { shift->{'verbose'} }     #TODO: Implement this
sub dump_conf { shift->{'dump_conf'} }

sub options {
    my $self = shift;
    return GetOptions(
        "trigger|ta"  => \$self->{'trigger'},
        "verbose|v|V" => \$self->{'verbose'},
        "dump_conf=s" => \$self->{'dump_conf'},
    );
}

sub jenkins {
    my $self = shift;
    my $conf = LoadFile( $self->conf_file );
    return $self->{'__jenkins_obj'} ||= do { Jenkins::API->new($conf) };
}

sub main {
    my $self = shift;
    my ( $jobs, $dirs ) = [];
    $self->options if (@ARGV);

    # Just dump XML if we're passed dump_conf and then bail
    return $self->dump_project_config( $self->dump_conf ) if $self->dump_conf;
    # Otherwise, do all the things.
    my $jenkins  = $self->jenkins;
    my $projects = $jenkins->current_status( { extra_params => { tree => 'jobs[name]' } } );
    my $jobs_ref = $projects->{'jobs'};
    my $count    = map { push @{$jobs}, $_->{'name'} } @{$jobs_ref};
    chdir( $self->aur_path );
    @{$dirs} = glob("*");

    foreach my $dir ( @{$dirs} ) {
        print $dir, "\n";
        $jenkins->create_job( $dir, $self->xml_tt($dir) )
          unless grep { /$dir/ } @{$jobs};
    }
    foreach my $job ( @{$jobs} ) {
        $jenkins->delete_project($job) unless -d sprintf( "%s/%s", $self->aur_path, $job );
    }
    $self->trigger_all($jobs) if $self->trigger_all;

    return 0;
}

sub dump_project_config {
    my $self    = shift;
    my $project = shift;
    my $config  = $self->jenkins->project_config($project);
    print $config, "\n";
    exit(0);
}

sub xml_tt {
    my $self         = shift;
    my $project      = shift;
    my $artifact_str = sprintf( "%s.tar.xz", $project );
    my $aur_path     = sprintf( "%s/%s", $self->aur_path, $project );
    my $build_path   = sprintf( "%s/%s", $self->build_path, $project );
    my $xml          = qq{<?xml version='1.0' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Build the PKGBUILD at https://aur.archlinux.org/packages/$project</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <jenkins.model.BuildDiscarderProperty>
      <strategy class="hudson.tasks.LogRotator">
        <daysToKeep>-1</daysToKeep>
        <numToKeep>1</numToKeep>
        <artifactDaysToKeep>-1</artifactDaysToKeep>
        <artifactNumToKeep>1</artifactNumToKeep>
      </strategy>
    </jenkins.model.BuildDiscarderProperty>
  </properties>
  <scm class="hudson.plugins.git.GitSCM" plugin="git\@2.4.4">
    <configVersion>2</configVersion>
    <userRemoteConfigs>
      <hudson.plugins.git.UserRemoteConfig>
        <url>ssh+git://aur\@aur.archlinux.org/$project.git</url>
      </hudson.plugins.git.UserRemoteConfig>
    </userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec>
        <name>*/master</name>
      </hudson.plugins.git.BranchSpec>
    </branches>
    <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
    <submoduleCfg class="list"/>
    <extensions>
      <hudson.plugins.git.extensions.impl.CleanCheckout/>
      <hudson.plugins.git.extensions.impl.CleanBeforeCheckout/>
    </extensions>
  </scm>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers>
    <hudson.triggers.TimerTrigger>
      <spec>\@weekly</spec>
    </hudson.triggers.TimerTrigger>
  </triggers>
  <concurrentBuild>true</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>cp -rv $aur_path $build_path
cd $build_path; 
makepkg;
yaourt -U $artifact_str --noconfirm
cp -v $artifact_str \$WORKSPACE;
rm -rf $build_path;
</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers>
    <hudson.tasks.ArtifactArchiver>
      <artifacts>$artifact_str</artifacts>
      <allowEmptyArchive>true</allowEmptyArchive>
      <onlyIfSuccessful>true</onlyIfSuccessful>
      <fingerprint>false</fingerprint>
      <defaultExcludes>true</defaultExcludes>
      <caseSensitive>true</caseSensitive>
    </hudson.tasks.ArtifactArchiver>
  </publishers>
  <buildWrappers/>
</project>
    };
    return $xml;
}
