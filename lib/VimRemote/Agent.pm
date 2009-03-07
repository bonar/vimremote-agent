
package VimRemote::Agent;

use warnings;
use strict;

our $VERSION = '0.01';

use base 'Class::Accessor::Fast';
use File::Which qw/which/;
use IPC::Run qw/start pump finish/;

__PACKAGE__->mk_accessors(qw/
    vimpath
    target_server_name
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
    my ($command_array, @input) = @_;

    my (%st);
    my $harness = start($command_array
        , \$st{'in'}, \$st{'out'}, \$st{'err'});

    foreach my $input (@input) {
        $st{in} .= $input . "\n";
        pump $harness while length $st{'in'};
    }
    finish $harness;

    return \%st;
}

sub vimbatch_do {
    my ($self, $command) = @_;

    # start vim with silent/batch mode (:help s-ex)
    my $st = _start([$self->vimpath, qw{-e -s -V1}], $command);
    my $response = (split /\Q$command\E/, $st->{'err'})[1];
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

sub search_server {
    my ($self) = @_;
    my $st = _start([$self->vimpath, qw{--serverlist}]);
    return split /$RETURN/, $st->{'out'};
}

=head1 NAME

VimRemote::Agent - simple client for vim server operations.

=head1 SYNOPSIS

    use VimRemote::Agent;

    if (!VimRemote::Agent->vim_ready()) {
        die "vim not found or not crrectly configured.";
    }

    # serch running vim server, and get names of them.
    my $server = shift VimRemote::Agent->serverlist();

    # create client object for the server.
    my $client = VimRemote::Agent->new(
        server => $server,
    );

    # or you can start server with the name $server.
    my $client = VimRemote::Agent->new(
        server       => $server,
        start_server => 1,
    );

    my $response = $client->open_file('foo.txt');
    my $response = $client->send_command('echo "Happy Vimming!"');
    my $response = $client->exec_file('my_vimscript.vim');


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

=head1 FUNCTIONS

=head1 AUTHOR

bonar, C<< <bonar at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-vimremote-client at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=VimRemote-Agent>. 
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2009 bonar, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
