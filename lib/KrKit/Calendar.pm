package KrKit::Calendar;
require Exporter;

use strict; # Choosey programmers' choose strict.
use Date::Calc qw( 	Add_Delta_YMD 
					Day_of_Week
					Day_of_Week_Abbreviation
					Day_of_Week_to_Text 
					Days_in_Month 
					Month_to_Text
					check_date  );

use KrKit::HTML qw( :all );
use KrKit::Validate;

############################################################
# Variables                                                #
############################################################
our @ISA 		= 	qw( Exporter );
our @EXPORT 	= 	qw(	cal_month cal_week cal_year ); 

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# cal_month( $r, etc... )
#-------------------------------------------------
sub cal_month ($$$$$$;@) {
	my ( $r, $root, $month, $year, $select, $function, @params ) = @_;

	if ( ( ! is_integer( $month ) ) || ( $month > 13 ) || ( $month < 1 ) ) {
		return( 'Malformed month.' );
	}

	if ( ( ! is_integer( $year ) ) || ( length( $year ) != 4) ) {
		return( 'Malformed year.' );
	}

	# Fix up some variables.
	my $month_max 	= Days_in_Month( $year, $month ); 
	my $offset 		= Day_of_Week( $year, $month, 1 );
	$offset 		= ( $offset == 7 ) ? 0 : $offset;
	$root 			=~ s/\/$//;

	my @lines = ht_table( { 'cols' => '7' } );

	if ( defined $select && $select ) {

		my ( $syear, $smonth ) = Add_Delta_YMD( $year, $month, 1, 0, -6, 0);

		# Build the month options.
		my @items;
		for my $option ( -6..6 ) {
			push( @items, "$syear/$smonth", Month_to_Text($smonth)." $syear" );

			( $syear, $smonth ) = Add_Delta_YMD( $syear, $smonth, 1, 0, 1, 0);
		}

		# Push on the month select box.
		push( 	@lines,	
				ht_form_js( $root ),
				ht_tr(),
				ht_td( 	{ class => 'head', align => 'center' },
						ht_a( 	( ( ( $month - 1 ) < 1 ) ?
										"$root/". ( $year - 1 ). "/12" : 
										"$root/$year/" . ($month - 1)	), 
								'&lt;&lt;' ) ),

				ht_td( 	{ class => 'head', align => 'center', colspan => '5' },
						ht_select( 	'month', 1, "$year/$month", '', 
									qq!onChange="window.location = '$root/' !.
									q!+ month.options[month.selectedIndex].!.
									q!value;"!, @items ) ),


				ht_td( 	{ class => 'head', align => 'center' },
						ht_a( 	( ( ( $month + 1 ) > 12 ) ?
										"$root/". ( $year + 1 ) . "/1" : 
										"$root/$year/" . ($month + 1) ), 
								'&gt;&gt;' ) ),
				ht_utr(),
				ht_uform() );
	}
	else {
		push( @lines,	ht_tr(),
						ht_td( 	{ 	class => 'head',
								 	align => 'center', 
								 	colspan => '7' }, 
								Month_to_Text( $month ) , " $year" ),
						ht_utr() );
	}

	push( @lines, 	ht_tr(),
					ht_td( 	{ class => 'date', align => 'center' }, 
							Day_of_Week_Abbreviation( 7 ) ) );

	for ( my $i = 1; $i < 7; $i++ ) {
		push( @lines, 	ht_td( 	{ class => 'date', align => 'center' }, 
								Day_of_Week_Abbreviation( $i ) ) );
	}	

	push( @lines, ht_utr() );

	my $extra	= ( ( ( $month_max % 7 ) + $offset ) > 7 ) ? 1 : 0 ;
	my $rows 	= int( $month_max / 7 ) + $extra + 1;

	for ( my $i = 0; $i < $rows; $i++ ) {
		push( @lines, ht_tr() );

		for ( my $j = 1; $j < 8; $j++ ) {
			my $k =  $j + ( $i * 7 ) + ( $offset * -1 );

			if ( ( $k > 0 ) && ( $k < ( $month_max + 1 ) ) ) {
				push( @lines, ht_td( { class => 'day', align => 'center' },
									&$function( $year, $month, $k, @params )) );
			}
			else {
				push( @lines, ht_td( { class => 'day' }, '&nbsp;' ) );
			}
		}
		push( @lines, ht_utr() );
	}
	
	return( @lines, ht_utable() );
} # END cal_month

#-------------------------------------------------
# cal_week( $r, etc... )
#-------------------------------------------------
# Draws one full week. $function is what you want
# it to do for each day in the week.
#-------------------------------------------------
sub cal_week ($$$$$$;@) {
	my ( $r, $root, $day, $month, $year, $function, @params ) = @_;

	# Validate our input.
	return( 'Malformed day.' ) 	if ( ! is_number( $day ) );
	return( 'Malformed month' ) if ( ! is_number( $month ) );
	return( 'Malformed year' ) 	if ( ! is_number( $year ) );
	return( 'Bad Date' ) 		if ( ! check_date( $year, $month, $day ) );

	# Figure some numbers out.
	my( $syear, $smonth, $sday ) = Add_Delta_YMD( $year, $month, $day, 0,0,-3);
	my( $eyear, $emonth, $eday ) = Add_Delta_YMD( $year, $month, $day, 0,0,3);
	my( $lyear, $lmonth, $lday ) = Add_Delta_YMD( $year, $month, $day, 0,0,-6);
	my( $gyear, $gmonth, $gday ) = Add_Delta_YMD( $year, $month, $day, 0,0,6);
	$root =~ s/\/$//;
	
	my @lines=( ht_table( {} ),
				ht_tr(),
	
				ht_td( 	{ class => 'head', align => 'center' },
						ht_a( "$root/$lyear/$lmonth/$lday", '&lt;&lt;' ) ),

				ht_td( 	{ class => 'head', align => 'center', colspan => '5' },
						qq!<SMALL><STRONG>$sday!,
						Month_to_Text( $smonth ),
						qq! $syear -- $eday !, 
						Month_to_Text( $emonth ), qq! $eyear! ),

				ht_td( 	{ class => 'head', align => 'center' },
						ht_a( "$root/$gyear/$gmonth/$gday", '&gt;&gt;' ) ),
				ht_utr(),
				ht_tr() );

	# Blammo, week headers.
	for ( -3..3 ) {
		my $wdt = Day_of_Week_to_Text( Day_of_Week( $syear, $smonth, $sday ) );

		push( @lines, 	ht_td( 	{ class => 'head', align => 'center' },
								qq!<SMALL><STRONG>$wdt</STRONG><BR>!,
								qq!( $syear/$smonth/$sday )! ) );

		( $syear, $smonth, $sday ) = 
						Add_Delta_YMD( $syear, $smonth, $sday, 0, 0, 1);
	}
	
	push( @lines, ht_utr(), ht_tr() );

	# Put on the actual week days now.
	( $syear, $smonth, $sday ) = Add_Delta_YMD( $year, $month, $day, 0, 0, -3);

	for ( -3..3 ) {
		push( @lines, ht_td( { class => 'day' },	
							 &$function( $syear, $smonth, $sday, @params ) ) );

		( $syear, $smonth, $sday ) = 
							Add_Delta_YMD( $syear, $smonth, $sday, 0, 0, 1);
	}

	return( @lines, ht_utr(), ht_utable() );
} # END cal_week

#-------------------------------------------------
# cal_year( $r, etc... )
#-------------------------------------------------
# Draws one full year. Function is what you want
# it to do for every day in the year.
#-------------------------------------------------
sub cal_year ($$$$;@) {
	my ( $r, $root, $year, $function, @params ) = @_;

	if ( ( ! is_number( $year ) ) || ( length( $year ) != 4 ) ) {
		return ( 'Malformed Year.' );
	}

	$root =~ s/\/$//;

	my @lines = ( 	ht_table( { 'cols' => '3' } ),
					ht_tr(),
	
					ht_td( 	{ align => 'left' },
							ht_a( "$root/". ( $year - 1 ), '&lt;&lt;' ) ),

					ht_td( 	{ align => 'center' },
							qq!<BIG><STRONG>$year</STRONG></BIG>! ),

					ht_td( 	{ align => 'right' },
							ht_a( "$root/". ( $year + 1 ), '&gt;&gt;' ) ),

					ht_utr(),
					ht_tr() );

	for ( my $i = 0; $i < 12; $i++ ) {
		push( @lines, ht_utr(), ht_tr() ) if ( ( $i % 3 ) == 0 );

		# Put each month on.
		push( @lines,	ht_td( 	{ class => 'base',  valign => 'top' }, 
								cal_month( 	$r, $root, $i+1, $year, 0, 
											$function, @params ) ) );
	}
	
	return( @lines,
			ht_utr(),
			ht_tr(),

			ht_td( 	{ align => 'left' },
					ht_a( "$root/". ( $year - 1 ), '&lt;&lt;' ) ),

			ht_td( 	{ align => 'center' },
					qq!<big><strong>$year</strong</big>! ),
			
			ht_td( 	{ align => 'right' },
					ht_a( "$root/". ( $year + 1 ), '&gt;&gt;' ) ),

			ht_utr(),
			ht_utable() );
} # END cal_year

# EOF
1;

__END__

=head1 NAME

KrKit::Calendar - Calendar 

=head1 SYNOPSIS

  use KrKit::Calendar;

  cal_month
    @month = cal_month( $r, $root, $month, $year, $select, \&function, @param );

  cal_week
    @week = cal_week( $r, $root, $day, $month, $year, \&function, @param );

  cal_year
    @year = cal_year( $r, $root, $year, \&function, @param );

  \&function
    @day = \&function( $year, $month, $day, @params);

=head1 DESCRIPTION

These module creates a couple calendar views that can be used by other
applications and are highly customizeable. 

=head1 FUNCTIONS 

=over 4

=item @month = cal_month( $r, $root, $month, $year, $select, \&function, @param )

This function creates a month in html for display. C<$r> is the apache
request object. C<$root> is the uri root of the calendar, this is used
for paging. C<$month> and C<$year> are the month and year to show.
C<$select> should be a boolean value, true if the month select is to be
shown, false otherwise. C<\&function> is a function referenc for the
day. C<@params> are any params that need to be passed to C<\&function>

=item @week = cal_week( $r, $root, $day, $month, $year, \&function, @param )

This function creates a week in html for display. C<$r> is the apache
request object. C<$root> is the uri root of the week, this is used for
paging. C<$day>, C<$month>, and C<$year> are the day, month, and year of
the Wednesday of the week. C<\&function> should be a function reference
for the day function. C<@param> is for the parameters for the day
function that will be passed through.

=item @year = cal_year( $r, $root, $year, \&function, @param )

This function creates a year in html for display. C<$r> is the apache
request object. C<$root> is the uri root of the year, this is used for
paging. C<$year> is the year to show. C<\&function> is the day function
to be used. C<@param> are any other params to pass into the day
function. This function uses the cal_month function to create it's
month.

=item @day = \&function( $year, $month, $day, @params)

This is the "day function" it is not defined in this module at all. It
needs to be defined by the user. The function should take the year,
month, and day to show. It should also accept the C<@params> that would
be passed into the cal_* params.

=back

=head1 SEE ALSO

KrKit(3)

=head1 LIMITATIONS

Users must define a day function. IT WILL NOT WORK WITHOUT IT.

=head1 AUTHOR

Nicholas Studt <nstudt@angrydwarf.org>

=head1 COPYRIGHT

Copyright (c) 1999-2005 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
