package KrKit::Framing;

use strict; # Choosey programmers' choose strict.

use Carp qw( croak );

use Apache2::RequestIO;

use KrKit::HTML qw( :all );

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# new
#-------------------------------------------------
sub new ($) {
	my $proto = shift;

	my $class = ref( $proto ) || $proto;
    my $self = {};

	$self->{option} = {};

    bless( $self, $class );

    return( $self );
} # END new 

#-------------------------------------------------
# $self->index( $r, $site )
#-------------------------------------------------
sub index {
	my ( $self, $r, $site ) = @_;

	# Set up some defaults.
	my @p 		= split( '/', $r->uri );
	my $docroot = $r->document_root;
	my $index	= '.index';
	my $path	= '';

	if ( scalar( @p ) > 1 ) {
		do {
			return( "Error: No $index" ) if ( scalar( @p ) < 1 );
			pop( @p );
			$path = join( '/', @p ) || '';

		} while ( ! -e "$docroot/$path/$index" );
	}

	return ( '' ) if ( ! defined $path );

	# Read in the index.
	open ( LIST, "$docroot/$path/$index" ) or die "Error: $!";
	
	my @listing = <LIST>;

	close ( LIST );

	# Grab the title row.
	my ( $title, $sort ) 	= split( /\|/, shift( @listing ) );
	$title 					= '' if ( ! defined $title );
	$sort 					= '' if ( ! defined $sort );
	@listing 				= sort( @listing ) if ( $sort =~ /sorted/ );
	my @lines 				= ( ht_h( '1', $title ) );

	# Walk through the index.
	for my $line ( @listing ) {
		next if ( $line =~ /^#/ );
		next if ( $line eq '' );
		next if ( $line =~ /^\s+$/ );

		chop $line;
		
		my ( $name, $url, $type ) = split( /\|/, $line );

		# Make sure we don't break outside links.
		if ( $url !~ /tp:\/\// ) {
			$$site{rootp} = '' if ( ! defined $$site{rootp} );
			( $url = "$$site{rootp}/$path/$url" ) =~ s/\/+/\//g; 
		}

		if ( defined $type ) {
			if ( $type =~ /subhead/ ) {
				push( @lines, ht_h( '2', ht_a( $url, $name, 'class="nav"' ) ) );
			}
			else {
				push( @lines, ht_a( $url, $name, 'class="nav"' ), ht_br() );
			}
		}
		else {
			push( @lines, ht_a( $url, $name, 'class="nav"' ), ht_br() );
		}
	}

	return( ht_lines( @lines ) );
} # END index

#-------------------------------------------------
# option( $option, $value )
#-------------------------------------------------
sub option ($$;$) {
	my ( $self, $option, $value ) = @_;

	croak 'Undefined option name to option()' if ( ! defined $option );

	if ( defined $value ) {
		$$self{option}{$option} = $value;
	}
	else {
		return( $$self{option}{$option} );
	}
} # END option

#-------------------------------------------------
# $self->send( $r, $site )
#-------------------------------------------------
sub send ($$$) {
	my ( $self, $r, $site ) = @_;

	if ( defined $$site{body_file} ) {
		$r->sendfile( $$site{body_file} );
	}
	else {
		$r->print( $$site{body_text} );
	}

	return();
} # END send 

# EOF
1;

__END__

=head1 NAME

KrKit::Framing - Framing Utility 

=head1 SYNOPSIS

  use KrKit::Framing;

  new
    my $frame = KrKit::Framing->new(); 

  index
    @index = $frame->index( $r, $site );

  option
	$frame->option( 'option_name', 'option_value' );	
	my $value = $frame->option( 'option_name' );

  send
    $frame->send( $r, $site );

=head1 DESCRIPTION

This is the core of the framing system in use by the KrKit libraries. 
The other Framing objects inherit most of these functions.

=head1 FUNCTIONS 

=over 4

=item my $frame = KrKit::Framing->new()

Creates a new instance of the Framing class that can be used to send output
to a browser. The variable $frame should contain a module in double colon 
notation ( ie Frames::MyFrame ). The included module will override the 
base send function.

=item @index = $frame->index( $r, $site )

This function deals with the .index menu building system. The menus are
supposed to be called .index. This function will walk backwards up the
tree to find one.

=item $frame->option( 'option_name', 'option_value' )

=item my $value = $frame->option( 'option_name' )

This method can be used to set options and view options on a frame. 
If only the 'option_name' is provided it will return the value, if the 
name and the value are provided it will set the value to the frame.

=item $frame->send( $r, $site )

Prints out $$site{body_text}, nothing more. Other frames, which will override
this function provide additional functionality, such as printing from
filehandles if they have one passed in. $r is the apache request object.
This method can also use C<< $r->sendfile >> to send out a open file handle
if it is in the 'body_file' value of the hash reference passed in.

=back

=head1 SEE ALSO

KrKit(3), KrKit::Framing::Plain(3)

=head1 LIMITATIONS

Other methods will inherit from this method. This method should not
be used directly.

=head1 AUTHOR 

Written by Nicholas Studt.

=head1 COPYRIGHT

Copyright (c) 1999-2005 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
