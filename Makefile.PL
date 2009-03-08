use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'VimRemote::Agent',
    AUTHOR              => 'bonar <bonar@cpan.org>',
    VERSION_FROM        => 'lib/VimRemote/Agent.pm',
    ABSTRACT_FROM       => 'lib/VimRemote/Agent.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Class::Accessor::Fast' => 0,
        'Test::More'  => 0,
        'File::Which' => 0,
        'IPC::Run'    => 0,
        'Time::HiRes' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'VimRemote-Agent-*' },
);
