package Apache::AxKit::Plugin::BasicAuth;

use strict;
use Apache;
use AxKit;
use Apache::Constants qw(:common M_GET);
use Apache::AuthCookie;
use Apache::Session::Flex;
use Apache::Util qw(escape_uri);
use Digest::MD5 qw(md5_hex);
use vars qw($VERSION);
use base qw(Apache::AuthCookie);

use constant IN_PROGRESS => 1;

$VERSION = 0.23;

sub authen_cred {
    my $self = shift;
    my $r = shift;
    my @creds = @_;
    AxKit::Debug(10, "[BAuth] Login name given as " . 
		 (defined($Apache::AxKit::Plugin::BasicSession::session{"credential_0"}) 
		  ? $Apache::AxKit::Plugin::BasicSession::session{"credential_0"} : "undef"));
    # Don't call this unless you've authenticated the user.
    return $Apache::AxKit::Plugin::BasicSession::session{"_session_id"}
        if (defined $Apache::AxKit::Plugin::BasicSession::session{"credential_0"});
}

sub authen_ses_key ($$$) {
    my $self = shift;
    my $r = shift;
    my $sess_id = shift;

    AxKit::Debug(9, "[BAuth] SessionID given to authen_ses_key ". (defined($sess_id) ? $sess_id : "undef"));
    # Session handling code
    return $Apache::AxKit::Plugin::BasicSession::session{credential_0}
        if ($Apache::AxKit::Plugin::BasicSession::session{_session_id} eq $sess_id);

    my $prefix = $r->auth_name;

    my %flex_options = (
        Store     => $r->dir_config( $prefix . 'DataStore' ) || 'DB_File',
        Lock      => $r->dir_config( $prefix . 'Lock' ) || 'Null',
        Generate  => $r->dir_config( $prefix . 'Generate' ) || 'MD5',
        Serialize => $r->dir_config( $prefix . 'Serialize' ) || 'Storable'
    );

    # When using Postgres, a different default is needed.  
    if ($flex_options{'Store'} eq 'Postgres') {
        $flex_options{'Commit'} = 1;
	$flex_options{'Serialize'} = $r->dir_config( $prefix . 'Serialize' ) || 'Base64'
    }

    # Load session-type specific parameters
    foreach my $arg ( split( /\s*,\s*/, 
			     $r->dir_config( $prefix . 'Args' ) ) ) {
        my ($key, $value) = split( /\s*=>\s*/, $arg );
        $flex_options{$key} = $value;
    }

    eval { tie %Apache::AxKit::Plugin::BasicSession::session,
	     'Apache::Session::Flex',
	     $sess_id, \%flex_options; };

    AxKit::Debug(9, "[BAuth] Retrieved session has id $Apache::AxKit::Plugin::BasicSession::session{_session_id}.");

    # invoke the custom_errors handler so we don't get fried...
    return (0, 0)
      unless defined
	$Apache::AxKit::Plugin::BasicSession::session{"credential_0"};

    return $Apache::AxKit::Plugin::BasicSession::session{"credential_0"};
}

sub login_form {
    my $self = shift;
    my $r = Apache->request or die "no request";
    my $auth_name = $r->auth_name || 'BasicSession';
    my $cgi = Apache::Request->instance($r);

    # There should be a PerlSetVar directive that gives us the URI of
    # the script to execute for the login form.

    my $authen_script;
    unless ($authen_script = $r->dir_config($auth_name . "LoginScript")) {
        $r->log_reason("PerlSetVar '${auth_name}LoginScript' not set", $r->uri);
        return SERVER_ERROR;
    }

    $r->internal_redirect($authen_script);
}

sub logout {
    my $self = shift;
    my $r    = shift;
    my $session = shift;

    foreach(keys %{$session}) {
        delete $session->{$_} if(/^credential_\d+/);
    }
}

sub custom_errors {
    my ($auth_type, $r, $auth_user, @args) = @_;

    $r->subprocess_env('AuthCookieReason', 'bad_cookie');

    # They aren't authenticated, and they tried to get a protected
    # document.  Send them the authen form.
    return $auth_type->login_form;
}

# This function disabled since we rely on session management for cookie setting.
sub send_cookie { }

1;
