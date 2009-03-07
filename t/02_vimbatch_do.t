
use Test::More tests => 4;

BEGIN {
    use_ok('VimRemote::Agent');
    plan skip_all => 'vim not found' if !VimRemote::Agent::search_vim();
}

my $mok = bless {}, 'VimRemote::Agent';
$mok->vimpath(VimRemote::Agent->search_vim());
ok($mok->can('vimpath'), 'create mok instance and can vimpath()');

my $res1 = $mok->vimbatch_do('echo "test"');
is($res1, 'test', 'vimbatch_do response: simple echo');

my $res2 = $mok->vimbatch_do('echo (1 + 1)');
is($res2, 2, 'vimbatch_do response: calc');


