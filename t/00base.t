use strict;
use warnings;

use Test::More;
use LWP::Simple;

use_ok('Test::Httpd::Apache2');

{ # skip if httpd cannot be found
    no warnings qw(once);
    my @paths = (
        split(':', $ENV{PATH}),
        @{$Test::Httpd::Apache2::Defaults{search_paths}},
    );
    if (! grep { -x "$_/httpd" } @paths) {
        warn "httpd not found, skipping actual tests";
        goto DONE_TESTING;
    }
}

# start httpd
my $httpd = Test::Httpd::Apache2->new(
    custom_conf => << 'EOT',

DocumentRoot "t/assets/htdocs"

EOT
);

ok $httpd, 'spawn httpd';
is get("http://@{[$httpd->listen]}/hello.txt"), 'hello';

# stop httpd
$httpd->stop();

ok ! $httpd->pid(), 'httpd should be down';

# try to load module if has support for dso
if (my @mods = @{$httpd->get_dynamic_modules}) {
    $httpd->required_modules([ $mods[0] ]);
    $httpd->start(); # will die on error
}

undef $httpd;

DONE_TESTING:
done_testing;
