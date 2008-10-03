#!perl

use strict;
use warnings;

use FindBin;
use IO::Socket;
use Test::More;
use Test::WWW::Mechanize;

# plan skip_all => 'set TEST_HTTP to enable this test' unless $ENV{TEST_HTTP};
eval "use Catalyst::Devel 1.0";
plan skip_all => 'Catalyst::Devel required' if $@;

plan tests => 17;

# How long to wait for test server to start and timeout for UA.
my $seconds = 30;

# Spawn the standalone HTTP server.
my $port = 30000 + int rand(1 + 10000);

 my $pipe = "perl -I$FindBin::Bin/../lib -I$FindBin::Bin/TestApp/lib $FindBin::Bin/TestApp/script/testapp_server.pl -fork -port $port |";

# my $pipe = "perl -I$FindBin::Bin/../lib -I$FindBin::Bin/TestApp/lib $FindBin::Bin/TestApp/script/testapp_server.pl -f -port $port 2>&1 |";

my $pid = open my $server, $pipe
    or die "Unable to spawn standalone HTTP server: $!";

diag("Waiting (up to $seconds seconds) for server to start...");

eval {
    local $SIG{ALRM} = sub { die "Server took too long to start\n" }; # NB: \n required
    alarm($seconds);

    while ( check_port( 'localhost', $port ) != 1 ) {
        sleep 1;
    }
    alarm(0)
};

if ( $@ )
{
    kill 'INT', $pid;
    close $server;
    die "Could not run test: $@\n$pipe";
}
    
my $root = $ENV{CATALYST_SERVER} = "http://localhost:$port";

# Tests start --------------------------------------------
ok("Started");


my $mech = Test::WWW::Mechanize->new(timeout => $seconds);

$mech->get_ok($root, "GET $root");
$mech->content_contains("not signed in", "Content looks right");

$mech->get_ok("$root/login", "GET $root/login");

# diag($mech->content);

$mech->submit_form_ok({ form_name => "login",
                        fields => { username => "paco",
                                    password => "l4s4v3n7ur45",
                                },
                       },
                      "Trying cleartext login, 'memebers' realm");

$mech->content_contains("signed in", "Signed in successfully");

$mech->get_ok("$root/signin_openid", "GET $root/signin_openid");

$mech->content_contains("Sign in with OpenID", "Content looks right");

my $claimed_uri = "$root/provider/paco";

$mech->submit_form_ok({ form_name => "openid",
                        fields => { openid_identifier => $claimed_uri,
                                },
                    },
                      "Trying OpenID login, 'openid' realm");

$mech->content_contains("You did it with OpenID!",
                        "Successfully signed in with OpenID");

$mech->get_ok($root, "GET $root");

$mech->content_contains("provider/paco", "OpenID signed in");
#$mech->content_contains("paco", "OpenID signed in as paco");

# can't be verified

$mech->get_ok("$root/logout", "GET $root/logout");

$mech->get_ok("$root/signin_openid", "GET $root/signin_openid");

$mech->content_contains("Sign in with OpenID", "Content looks right");

$mech->submit_form_ok({ form_name => "openid",
                        fields => { openid_identifier => $claimed_uri,
                                },
                    },
                      "Trying OpenID login, 'openid' realm");

$mech->content_contains("can't be verified",
                        "Proper failure for unauthenticated memember.");

# Tests end ----------------------------------------------

# shut it down
kill 'INT', $pid;
close $server;

exit 0;

sub check_port {
    my ( $host, $port ) = @_;

    my $remote = IO::Socket::INET->new(
        Proto    => "tcp",
        PeerAddr => $host,
        PeerPort => $port
    );
    if ($remote) {
        close $remote;
        return 1;
    }
    else {
        return 0;
    }
}

__END__

