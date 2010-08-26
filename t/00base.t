use strict;
use warnings;

use Test::More;
use LWP::Simple;

use_ok('Test::Httpd::Apache2');

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


done_testing;
