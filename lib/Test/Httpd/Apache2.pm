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
