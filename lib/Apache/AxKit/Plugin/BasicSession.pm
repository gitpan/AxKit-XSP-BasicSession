package Apache::AxKit::Plugin::BasicSession;
use Apache::Session::Flex;
use Apache::Request;
use Apache::Cookie;
use constant DEBUG => 0;
use lib qw( $VERSION %session );

$VERSION = 0.14;

sub handler
{
    my $r = Apache::Request->instance(shift);

    # Session handling code
    untie %session if (ref tied %session);
    my $no_cookie = 0;
    my $opts = {};

    # Load the configuration parameters
    my $cfgDataStore = $r->dir_config( 'BasicSessionDataStore' );
    my $cfgLock      = $r->dir_config( 'BasicSessionLock' );
    my $cfgGenerate  = $r->dir_config( 'BasicSessionGenerate' );
    my $cfgSerialize = $r->dir_config( 'BasicSessionSerialize' );

    my %flex_options = 
    (
        Store     => $cfgDataStore || 'DB_File',
        Lock      => $cfgLock      || 'Null',
        Generate  => $cfgGenerate  || 'MD5',
        Serialize => $cfgSerialize || 'Storable'
    );

    # Load session-type specific parameters
    foreach my $arg ( split( /\s*,\s*/, $r->dir_config( 'BasicSessionArgs' ) ) )
    {
        my ($key, $value) = split( /\s*=>\s*/, $arg );
        $flex_options{$key} = $value;
    }

    # Read in the cookie if this is an old session
    my $cookie = $r->header_in('Cookie');
    {
        # eliminate logging of Apache::Session warn messages
        local $^W = 0;

        $cookie =~ s/SESSION_ID=(\w*)/$1/;
        if ( $cookie ) {
            print STDERR "Loading existing session: \"$cookie\"\n" if DEBUG;
            eval { tie %session, 'Apache::Session::Flex', $cookie, \%flex_options; };
        }
        unless ( $session{_session_id} )
        {
            print STDERR "Creating a new session, since \"$session{_session_id}\" didn't work.\n" if DEBUG;
            eval { tie %session, 'Apache::Session::Flex', undef, \%flex_options; };
            $no_cookie = 1;
        }
    }

    # Might be a new session, so lets give them a cookie
    if (!defined($cookie) || $no_cookie)
    {
        my %cookie_options = ();
        $cookie_options{'-expires'} = $r->dir_config('BasicSessionCookieExpires');
        $cookie_options{'-domain'} = $r->dir_config('BasicSessionCookieDomain');
        $cookie_options{'-path'} = $r->dir_config('BasicSessionCookiePath');
        if ($r->dir_config('BasicSessionCookieSecure') =~ /yes/) {
            $cookie_options{'-secure'} = 1;
        }
        my $session_cookie = Apache::Cookie->new($r,
            -name => 'SESSION_ID',
            -value => $session{_session_id},
            %cookie_options,
        );
        $session_cookie->bake;
        $session{_creation_time} = time;
        print STDERR "Set a new header for the session cookie: \"$session_cookie\"\n" if DEBUG;
    }

    # Update the "Last Accessed" timestamp key
    $session{_last_accessed_time} = time;

    print STDERR "Successfully set the session object in the pnotes table\n" if DEBUG;

    $r->push_handlers(PerlCleanupHandler => \&cleanup);
    return OK;
}

sub cleanup {
    my $r = shift;
    untie %session;
}

1;

__END__

=head1 NAME

Apache::AxKit::Plugin::BasicSession - AxKit plugin that handles setting / loading of Sessions

=head1 SYNOPSIS

    AxAddPlugin Apache::AxKit::Plugin::BasicSession
    PerlSetVar BasicSessionDataStore DB_File
    PerlSetVar BasicSessionArgs "FileName => /tmp/session"

=head1 DESCRIPTION

Session is an AxKit plugin which automatically creates and manages
server-side user sessions.  Based on Apache::Session::Flex, this allows
you to specify all the parameters normally configurable through ::Flex.

=head1 Parameter Reference

=head2 C<BasicSessionDataStore>

Sets the backend datastore module.  Default: DB_File

=head2 C<BasicSessionLock>

Sets the record locking module.  Default: Null

=head2 C<BasicSessionGenerate>

Sets the session id generation module.  Default: MD5

=head2 C<BasicSessionSerialize>

Sets the hash serializer module.  Default: Storable

=head2 C<BasicSessionArgs>

Comma-separated list of name/value pairs.  This is used to pass additional
parameters to Apache::Session::Flex for the particular modules you select.
For instance: if you use MySQL for your DataStore, you need to pass the
database connection information.  You could pass this by calling:

    PerlSetVar BasicSessionArgs "DataSource => dbi:mysql:sessions, \
                                 UserName   => session_user, \
                                 Password   => session_password"

=head2 C<BasicSessionCookie*>

These arguments set the parameters your session cookie will be created
with.  The possible options are "BasicSessionCookiePath", "BasicSessionCookieDomain",
"BasicSessionCookieExpires", "BasicSessionCookieSecure".  All options take an arbitrary
string, except Expires and Secure.  BasicSessionCookieSecure takes a boolean (yes or no)
while Expires takes a time interval (for more information, please see L<Apache::Cookie>).

=head2 C<AxKit::XSP::Session Support>

This plugin was created to complement AxKit::XSP::Session, but can be used
without the taglib.

Every session access, the session key "_last_accessed_time" is set to the current
date-timestamp.  When a new session is created, the session key "_creation_time" is
set to the current date-timestamp.

=head1 ERRORS

To tell you the truth, I haven't tested this enough to know what happens when it fails.
I'll update this if any glaring problems are found.

=head1 AUTHOR

Michael A Nachbaur, mike@nachbaur.com

=head1 COPYRIGHT

Copyright (c) 2001 Michael A Nachbaur. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

AxKit, AxKit::XSP::Session, Apache::Session, Apache::Session::Flex

=cut
