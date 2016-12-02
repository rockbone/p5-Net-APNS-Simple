# NAME

Net::APNS::Simple - APNS Perl implementation

# SYNOPSIS

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

# DESCRIPTION

Net::APNS::Simple is APNS Perl implementation.

# LICENSE

Copyright (C) Tooru Tsurukawa.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Tooru Tsurukawa <rockbone.g at gmail.com>
