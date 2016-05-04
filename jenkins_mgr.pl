#!/usr/bin/env perl 

use strict;
use version;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Jenkins::API;
use FindBin qw($Bin);
use YAML qw(LoadFile);

our $version = qv(0.5.0);

( bless {}, __PACKAGE__ )->main();

#Dummy subs cuz I'm lazy...
sub trigger_all { shift->{'trigger_all'}; }
sub trigger     { shift->{'trigger'}; }
sub verbose     { shift->{'verbose'} }        #TODO: Implement this
sub dump_conf   { shift->{'dump_conf'} }

sub conf_file {
    shift->{'conf_file'} ||= do { "$Bin/conf/jenkins-config.yaml" }
}

sub config {
    my $self = shift;
    my $conf = $self->{'__conf_obj'} ||= do { LoadFile( $self->conf_file ) };
    return $conf;
}

sub aur_path {
    my $self = shift;
    return $self->{'__aur_path'} ||= do { $self->config->{'conf'}->{'aur_root'} };
}

sub web_path {
    my $self = shift;
    return $self->{'__web_path'} ||= do { $self->config->{'conf'}->{'web_root'} };
}

sub options {
    my $self = shift;
    return GetOptions(
        "config|c=s"     => \$self->{'conf_file'},
        "trigger_all|ta" => \$self->{'trigger_all'},
        "trigger|t=s"    => \$self->{'trigger'},
        "verbose|v|V"    => \$self->{'verbose'},
        "dump_conf=s"    => \$self->{'dump_conf'},
    );
}

sub jenkins {
    my $self = shift;
    my $conf = $self->config->{'auth'};
    return $self->{'__jenkins_obj'}
      ||= do { Jenkins::API->new($conf) };
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
        unless ( grep { /^$dir$/ } @{$jobs} ) {
            print "Adding new job: $dir\n";
            $jenkins->create_job( $dir, $self->xml_tt($dir) );
        }
    }
    foreach my $job ( @{$jobs} ) {
        unless ( -d sprintf( "%s/%s", $self->aur_path, $job ) ) {
            print "Deleting job: $job\n";
            $jenkins->delete_project($job);
        }
    }
    $self->trigger_job( $self->trigger ) if $self->trigger;
    $self->trigger_all_jobs($jobs) if $self->trigger_all;

    return 0;
}

sub trigger_job {
    my $self = shift;
    my $job  = shift;
    print "Triggering Job: $job\n";
    $self->jenkins->trigger_build($job);
    return 0;
}

sub trigger_all_jobs {
    my $self = shift;
    my $jobs = shift;
    foreach my $job ( @{$jobs} ) {
        print "Triggering Job: $job\n";
        $self->jenkins->trigger_build($job);
    }
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
    my $www_root     = $self->web_path;
    my $artifact_str = sprintf( "%s*.tar.xz", $project );
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
      <command>makepkg -s -f;
cp -v $artifact_str $www_root;
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
__END__
