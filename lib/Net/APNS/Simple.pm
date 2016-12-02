package Net::APNS::Simple;
use 5.008001;
use strict;
use warnings;
use Carp ();
use Crypt::JWT ();
use JSON;
use Moo;
use Protocol::HTTP2::Client;
use IO::Select;
use IO::Socket::SSL qw(debug4);

our $VERSION = "0.01";

has [qw/auth_key key_id team_id bundle_id development/] => (
    is => 'rw',
);

sub algorithm {'ES256'};

sub host {
    my ($self) = @_;
    return 'api.' . ($self->development ? 'development.' : '') . 'push.apple.com'
}

sub notify {
    my ($self, $device_token, $aps, $cb, $arg) = @_;
    defined $device_token && $device_token ne ''
        or Carp::croak("Empty parameter 'device_token'");
    ref $aps eq 'HASH'
        or Carp::croak("Parameter aps is not HASHREF");
    $arg ||= {};
    for my $attr (qw/auth_key key_id team_id bundle_id/){
        exists $arg->{$attr} and $self->$attr($arg->{$attr});
        defined $self->$attr && $self->$attr ne ''
            or Carp::croak("Empty parameter '$attr'");
    }
    my $secret = `openssl pkcs8 -nocrypt -in @{[$self->auth_key]}`;
    $? == 0
        or Carp::croak("Cannot read auth_key file. $!");
    my $craims = {
        iss => $self->team_id,
        iat => time,
    };
    my $jwt = Crypt::JWT::encode_jwt(
        payload => $craims,
        key => \$secret,
        alg => $self->algorithm,
        extra_headers => {
            kid => $self->key_id,
        },
    );
    my $path = sprintf '/3/device/%s', $device_token;
    my $h2_client = Protocol::HTTP2::Client->new;
    $h2_client->request(
        ':scheme' => 'https',
        ':authority' => join(":", $self->host, 443),
        ':path' => $path,
        ':method' => 'POST',
        headers => [
            'apns-expiration' => 0,
            'apns-priority' => 10,
            'apns-topic' => $self->bundle_id,
            'authorization'=> sprintf('bearer %s', $jwt),
        ],
        data => JSON::encode_json({aps => $aps}),
        on_done => $cb,
    );
    # TLS transport socket
    my $client = IO::Socket::SSL->new(
        PeerHost => $self->host,
        PeerPort => 443,
        # openssl 1.0.1 support only NPN
        SSL_npn_protocols => ['h2'],
        # openssl 1.0.2 also have ALPN
        SSL_alpn_protocols => ['h2'],
        SSL_version => 'TLSv1_2',
    ) or die $!||$SSL_ERROR;

    # non blocking
    $client->blocking(0);

    my $sel = IO::Select->new($client);

    # send/recv frames until request is done
    while ( !$h2_client->shutdown ) {
        $sel->can_write;
        while ( my $frame = $h2_client->next_frame ) {
            syswrite $client, $frame;
        }

        $sel->can_read;
        while ( sysread $client, my $data, 4096 ) {
            $h2_client->feed($data);
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Net::APNS::Simple - APNS Perl implementation

=head1 SYNOPSIS

    use Net::APNS::Simple;
    my $apns = Net::APNS::Simple->new(
        # enable if development
        # development => 1,
        auth_key => '/path/to/auth_key.p8',
        key_id => 'AUTH_KEY_ID',
        team_id => 'APP_PREFIX',
        bundle_id => 'APP_ID',
    );
    $apns->notify('DEVICE_ID',{
            alert => 'APNS message: HELLO!',
            badge => 1,
            sound => "default",
            # SEE: https://developer.apple.com/jp/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/TheNotificationPayload.html,
        }, sub {
            my ($header, $content) = @_;
            require Data::Dumper;
            print Dumper $header;

            # $VAR1 = [
            #           ':status',
            #           '200',
            #           'apns-id',
            #           '791DE8BA-7CAA-B820-BD2D-5B12653A8DF3'
            #         ];

            print $content;

            # $VAR1 = undef;
        }
    );

=head1 DESCRIPTION

Net::APNS::Simple is APNS Perl implementation.

=head1 LICENSE

Copyright (C) Tooru Tsurukawa.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Tooru Tsurukawa E<lt>rockbone.g at gmail.comE<gt>

=cut

