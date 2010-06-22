package KrKit::AppBase;

require Exporter;

use strict; # Choosey programmers' choose strict.

use Carp qw( croak );
use Net::SMTP;
use POSIX qw( strftime );

############################################################
# Variables                                                #
############################################################
our @ISA 	= qw( Exporter );
our @EXPORT = qw(  	appbase_cookie_retrieve
					appbase_cookie_set
					appbase_get_frame	
					appbase_get_dbparam	
					appbase_sendmail	); 

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# appbase_cookie_retrieve( $r )
#-------------------------------------------------
sub appbase_cookie_retrieve ($) {
	my $r = shift; 

	my $client = $r->headers_in->{ 'Cookie' }; 

	return () if ( ! defined $client ); #|| ! $raw ); 
	
	my %cookies; 

	for my $crumb ( split ( /; /, $client ) ) { 
		my ( $key, $value ) = split( /=/, $crumb ); 
		$cookies{$key} = $value;
 	} 
		
	return( \%cookies );
} # END appbase_cookie_retrieve

#-------------------------------------------------
# appbase_cookie_set( $r, $name, $value, $expire, $path, $domain, $secure )
#-------------------------------------------------
sub appbase_cookie_set ($$$;$$$$) {
	my ( $r, $name, $value, $expire, $path, $dom, $sec ) = @_;

	croak( 'Cookie has no name' ) 	if ( ! defined $name );	
	croak( 'Cookie has no value' ) 	if ( ! defined $value );	

	# Only required fields in the cookie.
	my $cookie = sprintf( "%s=%s; ", $name, $value );

    # these are all optional. and should be created as such.
	if ( defined $expire ) {
    	$expire = 0 if ( $expire !~ /^\d+$/ );
    	$cookie .= strftime( 	"expires=%a, %d-%b-%Y %H:%M:%S GMT; ", 
								gmtime( time + $expire ) );
	}

    $cookie .= sprintf( "path=%s; ", $path ) 	if ( defined $path );
    $cookie .= sprintf( "domain=%s; ", $dom )	if ( defined $dom );
    $cookie .= 'secure' 						if ( defined $sec && $sec );

	# Always use this method, its safe for redirect and error and
	# normal pages as well. .
	$r->err_headers_out->add( 'Set-Cookie', $cookie );

	return();
} # END appbase_cookie_set

#-------------------------------------------------
# appbase_get_frame( $r, $frame )
#-------------------------------------------------
sub appbase_get_frame ($$) { 
	my ( $r, $frames ) = @_;

	croak( 'Invalid apache request object.' ) 	if ( ! defined $r );
	croak( 'No frame supplied.' ) 				if ( ! defined $frames );

	my ( $frame, $module, $framed, $options ) = ( '', '', '' );

	( $frame, $options ) = split( ';', $frames ); 

	# none
	$module = 'KrKit::Framing' 				if ( $frame =~ /^(off|none)$/i );

	# plain
	$module = 'KrKit::Framing::Plain' 		if ( $frame =~ /^plain$/i );

	# template
	$module = 'KrKit::Framing::Template'	if ( $frame =~ /^template/ );

	# other
	$module = $frame						if ( $module eq '' );

	eval { $framed = new $module };

	return( "$framed mod=$frame: $@\n" ) if ( $@ );

	$framed->option( 'template', $options );

	return( $framed );
} # END appbase_get_frame 

#-------------------------------------------------
# appbase_get_dbparam( $r, $auth )
#-------------------------------------------------
sub appbase_get_dbparam ($;$) {
	my ( $r, $auth ) = @_;
	
	croak 'Invalid apache request object.' if ( ! defined $r );

	if ( defined $auth && $auth ) {
		my %db = (	'dbtype'	=>	$r->dir_config( 'AuthDatabaseType' ),
					'usr'		=>	$r->dir_config( 'AuthDatabaseUser' ),
					'pwd'		=>	$r->dir_config( 'AuthDatabasePw' ),
					'srv'		=>	$r->dir_config( 'AuthDatabaseServer' ),
					'db'		=>	$r->dir_config( 'AuthDatabaseName' ),
					'commit'	=> 	$r->dir_config( 'AuthDatabaseCommit' ) );

		# Use these if we have enough.
		return( %db ) if ( defined $db{dbtype} && defined $db{db} );
	}

	return(	'dbtype'	=>	$r->dir_config( 'DatabaseType' ),
			'usr'		=>	$r->dir_config( 'DatabaseUser' ),
			'pwd'		=>	$r->dir_config( 'DatabasePw' ),
			'srv'		=>	$r->dir_config( 'DatabaseServer' ),
			'db'		=>	$r->dir_config( 'DatabaseName' ),
			'commit'	=> 	$r->dir_config( 'DatabaseCommit' ) );
} # END appbase_get_dbparam

#-------------------------------------------------
# appbase_sendmail( $mail )
#-------------------------------------------------
sub appbase_sendmail ($) {
	my $mail = shift; 

	die 'No SMTP host defined' if ( ! defined $$mail{smtp} );

	my $smtp = Net::SMTP->new( $$mail{smtp} ); 
	
	$smtp->mail( $$mail{from} ); 
	
	if ( $$mail{to} =~ /,/ ) {   
		my @recip = split( ',', $$mail{to} );
		$smtp->to( @recip );
	}
	else {   
		$smtp->to( $$mail{to} );
	} 

	$$mail{body} 		= '[No Message body]' if ( ! defined $$mail{body} );
	$$mail{'x-sender'} 	= 'KrKit' if ( ! defined $$mail{'x-sender'} );
	
	$smtp->data();
	$smtp->datasend( "From: $$mail{from}\n" );
	$smtp->datasend( "To: $$mail{to}\n" );
	$smtp->datasend( "Subject: $$mail{subject}\n" );
	$smtp->datasend( "X-Sender: $$mail{'x-sender'}\n" );
	$smtp->datasend( "\n" );

	$smtp->datasend( $$mail{body} );
	
	$smtp->quit; 

	return();
} # END appbase_sendmail

# EOF
1;

__END__

=head1 NAME

KrKit::AppBase - Common functions for web applications

=head1 SYNOPSIS

  use KrKit::AppBase;

  appbase_cookie_retrieve
  	$cookie = appbase_cookie_retrieve( $r );

  appbase_cookie_set
  	appbase_cookie_set( $r, $name, $value, $expire, $path, $domain, $secure );

  appbase_get_frame
    $frame = appbase_get_frame( $r, $frame_name );

  appbase_get_dbparam
    @params = appbase_get_dbparam( $r, $auth );

  appbase_sendmail
    appbase_sendmail( $mail );

=head1 DESCRIPTION

AppBase contains utility functions that may be helpful. These include
dealing with cookies and sending mail.

=head1 FUNCTIONS 

=over 4

=item $cookie = appbase_cookie_retrieve( $r )

This function reads the cookie from the user and parses it into a hash
based on the name of the cookie. This funciton can handle multiple
cookies with different names, though not with the same name. A hash
reference is returned.

=item appbase_cookie_set( $r, $name, $value, $expire, $path, $domain, $secure )

This function creates a cookie and sends it to the user via
err_headers_out which is safe for all response types. The $name and
$value are the only required cookie pieces everything else is optional.
$path is the path for which this cookie applies, $domain is the domain,
$secure is a boolean and if set will only allow the cookie to be sent
over a secure wire. $expire is how many seconds into the future the
cookie should last, if a session only cookie is required do not set the
$expire. 

=item $frame = appbase_get_frame( $r, $frame_name )

Returns a blessed refrence to $frame. $r is the Apache request object.
Will croak if either $r or $frame is undefined.

=item @params = appbase_get_dbparam( $r, $auth )

Returns an array/hash of the directory configuration variables:
DatabaseType, DatabaseServer, DatabaseName, DatabaseUser, DatabasePw,
and DatabaseCommit if $auth is not set.  AuthDatabaseType,
AuthDatabaseServer, AuthDatabaseName, AuthDatabaseUser, AuthDatabasePw,
and AuthDatabaseCommit if $auth is set.  Will croak if $r is not
supplied. For the Auth values to be used the minimum of AuthDatabaseType
and AuthDatabaseName must be set, these are the only two really required
values to connect in most cases.

=item appbase_sendmail( $mail )

$mail is a hash refrence containing the variables 'smtp', 'from', 'to', 'body', 'subject', and 'x-sender. The only required one of this hash is 'smtp', though
it would be more constuctive to fill in the 'to', 'from' and 'body' fields.

=back

=head1 SEE ALSO

KrKit(3)

=head1 LIMITATIONS

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
