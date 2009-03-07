#!perl -T

use Test::More tests => 5;

BEGIN {
	use_ok( 'Class::Accessor::Fast' );
	use_ok( 'Test::More' );
	use_ok( 'File::Which' );
	use_ok( 'IPC::Run' );
	use_ok( 'VimRemote::Agent' );
}


