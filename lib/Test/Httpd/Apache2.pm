package Test::Httpd::Apache2;

use strict;
use warnings;

use 5.008;
use Class::Accessor::Lite;
use Cwd qw(getcwd);
use File::Temp qw(tempdir);
use IO::Socket::INET;
use POSIX qw(WNOHANG);
use Test::TCP qw(empty_port);
use Time::HiRes qw(sleep);

our $VERSION = '0.01';

my %Defaults = (
    auto_start   => 1,
    pid          => undef,
    listen         => undef,
    server_root  => undef,
    tmpdir       => undef,
    custom_conf  => '',
    search_paths => [ qw(/usr/sbin /usr/local/sbin /usr/local/apache/bin) ],
);

Class::Accessor::Lite->mk_accessors(keys %Defaults);

sub new {
    my $klass = shift;
    my $self = bless {
        %Defaults,
        @_ == 1 ? %{$_[0]} : @_,
    }, $klass;
    if (! $self->server_root) {
        $self->server_root(getcwd);
    }
    $self->listen("127.0.0.1:@{[empty_port()]}")
        unless $self->listen();
    $self->tmpdir(tempdir(CLEANUP => 1));
    $self->start()
        if $self->auto_start();
    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->stop()
        if $self->pid();
}

sub start {
    my $self = shift;
    die "httpd is already running (pid:@{[$self->pid]})"
        if $self->pid;
    # write configuration
    $self->write_conf();
    # spawn httpd
    my $pid = fork;
    if (! defined $pid) {
        die "fork failed:$!";
    } elsif ($pid == 0) {
        # child process
        $ENV{PATH} = join(':', $ENV{PATH}, $self->search_paths);
        exec 'httpd', '-X', '-D', 'FOREGROUND', '-f', $self->conf_file;
        die "failed to exec httpd:$!";
    }
    # wait until the port becomes available
    while (1) {
        my $sock = IO::Socket::INET->new(
            PeerAddr => do {
                $self->listen =~ /:/
                    ? $self->listen : "127.0.0.1:@{[$self->listen]}",
                },
            Proto    => 'tcp',
        ) and last;
        if (waitpid($pid, WNOHANG) == $pid) {
            die "httpd failed to start, exitted with rc=$?";
        }
        sleep 0.1;
    }
    $self->pid($pid);
}

sub stop {
    my $self = shift;
    die "httpd is not running"
        unless $self->pid;
    kill 'TERM', $self->pid;
    while (waitpid($self->pid, 0) != $self->pid) {
    }
    $self->pid(undef);
}

sub write_conf {
    my $self = shift;
    my $conf = << "EOT";
ServerRoot @{[$self->server_root]}
PidFile @{[$self->tmpdir]}/httpd.pid
LockFile @{[$self->tmpdir]}/httpd.pid
ErrorLog @{[$self->tmpdir]}/error_log
Listen @{[$self->listen]}

@{[$self->custom_conf]}
EOT
    open my $fh, '>', $self->conf_file
        or die "failed to open file:@{[$self->conf_file]}:$!";
    print $fh $conf;
    close $fh;
}

sub conf_file {
    my $self = shift;
    return "@{[$self->tmpdir]}/httpd.conf";
}

1;

__END__

=head1 NAME

Test::Httpd::Apache2 - Apache2 runner for tests

=head1 SYNOPSIS

    use Test::Httpd::Apache2;

    my $httpd = Test::Httpd::Apache2->new(
        custom_conf => << 'EOT',
    DocumentRoot "htdocs"
    EOT
    );

    # do whatever you want
    my $url = "http://" . $httpd->listen . "/";
    ...

=head1 DESCRIPTION

The module automatically setups an instance of Apache2 httpd server and destroys it when the perl script exits.

=head1 FUNCTIONS

=head2 new

Creates and runs the httpd server.  Httpd is terminated when the returned object is DESTROYed.  The function accepts following arguments, which can also be read and/or be set through the accessors of the same name.

=head3 listen

The address to which the httpd binds to.  Corresponds to the "Listen" configuration directive of Apache.  The default value is "127.0.0.1:<whatever_port_that_was_unused>".

=head3 server_root

The "ServerRoot" runtime directive.  Set to current working directory if omitted.

=head3 custom_conf

Application-specific configuration passed that will be written to the configuration file of Apache.  Default is none.

=head3 search_paths

Paths to look for the httpd server in addition to the PATH environment variable.  The default is: /usr/sbin, /usr/local/sbin, /usr/local/apache/bin.

=head3 pid

the read-only accessor returns pid of the httpd server or undef if it is not running

=head2 start

the instance method starts the httpd server

=head2 stop

the instance method stops the httpd server

=head1 COPYRIGHT

Copyright (C) 2010 Cybozu Labs, Inc.  Written by Kazuho Oku.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
