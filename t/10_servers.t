
use Test::More tests => 3;

BEGIN {
    use_ok('VimRemote::Agent');
    plan skip_all => 'vim not found' if !VimRemote::Agent::search_vim();

    my $mok = bless {}, 'VimRemote::Agent';
    $mok->vimpath(VimRemote::Agent->search_vim());
    plan skip_all => 'no clientserver option.' 
        . 'reconfigure with +clientserver flag' if !$mok->has('clientserver');
}

my $client = VimRemote::Agent->new();
ok($client, 'create instance');
isa_ok($client, 'VimRemote::Agent');

my @servers = $client->search_server();
use Data::Dumper;
warn Dumper(\@servers);

