
use Test::More tests => 25;

BEGIN {
    use_ok('VimRemote::Agent');
    plan skip_all => 'vim not found' if !VimRemote::Agent::search_vim();

    my $mok = bless {}, 'VimRemote::Agent';
    $mok->vimpath(VimRemote::Agent->search_vim());
    plan skip_all => 'no clientserver option.' 
        . 'reconfigure with +clientserver flag' if !$mok->has('clientserver');
}

plan skip_all => 'this terminal needs output tty' if !-t;

my $agent = VimRemote::Agent->new();
ok($agent, 'create instance');
isa_ok($agent, 'VimRemote::Agent');

{ # start/shutdown server
    is($agent->start_server('VIMREMOTE'), 1, 'starting server');
    ok(scalar(grep /VIMREMOTE/, $agent->serverlist())
        , 'found in serverlist');

    is($agent->shutdown_server('VIMREMOTE'), 1, 'shutdown server');
    is(scalar(grep /VIMREMOTE/, $agent->serverlist()), 0
        , 'not found in serverlist');

    # starting multi-server
    my @serverlist = qw/FOO BAR BUZZ/;
    is(scalar $agent->serverlist(), 0, 'now serverlist empty');
    foreach my $serve_name (@serverlist) {
        is($agent->start_server($serve_name), 1
            , "starting server [$serve_name]");
    }
    is(scalar $agent->serverlist(), scalar @serverlist
        , 'server count');
    foreach my $serve_name (@serverlist) {
        is($agent->shutdown_server($serve_name), 1
            , "shutdown server [$serve_name]");
    }
    is(scalar $agent->serverlist(), 0, 'server count');
}

{ # expr
    is($agent->start_server('EXPR'), 1, 'starting server');
    is($agent->remote_expr('EXPR', '1 + 1'), 2, 'expr 1 + 1');
    is($agent->remote_expr('EXPR', '5 - 2'), 3, 'expr 5 -2');
    is($agent->remote_expr('EXPR', '2 * 3'), 6, 'expr 2 * 3');
    is($agent->remote_expr('EXPR', '339 / 3'), 113, 'expr 339 / 3');
    is($agent->shutdown_server('EXPR'), 1, 'shutdown server');
}

{ # remote send
    is($agent->start_server('REMOTESEND'), 1, 'starting server');

    # create test file, and print pid on it.
    my $tmp_path = "VimRemote-Agent-$$.txt";
    unless (open $tmp, '> ', $tmp_path) {
        die "cannot create temp file for test";
    }
    print $tmp $$;
    close($tmp);

    # open tmp file on remote server and get first line
    # by calling remote_expr.
    $agent->remote_send('REMOTESEND', "e $tmp_path");
    my $firstline = $agent->remote_expr('REMOTESEND', 'getline(1)');
    is($firstline, $$, 'e open and remote_send read combination');

    is($agent->shutdown_server('REMOTESEND'), 1, 'shutdown server');
    unlink($tmp_path);
}





















