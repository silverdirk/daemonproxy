#! /usr/bin/env perl

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use Test::DaemonProxy;

my $dp= Test::DaemonProxy->new;
$dp->timeout(0.1);
$dp->run('--stdin');

# Set short timeouts so that this test doesn't take too long to run
$dp->send("conn.event_timeout	2	8");
$dp->send("echo	set");
$dp->recv( qr/^set$/m );

# Send a bunch of service.args commands, and don't read the responses, causing a pileup
# on the return pipe.
# Daemonproxy should set the overflow flag after 2 seconds unable to write the pipe,
# and then queue an 'overflow' message.
# When we finally read our pipe, it should end with "overflow" after about 6K of data.
for (my $i= 0; $i < 1000; $i++) {
	$dp->send("service.args\tfoo\t/nonexistent/path/$i".(' yada' x 60));
}

$dp->response_like(qr/^overflow$/m, 'overflow flag received');

$dp->discard_response;

$dp->send("echo\t-marker-");
$dp->response_like( qr/^-marker-/, 'can still send/receive' );

$dp->send("terminate");
$dp->exit_is(6);

done_testing;