package Catalyst::Plugin::ClamAV;

use strict;
use warnings;
use IO::Handle;
use Net::ClamAV::Client;

our $VERSION = '0.03';
our $base    = 'clamav';

sub clamscan {
    my ( $c, @names ) = @_;

    my $scanner = $c->_init_clam();
    unless ($scanner) {
        return -1;
    }

    my $found = 0;
    my @virus;
    foreach my $name (@names) {
        my @uploads = $c->req->upload( $name );
        next unless @uploads;

        foreach my $upload (@uploads) {
            my $fh = $upload->fh;
            if ($fh) {
                my $io = IO::Handle->new_from_fd($fh, 'r');
                my $virus = $scanner->scanStreamFH( $io );
                seek( $fh, 0, 0 );
                if ( $virus ) {
                    $found++;
                    push @virus, {
                        name      => $name,
                        filename  => $upload->filename,
                        signature => $virus,
                    };
                    $c->log->warn( __PACKAGE__ . " VIRUS found. signature='$virus'" );
                }
            }
        }
    }
    return wantarray ? @virus : $found;
}

sub _init_clam {
    my ($c) = shift;

    my %opt;
    foreach my $n(qw( socket_name socket_host socket_port )){
        $opt{$n} = $c->config->{$base}->{$n} if defined $c->config->{$base}->{$n};
    }
    my %new_opt;
    if ( $opt{socket_name} ) {
        $new_opt{url} = $opt{socket_name};
    }
    else {
        my $host = $opt{socket_host} || 'localhost';
        my $port = $opt{socket_port} || 3310;
        $new_opt{url} = "$host:$port";
    }

    my ( $scanner, $error );
    eval {
        $scanner = Net::ClamAV::Client->new( %new_opt );
        if ( !$scanner or !$scanner->ping ) {
            $error = 1;
        }
    };
    if ( $@ || $error ) {
        $c->log->error(qq{Cannot connect to ClamAV. $@});
        return;
    }
    return $scanner;
}

1;
__END__

=head1 NAME

Catalyst::Plugin::ClamAV - ClamAV scanning Plugin for Catalyst

=head1 SYNOPSIS

    use Catalyst;
    MyApp->setup( qw/ ClamAV / );

    # configuration for using unix domain socket
    MyApp->config->{clamav} = {
        socket_name => '/var/sock/clam',
    };

    # configuration for using TCP/IP socket
    MyApp->config->{clamav} = {
        socket_host => '127.0.0.1',
        socket_port => '3310',
    };

    # Virus scan upload files.
    my $found = $c->clamscan('field1', 'field2');

    my @found_virus = $c->clamscan('field1', 'field2');
    # e.g. @found_virus == ( {
    #          name      => 'field1',
    #          filename  => 'filename',
    #          signature => 'VIRUSNAME'
    #      } );

=head1 DESCRIPTION

This plugin add virus scan method (using ClamAV) for Catalyst.

Using Net::ClamAV::Client module.

=head1 CONFIGURATION

  MyApp->config->{clamav}->{socket_name};    # UNIX domain socket
  MyApp->config->{clamav}->{socket_host};    # TCP/IP host
  MyApp->config->{clamav}->{socket_port};    # TCP/IP port

See Net::ClamAV::Client POD.

=head1 METHODS

=over 4

=item clamscan

Scan uploaded file handles, using Net::ClamAV::Client->scanStreamFH().
Takes file upload field names as arguments.

HTML:

    <form action="/upload" method="post" enctype="multipart/form-data">
      <input type="file" name="field1">
      <input type="file" name="field2">
    </form>

Controller:

    $found = $c->clamscan('field1', 'field2');

The number of found viruses is returned.
If clamd is stopping ( $scanner->ping failed ), -1 returned.

To get found virus detail,

    @found_virus = $c->clamscan('field1', 'field2');

@found_virus is list of hash ref ( e.g. { name => 'fieldname', signature => 'virusname' } ).

=back

=head1 SEE ALSO

L<Catalyst> L<Net::ClamAV::Client>

=head1 AUTHOR

FUJIWARA Shunichiro, E<lt>fujiwara@topicmaker.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by FUJIWARA Shunichiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
