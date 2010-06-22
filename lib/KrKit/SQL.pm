package KrKit::SQL;
require Exporter;

use strict; # Choosey programmers' choose strict.
use utf8;

use Carp qw( confess );

############################################################
# Variables                                                #
############################################################
our @ISA 	= qw( Exporter );
our @EXPORT = qw( 	sql_bool 
					sql_insert
					sql_num
					sql_str
					sql_update
					sql_quote 	); 

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# sql_bool( $bool_string )
#-------------------------------------------------
sub sql_bool ($) {
	my $input = shift;

	return( 'FALSE' ) if ( ( ! defined $input ) || ( ! length $input ) );

	if ( $input =~ /^(t|y|1)$/i ) {
		return( 'TRUE' );
	}
	elsif ( $input =~ /^(f|n|0)$/i ) {
		return( 'FALSE' );
	}
	elsif ( defined $input ) {
		return( 'TRUE' );
	}
	else {
		return( 'FALSE' );
	}
} # END sql_bool

#-------------------------------------------------
# sql_insert( $table, %data )
#-------------------------------------------------
sub sql_insert ($%) {
	my ( $table, @vals ) = @_;

	my ( @fields, @values );

	while ( @vals ) {
		push ( @fields, shift( @vals ) );
		
		if ( @vals ) {
			push( @values, shift( @vals ) );
		}
		else {
			confess( 'Error: Incorrect number of arguements.' );
		}
	}

	return( "INSERT INTO $table ( ". join( ', ', @fields ). ' ) VALUES ( '. 
			join( ', ', @values ). ' )' );
} # END sql_insert 

#-------------------------------------------------
# sql_num( $number )
#-------------------------------------------------
sub sql_num ($) {
	my $number = shift;

	return( 'NULL' ) if ( ( ! defined $number ) || ! length ( $number) );

	$number =~ s/\\/\\\\/g;
	$number =~ s/\'/\\'/g;
	
	return( "'$number'" );
} # END sql_num

#-------------------------------------------------
# sql_str( $string )
#-------------------------------------------------
sub sql_str ($) {
	my $string = shift;

	return( "''" ) if ( !defined( $string ) || ! length( $string ) );

	$string =~ s/\\/\\\\/g;
	$string =~ s/\'/\\'/g;

	return( "'$string'" );
} # END sql_str

#-------------------------------------------------
# sql_update( $table, $clause, $data )
#-------------------------------------------------
sub sql_update ($$%) {
	my ( $table, $clause, @vals ) = @_;

	$clause = '' if ( ! defined $clause );

	my @updates;

	while ( @vals ) {
		my $field = shift( @vals );
		
		if ( @vals ) {
			push( @updates, "$field=". shift( @vals ) );
		}
		else {
			confess( 'Error: Incorrect number of arguements.' );
		}
	}

	return( "UPDATE $table SET ". join( ', ', @updates ). ' '. $clause );
} # END sql_update

#-------------------------------------------------
# sql_quote( $string )
#-------------------------------------------------
sub sql_quote ($) {
	my $sql = shift;

	return( '' ) if ( ! defined $sql );

 	$sql =~ s/\\/\\\\/g;
	$sql =~ s/'/''/g;

	return( $sql );
} # END sql_quote

# EOF
1;

__END__

=head1 NAME 

KrKit::SQL - SQL quoting routines.

=head1 SYNOPSIS

  sql_bool
    $sql_boolean = sql_bool( $string );

  sql_insert
    $sql = sql_insert( $table, %vals );

  sql_num
    $sql_number = sql_num( $number );

  sql_str
    $sql_string = sql_str( $string );

  sql_update
    $sql = sql_update( $table, $clause, %vals );

  sql_quote
    $sql_quoted = sql_quote( $string );

=head1 DESCRIPTION

This module supplies easy ways to make strings sql safe as well as 
allowing the creation of sql commands. All of these commands should 
work with any database as they do not do anything database specfic, 
well as far as I know anyways.

=head1 FUNCTIONS 

=over 4

=item $sql_boolean = sql_bool( $string )

This function takes a string and returns either TRUE or FALSE depending 
on whether or not the function thinks it's true or not. True is defined 
as containing any of the following, 't', 'y', '1', or after
the false test if the string is defined. False is defined as 'f', 'n' or '0'.
Defined and not false is true, and not defined is false. Hopefully this 
is fairly confusing. 

=item $sql = sql_insert( $table, %vals )

This function takes the table to insert into C<$table'>, and the information
to insert into said table, C<%vals>. The function will build an insert 
statement based on this information. The C<%vals> variable should contain
the keys corrisponding to the columns in the database where the values
should be the values to insert into those fields. The function will return,
hopefully, a valid sql insert string.

=item $sql_number = sql_num( $number )

This function takes a number, C<$number>, and quotes it in such a way as 
it may be used in a sql call safely. It handles anything that is a number 
at all. A properly quoted number is return, including the quotes.

=item $sql_string = sql_str( $string )

This function takes a string, C<$string>, and quotes in in such a way as 
it may be used safely in a sql call. The string is then returned, including
the quotes arround it.

=item $sql = sql_update( $table, $clause, %vals )

This function creates a valid sql update string. It is identical in form
to the C<sql_insert()> function save it takes a where clause, C<$clause>.
The clause must contain a valid test against the database, in a pinch use
a where clause that will always return true. The 'WHERE' in the clause need
not be supplied as it is assumed and alwas inserted into the update string.
A valid sql update string is returned, hopefully anyways.

=item $sql_quoted = sql_quote( $string )

This function works the same way as C<sql_str()> save it doesn't really
care what it opperates on. A properly quoted version of whatever is passed
in is returned.

=back

=head1 SEE ALSO

KrKit(3), KrKit::DB(3)

=head1 LIMITATIONS

There is no sql_date function, which there probably should be.

The quoting method has been tested with Postgresql.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
