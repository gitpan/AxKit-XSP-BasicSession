package Apache::AxKit::Plugin::BasicSession;
# $Id: BasicSession.pm,v 1.4 2003/09/09 17:11:30 nachbaur Exp $

use Apache::Session::Flex;
use Apache::Request;
use Apache::Cookie;
use Apache::AuthCookie;
use vars qw( $VERSION %session );

$VERSION = 0.16;

sub handler
{
    my $r = Apache::Request->instance(shift);
    my $debug = $r->dir_config("BasicSessionDebug") || 0;

    # Session handling code
    untie %session if (ref tied %session);
    my $no_cookie = 0;
    my $opts = {};

    $AxKit::XSP::Core::SessionCreator = \&AxKit::XSP::BasicSession::create;

    #
    # Fetch authentication name for this realm, or use the default 'BasicSession'
    # if the user hasn't set this up for handling authentication (e.g. basic session-
    # handling code)
    my $prefix = $r->auth_name || 'BasicSession';

    my %flex_options = (
        Store     => $r->dir_config( $prefix . 'DataStore' ) || 'DB_File',
        Lock      => $r->dir_config( $prefix . 'Lock' ) || 'Null',
        Generate  => $r->dir_config( $prefix . 'Generate' ) || 'MD5',
        Serialize => $r->dir_config( $prefix . 'Serialize' ) || 'Storable'
    );

    #
    # Load session-type specific parameters, comma-separated, name => value pairs
    foreach my $arg ( split( /\s*,\s*/, $r->dir_config( $prefix . 'Args' ) ) )
    {
        my ($key, $value) = split( /\s*=>\s*/, $arg );
        $flex_options{$key} = $value;
    }

    #
    # Read in the cookie if this is an old session, using this realm's name as part
    # of the cookie
    my $cookie = $r->header_in('Cookie');
    my $cookie_id = undef;
    my ($auth_type, $auth_name) = ($r->auth_type, $r->auth_name);
    ($cookie_id) = $cookie =~ /${auth_type}_$auth_name=(\w*)/;

    #
    # Attempt to load the session from our back-end datastore
    eval { tie %session, 'Apache::Session::Flex', $cookie_id, \%flex_options }
        if ($cookie_id and $cookie_id ne '');
    unless ( $session{_session_id} ) {
        warn "Creating a new session, since \"$session{_session_id}\" didn't work.\n"
            if $debug;
        eval { tie %session, 'Apache::Session::Flex', undef, \%flex_options };
        die "Problem creating session: $@" if $@;
        $no_cookie = 1;
    }

    # Might be a new session, so lets give them a cookie
    if (!defined($cookie_id) or $no_cookie) {
        Apache::AuthCookie->send_cookie($session{_session_id});
        $session{_creation_time} = time;
        warn "Set a new header for the session cookie: \"$session_cookie\"\n"
            if $debug;
    }

    # Update the "Last Accessed" timestamp key
    $session{_last_accessed_time} = time;

    warn "Successfully set the session object in the pnotes table\n" 
        if $debug;

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

BasicSession is an AxKit plugin which automatically creates and manages
server-side user sessions.  Based on Apache::Session::Flex, this allows
you to specify all the parameters normally configurable through A:S::Flex.

B<NOTE>: If used in conjunction with the provided AxKit::XSP::BasicAuth module, the
following parameter's names should be changed to reflect your local realm
name.  For instance, "BasicSessionDataStore" should be changed to say
"RealmNameDataStore".  This allows for different configuration parameters
to be given to each realm in your site.

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
with.  These are named similarly to the above parameters, namely the prefix
should reflect your local realm name (or "BasicSession" if you aren't doing
authentication).  For more information, please see L<Apache::AuthCookie>.

=head2 C<AxKit::XSP::BasicSession Support>

This plugin was created to complement AxKit::XSP::BasicSession, but can be used
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

Copyright (c) 2001-2003 Michael A Nachbaur. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

L<AxKit>, L<AxKit::XSP::BasicSession>, L<Apache::Session>, L<Apache::Session::Flex>

=cut
