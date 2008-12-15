package KrKit::DB;
require Exporter;

use strict; # Choosey programmers' choose strict.
use utf8;

use Carp qw( croak );
use DBI;

############################################################
# Variables                                                #
############################################################
our @ISA 	= qw( Exporter );
our @EXPORT = qw( 	db_commit
					db_connect
					db_disconnect
					db_finish
					db_getnamespace 
					db_lastseq
					db_next
					db_nextvals	
					db_query
					db_rollback
					db_rowcount
					db_run		); 

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# db_commit( $dbh )
#-------------------------------------------------
sub db_commit ($) {
	my $handle = shift;

	$handle->commit if ( $handle->{AutoCommit} == 0 );

	return();
} # END db_commit

#-------------------------------------------------
# db_connect()
#-------------------------------------------------
sub db_connect {
	my ( $db_type, $user, $pass, $server, $db, $commit );

	# Setup the variables, sanity check it too.
	if ( $_[0] =~ /^(dbtype|usr|pwd|db|srv|commit)$/ ) { # It's a hash
		my %settings = @_;
	
		$db_type	= $settings{dbtype} || '';
		$user 		= $settings{usr} 	|| '';
		$pass 		= $settings{pwd} 	|| '';
		$db 		= $settings{db} 	|| '';
		$server		= $settings{srv} 	|| '';
		$commit 	= $settings{commit} || '';

		$commit 	= ( $commit =~ /off/i ) ? 0 : 1 ; 
	}
	else {
		( $db_type, $user, $pass, $server, $db, $commit ) = @_;
	
		$db_type 	= '' 	if ( ! defined ( $db_type ) );
		$user 		= '' 	if ( ! defined ( $user ) );
		$pass 		= '' 	if ( ! defined ( $pass ) );
		$server 	= '' 	if ( ! defined ( $server ) );
		$db 		= '' 	if ( ! defined ( $db ) );
		$commit 	= '1' 	if ( ! defined ( $commit ) );
		$commit 	= ( $commit =~ /off/i ) ? 0 : 1 ; 
	}

	croak 'No Database Type defined' if ( length( $db_type ) < 1 );

	my $dsn = "dbi:$db_type:dbname=$db"; 

 	$dsn .= ( $server eq '' ) ? '' : ";host=$server";

	my $dbh = DBI->connect( $dsn, $user, $pass, 
  							{   RaiseError  =>  0,
								PrintError  =>  1,
								AutoCommit  =>  $commit } ) or
								croak( "DB Connection error: '$DBI::err'" );

	return( $dbh );
} # END db_connect 

#-------------------------------------------------
# db_disconnect( $dbh )
#-------------------------------------------------
sub db_disconnect ($) {
	my $handle = shift;

	$handle->rollback if ( $handle->{AutoCommit} == 0 );

	$handle->disconnect;

	return;
} # END db_disconnect 

#-------------------------------------------------
# db_finish( $sth )
#-------------------------------------------------
sub db_finish ($) {
	my $handle = shift;

	$handle->finish;

	return();
} # END db_finish

#-------------------------------------------------
# db_getnamespace( $dbtype, $namespace )
#-------------------------------------------------
sub db_getnamespace ($$) {
	my ( $dbtype, $namespace ) = @_;

	# FIXME: Add mysql, oracle, ....

	# Make sure the namespace is sane based on the DB Type
	if ( $dbtype eq 'Pg' ) {
		$namespace = 'public.' 	if ( ! defined $namespace );
		$namespace .= '.' 		if ( $namespace !~ /\.$/ );
	}

	return( $namespace );
} # END db_getnamespace

#-------------------------------------------------
# db_lastseq( $dbh, $sequence_name )
#-------------------------------------------------
sub db_lastseq ($$) {
	my ( $handle, $seq ) = @_;

	croak "No database handle for db_lastseq: $!\n" unless ( defined $handle );

	if ( ! defined $seq ) {
		$handle->rollback if ( $handle->{AutoCommit} );
		croak "No sequence for db_lastseq: $!\n";
	}

	my $sth = db_query ( $handle, "db_lastseq getting last value",
						 "SELECT last_value FROM $seq;" );

	my ( $last_value ) = db_next ( $sth );

	db_finish ( $sth );

	return ( $last_value );

} # END db_lastseq

#-------------------------------------------------
# db_next( $sth )
#-------------------------------------------------
sub db_next ($) {
	my $handle = shift;

	croak "Error: db_next() not given a handle, $!\n" if ( ! $handle );
	
	return( $handle->fetchrow );	
} # END db_next 

#-------------------------------------------------
# db_nextvals( $sth )
#-------------------------------------------------
sub db_nextvals {
	my $handle = shift; 
   
	if( ! $handle ) {
   		croak "Query error db_nextvals() not given a statement: $!\n";
	}
	
	return( $handle->fetchrow_hashref );

} # END db_nextvals

#-------------------------------------------------
# db_query( $dbh, $description, @query )
#-------------------------------------------------
sub db_query ($$@) {
	my ( $handle, $description, @query ) = @_;

	if ( ! defined ( $handle ) ) {
		croak "Error $description: db_query not given a connection: $!\n";
	}

	if ( length ( @query ) == 0 ) {
		$handle->rollback if ( $handle->{AutoCommit} == 0 );
		croak "Error $description: db_query not given any SQL: $!\n";
	}

	my $sql = join ( "\n", @query );

	my $sth = $handle->prepare( $sql );
	
	$sth->execute or do 
		{
			$handle->rollback if ( $handle->{AutoCommit} == 0 );
			croak "SQL Query Error ( $description ): $sql\n";
		};

	return( $sth );
} # END db_query 

#-------------------------------------------------
# db_rollback( $sth )
#-------------------------------------------------
sub db_rollback ($) {
	my $handle = shift;

	$handle->rollback;

	return;
} # END db_rollback

#-------------------------------------------------
# db_rowcount( $sth )
#-------------------------------------------------
sub db_rowcount ($) {
	my $handle = shift;

	return( $handle->rows );
} # END db_rowcount

#-------------------------------------------------
# db_run( $dbh, $description, @sql )
#-------------------------------------------------
sub db_run ($$@) {
	my ( $handle, $description, @sql ) = @_;

	if ( ! defined ( $handle ) ) {
		croak "Error $description: db_run() not given a connection: $!\n";
	}

	if ( length ( @sql ) == 0 ) {
		$handle->rollback if ( $handle->{AutoCommit} == 0 );
		croak "Error $description: db_run() was not given any SQL: $!\n";
	}

	my $command = join ( "\n", @sql );

	$handle->do( $command ) or do 
			{
				$handle->rollback if ( $handle->{AutoCommit} == 0 );
				croak "SQL Query Error ($description): $command\n".
					  $handle->errstr. "\n";
			};

	return;
} # END db_run

# EOF
1;

__END__

=head1 NAME

KrKit::DB - Database wrapper fucntions, specfic to PostgreSQL

=head1 SYNOPSIS

  db_commit
    db_commit( $dbh );

  db_connect
    $dbh = db_connect( $db_type, $user, $pass, $server, $db, $commit );
    $dbh = db_connect( %config_hash );

  db_disconnect
    db_disconnect( $dbh );

  db_finish
    db_finish( $sth );
  
  db_getnamespace
    $proper_namespace = db_getnamespace( $db_type, $db_namespace );

  db_lastseq
    $last_value = db_lastseq( $dbh, $sequence_name );

  db_next
    ( @values ) = db_next( $sth );

  db_nextvals
    $hash_reference = db_nextvals( $handle );

  db_query
    $sth = db_query( $dbh, $description, @sql_query );

  db_rollback
    db_rollback( $dbh );

  db_rowcount
    $rows = db_rowcount( $sth );

  db_run
	db_run( $dbh, $description, @sql_query );

=head1 DESCRIPTION

These functions wrap the common DBI calls to Databases with error
checking. 

=head1 FUNCTIONS 

=over 4

=item db_commit( $dbh )

Takes a database handle and commits all pending transactions if AutoCommit is
not enabled, otherwise does nothing. Returns no value.

=item $dbh = db_connect( %config_hash )

=item $dbh = db_connect( $db_type, $user, $pass, $server, $db, $commit )

Creates a connection to the database specified by $db on host $server. It then
returns a $dbh variable containing the connection. The hash has the values
db_type, usr, pwd, db, srv, commit for the respective variables. Commit 
should be specified as the text 'on' or 'off', case does not matter.
'db_type' should be a valid DBI database type ( eg. 'Pg' for postgres. ).

=item db_disconnect( $dbh )

Takes a database handle and disconnects that connection to the database,
it will also rollback any pending transactions that have not been commited 
with db_commit(). Returns no value.

=item db_finish( $sth )

Finishes a statement handle after a db_query() is completed. Returns nothing.
    
=item $proper_namespace = db_getnamespace( $db_type, $db_namespace );

This function ensures that the namespace is properly formed for the
particular db_type. The default return for namespace is the default
namespace that each database uses. For example, the default for
PostgreSQL is "public.".

=item $last_value = db_lastseq( $dbh, $sequence_name )

Takes a database handle and the name of the sequence. It returns the last 
value that the sequence handed out. Usefully during transactions when 
the id of the last inserted SQL is needed. Will croak() if there is no
database handle passed in or if no sequence is passed in. If no sequence
is passed in, before croak()ing it will preform a rollback.

=item ( @values ) = db_next( $sth )

Takes a statement handle and returns the next row as an array. The function
will croak() if there is no statement handle passed in.

=item $hash_reference = db_nextvals( $sth )

This function takes a sql statement handle, C<$sth>, and returns the next
row from the statement as a hash reference with the column names as 
the keys and the values set from the row in the query.

=item $sth = db_query( $dbh, $description, @sql_query )

This function takes a database handler, C<$dbh>, a description of the 
call, C<$description>, and a sql query, C<@sql_query>. The sql query can 
be either an array or a string, it will be joined with spaces if it is
an array. The query is then run against the database specified in C<$dbh>. 
The function will return a statment handler, C<$sth>, or if there is an 
error while executing the sql query it will C<croak()>.

=item db_rollback( $dbh )

Takes a database handle and preforms a rollback on the handle. Returns nothing.

=item $rows = db_rowcount( $sth )

Takes a statement handle and returns an integer count of the number of 
rows affected in the statement handle ( ie. the number of rows in a select ).

=item db_run( $dbh, $description, @sql_query )

This function behaves identcally to C<db_query()>, save it uses the DBI->do
vs the DBI->execute method to run the sql query. This means this function
will never return a statement handle.

=back

=head1 SEE ALSO

KrKit::SQL(3), DBI(3), DBD::Pg(3)

=head1 LIMITATIONS

This library is untested with databases other than Postgresql.

=head1 AUTHOR

Nicholas Studt <nstudt@angrydwarf.org>

=head1 COPYRIGHT

Copyright (c) 1999-2005 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
