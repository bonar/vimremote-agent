
use Test::More tests => 4;

BEGIN {
    use_ok('VimRemote::Agent');
    plan skip_all => 'vim not found' if !VimRemote::Agent::search_vim();
}

my $vim = VimRemote::Agent::search_vim();
if (!defined $vim) {
    plan skip_all => 'vim not found';
}
ok($vim, "vim found: $vim");
ok(-f $vim, "vim file: $vim");
ok(-x $vim, "vim excutable: $vim");

