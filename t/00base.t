use strict;
use warnings;

use Test::More;
use LWP::Simple;

use_ok('Test::Httpd::Apache2');


my $httpd = Test::Httpd::Apache2->new(
    custom_conf => << 'EOT',

DocumentRoot "t/assets/htdocs"

EOT
);

ok $httpd, 'spawn httpd';
is get("http://@{[$httpd->listen]}/hello.txt"), 'hello';

undef $httpd;

done_testing;
