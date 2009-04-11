
package VimRemote::Agent;

use warnings;
use strict;

our $VERSION = '0.01';

use base 'Class::Accessor::Fast';
use File::Which qw/which/;
use IPC::Run qw/start pump finish run timeout/;
use Time::HiRes qw/usleep/;

use constant {
    START_SERVER_CHECK_ERTRY => 30,
    START_SERVER_CHECK_SLEEP => 1000, # micro secs
    RUN_TIMEOUT => 5, # secs

    REMOTE_SEND_FMT => '<C-\><C-N>:%s<CR>',
};

__PACKAGE__->mk_accessors(qw/
    vimpath
    run_timeout
    exit_on_destroy
/);
our $RETURN = '\r?\n'; # common output delim

sub search_vim {
    my $candidate =  which('vim');
    return if !defined $candidate || !-f $candidate;

    if (!-x $candidate) {
        warn "vim found [$candidate], but not excutable.";
        return;
    }
    return $candidate;
}

sub has {
    my ($self, $option_name) = @_;
    return $self->vimbatch_do(qq{echo has("$option_name")});
}

sub _start {
    my (%arg) = @_;

    my $command_array = $arg{command};
    my @input = ref($arg{input}) eq 'ARRAY' ? @{$arg{input}} : ();

    my (%st);
    my $harness = start($command_array
        , \$st{'in'}, \$st{'out'}, \$st{'err'});
    return \%st if $arg{no_wait};

    foreach my $input (@input) {
        $st{in} .= $input . "\n";
        pump $harness while length $st{'in'};
    }
    finish $harness;

    return \%st;
}

sub vimbatch_do {
    my ($self, $input) = @_;

    # start vim with silent/batch mode (:help s-ex)
    my $st = _start(
        command => [$self->vimpath, qw{-e -s -V1}],
        input   => [$input],
    );
    my $response = (split /\Q$input\E/, $st->{'err'})[1];
    return (split /$RETURN/, $response)[1];
}

sub new {
    my ($class, %opt) = @_;
    my $self = bless {}, $class;

    # detect vimpath
    if (!defined $opt{vimpath}) {
        my $vimpath = search_vim()
            or die "vim not found or not correctly configured";
        $self->vimpath($vimpath);
    }
    else {
        $self->vimpath($opt{vimpath});
    }

    # check compile option
    if (!$self->has('clientserver')) {
        die "your vim[" . $self->vimpath . "] has no clientserver mode."
            . "reconfigure vim with +clientserver flag";
    }

    return $self;
}

sub serverlist {
    my ($self) = @_;
    my $st = _start(
        command => [$self->vimpath, qw{--serverlist}],
    );
    return split /$RETURN/, $st->{'out'};
}

sub start_server {
    my ($self, $name) = @_;
    _start(
        command => [$self->vimpath, '-g', '--servername', $name],
        no_wait => 1,
    );

    # wait until the server found in serverlist
    my $retry = START_SERVER_CHECK_ERTRY;
    while ($retry--) {
        return 1 if (grep /$name/, $self->serverlist());
        usleep(START_SERVER_CHECK_SLEEP);
    }
    warn "starting server [$name] failed.";
    return;
}

sub shutdown_server {
    my ($self, $name) = @_;
    return $self->remote_send($name, 'qa!');
}

sub _remote_cmd {
    my ($self, $server_name, $cmd) = @_;

    my $st = _start(
        command => $cmd);
    if ($st->{'err'}) {
        warn $st->{'err'};
        return;
    }
    return $st;
}

sub remote {
    my ($self, $server_name, $file) = @_;

    $self->_remote_cmd($server_name
        , [$self->vimpath, '--servername', $server_name
            , '--remote', $file]);
    return 1;
}

sub remote_wait {
    my ($self, $server_name, $file) = @_;
    
    my (%st);
    my $timeout = $self->run_timeout 
        ? $self->run_timeout 
        : RUN_TIMEOUT
        ;
    run([$self->vimpath, '--servername', $server_name
        , '--remote-wait', $file]
        , \$st{in}, \$st{out}, \$st{err}
        , timeout($timeout));
    return 1;
}

sub remote_send {
    my ($self, $server_name, $command) = @_;

    $self->_remote_cmd($server_name
        , [$self->vimpath, '--servername', $server_name
            , '--remote-send', sprintf(REMOTE_SEND_FMT, $command)]);
    return 1;
}

sub remote_send_raw {
    my ($self, $server_name, $command) = @_;

    $self->_remote_cmd($server_name
        , [$self->vimpath, '--servername', $server_name
            , '--remote-send', $command]);
    return 1;
}

sub remote_expr {
    my ($self, $server_name, $expr) = @_;

    my $st = $self->_remote_cmd($server_name
        , [$self->vimpath, '--servername', $server_name
            , '--remote-expr', $expr]);
    return if !defined $st;

    chomp $st->{'out'};
    return $st->{'out'};
}

=head1 NAME

VimRemote::Agent - simple client for vim server operations.

=head1 SYNOPSIS

    use VimRemote::Agent;

    my $agent = VimRemote::Agent->new();

    # check compile option
    if (!$agent->has('clientserver')) {
        die "configure vim with +clientserver flag";
    }

    # get running server list
    my @server_name = $agent->serverlist();

    # start new server
    my $server_name = 'NEWSVR';
    if (!$agent->start_server($server_name)) {
        die "starting server $server_name failed.";
    }

    # calc on remote server
    my $result = $agent->remote_expr($server_name, '1 + 1');
    print $result; # 2

    # send ex command to remote server
    $agent->remote_send('e /tmp/hoge.txt');

    # shutdown server
    $agent->shutdown_server($server_name);


=head1 DESCRIPTION

VimRemote::Agent is a simple client for vim server operations.

This module is just a system call wrappers for vim server mode operations.
All the functions use IPC::Run to call vim commands and get its output, so 
it is very slow.

XS version is comming up in 2050.

=head1 ABOUT VIM SERVER

Vim can act as a command server. this command will start new server
named "BONAR".

  vim --servername=BONAR

Now you can send file operation command or other vimscript to the server "BONAR".

  vim --servername=BONAR --remote "foo.txt"
  vim --servername=BONAR --remote-send 'echo "Happy vimming"';

See vim help for details:
  :help remote

=head1 COMPILING VIM

Vim server mode (--remote) is not in default configure flag. your vim has to be 
compiled with this configure flag to use it.

  ./configure +clientserver

Check compile options with :version command in vim normal mode.

=head1 METHODS

=head2 new(%opt)

return VimRemote::Agent object. these are the options.

=head3 vimpath

path to vim. if not specified, search_vim() is called to search path.

=head2 search_vim

search and return  vim path with File::Which::which.

=head2 has($option_name)

check vim compile option. retrun 1 if current vim ($self->vimpath) is
configured with +$option_name. 

=head2 vimbatch_do($input)

(beta function)

execute vimscript($input) on the vim silent/batch mode with -V option
and returns "only first line" of the output.

=head2 serverlist

returns running server name list (array of string). this is an alias 
of system call "vim --serverlist".

=head2 start_server($server_name)

start vim server with $server_name. this is an alias of
"vim --servername $servername". this function wait until
$server_name is found in serverlist() array.

=head2 shutdown_server

shutdown vim server with $server_name. this function call remote_send()
and execute quit command.

=head2 remote($server_name, $filepath)

open $filepath on remote server.

=head2 remote_wait($server_name, $filepath)

open $filepath on remote server. but this method use "run" instead of 
"start". that means this method waits until vim server returns some
response (or timeout).

=head2 remote_send($server_name, $command)

send $command to running server($server_name). return 1 for success,
0 for failed.

=head2 remote_expr($server_name, $expr)

send $expr to running server($server_name), and returns the result.

  print $agent->remote_expr("SVR1", '5 * 3'); # 15

=head1 AUTHOR

bonar, C<< <bonar at cpan.org> >>

=head1 BUGS

patches are wellcome.
git repo:
http://github.com/bonar/vimremote-agent/tree/master

=head1 COPYRIGHT & LICENSE

Copyright 2009 bonar, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
