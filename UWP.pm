package Games::Traveller::UWP;
#
#   History
#
#   Date             Reason
#   ---------------- -------------------------------------------------
#   17 Sept 2004     Adding a displacement method
#   06 Oct  2004     Reworking the trade code section
#   21 Oct  2004     Added TAS package structure, trade index
#   26 Oct  2004     Tidying up for upload.
#
use strict;
use vars qw(@ISA @EXPORT_OK $VERSION);

require Exporter;
@ISA       = qw( Exporter  );
@EXPORT_OK = qw( createUwp );
$VERSION   = '0.9';

{
   my @hex = ( 0..9, 'A'..'H', 'J'..'N', 'P'..'Z' );
   my %hex2dec = ();
   for( my $i=0; $i<@hex; $i++ )
   {
      $hex2dec{$hex[$i]} = "$i";
   }
   
   
   my ( %name, 
        %loc, 
        %uwp, 
        %base, 
        %codes, 
        %zone, 
        %pbg, 
        %alleg, 
        %stars, 
        %xboat,
        %rowXlt,
        %colXlt );


   sub DESTROY 
   {
       my $self = 0+shift;
       delete  $name  {$self}
              ,$loc   {$self}
              ,$uwp   {$self}
              ,$base  {$self}
              ,$codes {$self}
              ,$zone  {$self}
              ,$pbg   {$self}
              ,$alleg {$self}
              ,$stars {$self}
              ,$xboat {$self}
              ,$rowXlt{$self}
              ,$colXlt{$self}
              ;
   }
   

   my %translation;
   
   setTranslation( 0, 0 );

   my $sector = 'unknown';
   my $hashFunction = \&setHashCode;


   sub new { bless {}, shift; }
      
      
   sub createUwp
   {
      my $line = shift;
      my $min  = shift;  # min clip window
      my $max  = shift;  # max clip window
   
      # Do some command processing
      if ( $line =~ /^Sector: (\w+)( Sector)?/ )
      {
         my $sector = $1;
         print STDERR "$sector\n";
         &$hashFunction( $sector ) if $hashFunction;
         if (setTranslation(0,0)) { print STDERR "  xn-reset\n"; }
      }
      
      if ( $line =~ /^\s*offset:\s+rows?\s*=\s*(\w+)\s+cols?\s*=\s*(\w+)\s*(quadrants|subsectors|sectors|parsecs)?/i )
      {
         my $prow  = $1;
         my $pcol  = $2;
         my $units = $3 || 'parsecs';
         
         $prow *= 40 if $units eq 'sectors';
         $pcol *= 32 if $units eq 'sectors';
         
         $prow *= 20 if $units eq 'quadrants';
         $pcol *= 16 if $units eq 'quadrants';
         
         $prow *= 10 if $units eq 'subsectors';
         $pcol *=  8 if $units eq 'subsectors';
         
         print STDERR "  xn-set( $prow, $pcol pc)\n";
         setTranslation($prow,$pcol);
         return 0;
      }
      
      return 0 unless $line =~ /^(.*)(\d{4}) (\w{7}-\w) /;
      
      # Convert really really old format into new format.
      $line = sprintf( "%-49s 001 ?? ??", $1) if $line =~ /^(.{29,50}\s*)G\s*$/;
      $line = sprintf( "%-49s 000 ?? ??", $1) if $line =~ /^(.{29,50})\s*$/;
      $line =~ s/\n//;
            
      my $self = new Games::Traveller::UWP();      
      $_    = $line;
      my $post;  
         
      ($self->name, $self->loc,   $self->uwp,   $post) 
         = /^(.*)(\d{4}) (\w{7}-\w) (.*)$/;
         
      ($self->base, $self->codes, $post) 
         = $post =~ /^\s?(.) (.{15}) (.*)$/;

      ($self->zone, $self->pbg, $post) 
         = $post =~ /^\s*(.) (\d{3})(.*)$/;
      
      ($self->alleg, $self->stars, $self->xboat)
         = $post =~ /\s?(..) ([^:]*)(:.*)?/; 
                   
      return 0 unless $self->uwp;
      
      $self->codes = '' unless $self->codes =~ /\w/;
      $self->xboat = '' unless $self->xboat && $self->xboat =~ /\S/;
      
      
      # apply the clipping filter, if need be.
      
      if ( $min || $max )
      {
         my ($c,  $r)  = $self->loc =~ /(\d\d)(\d\d)/;
         my ($c1, $r1) = $min =~ /(\d\d)(\d\d)/;
         my ($c2, $r2) = $max =~ /(\d\d)(\d\d)/;
   
         return 0 unless 
                     $r >= $r1
                  && $r <= $r2 
                  && $c >= $c1
                  && $c <= $c2;
      }
   
      $self->rowXlt = $translation{row};
      $self->colXlt = $translation{col};
            
#      $self->translate();
      return $self;
   }   
   
   
   
   
   # read-write methods
   
   sub sector     : lvalue {$sector}
   sub hashFunc   : lvalue {$hashFunction}
   sub rowXlt     : lvalue {$rowXlt    {+shift}}
   sub colXlt     : lvalue {$colXlt    {+shift}}
   sub name       : lvalue {$name      {+shift}}
   sub loc        : lvalue {$loc       {+shift}}
   sub uwp        : lvalue {$uwp       {+shift}}
   sub base       : lvalue {$base      {+shift}}
   sub codes      : lvalue {$codes     {+shift}}
   sub zone       : lvalue {$zone      {+shift}}
   sub pbg        : lvalue {$pbg       {+shift}}
   sub alleg      : lvalue {$alleg     {+shift}}
   sub stars      : lvalue {$stars     {+shift}}
   sub xboat      : lvalue {$xboat     {+shift}}
   
   
   
   
   # read-only methods
   
   sub col      { ($loc{+$_[0]} =~ /^(..)/)[0] + $colXlt{+$_[0]}     }
   sub row      { ($loc{+$_[0]} =~ /(..)$/)[0] + $rowXlt{+$_[0]}     }
   
   sub starport { ($uwp{+shift} =~ /^(.)/)[0];      }
   sub size     { ($uwp{+shift} =~ /^.(.)/)[0];     }
   sub atm      { ($uwp{+shift} =~ /^..(.)/)[0];    }
   sub hyd      { ($uwp{+shift} =~ /^...(.)/)[0];   }
   sub popul    { ($uwp{+shift} =~ /^....(.)/)[0];  }
   sub gov      { ($uwp{+shift} =~ /(.).-.$/)[0];   }
   sub law      { ($uwp{+shift} =~ /(.)-.$/)[0];    }
   sub tl       { ($uwp{+shift} =~ /(.)$/)[0];      }
   
   sub pm       { ($pbg{+shift} =~ /^(.)/)[0];      }
   sub belts    { ($pbg{+shift} =~ /^.(.)/)[0];     }
   sub ggs      { ($pbg{+shift} =~ /(.)$/)[0];      }
   
   sub primary  { $stars{+shift}->[0];         }
   
   
   
   
   # trade code read-only methods
   
   sub isBa($) { (popul($_[0]) eq '0')   && 'Ba '; }
   sub isLo($) { (popul($_[0]) =~ /0-4/) && 'Lo '; }
   sub isHi($) { (popul($_[0]) =~ /9A/)  && 'Hi '; }
   sub isAg($) { ($uwp{+shift} =~ /^..[4-9][4-8][5-7]/) && 'Ag '; }
   sub isNa($) { ($uwp{+shift} =~ /^..[0-3][0-3][6-A]/) && 'Na '; }
   sub isIn($) { ($uwp{+shift} =~ /^..[012479].[9A]/)   && 'In '; }
   sub isNi($) { ($uwp{+shift} =~ /^....[0-6]/)         && 'Ni '; }
   sub isRi($) { ($uwp{+shift} =~ /^..[6-8].[6-8][4-9]/) && 'Ri '; }
   sub isPo($) { ($uwp{+shift} =~ /^..[2-5][0-3][^0]/)   && 'Po '; }
   
   sub isWa($) { (hyd($_[0]) eq 'A') && 'Wa '; }
   sub isDe($) { ($uwp{+shift} =~ /^..[2-A]0/) && 'De '; }
   sub isAs($) { (size($_[0]) eq '0') && 'As '; }
   sub isVa($) { ($uwp{+shift} =~ /^..[1-A]0/) && 'Va '; }
   sub isIc($) { ($uwp{+shift} =~ /^..[01][1-A]/) && 'Ic '; }
   sub isFl($) { ($uwp{+shift} =~ /^..A[1-A]/)    && 'Fl '; }
   
   sub isCp($) { ($codes{+shift} =~ /cp/) && 'Cp '; }
   sub isCx($) { ($codes{+shift} =~ /cx/) && 'Cx '; }
   
   
   
   
   # other methods

   sub setHashCode($) 
   {
      $sector = shift;
      $sector =~ s/ Sector//;
      
      my @chars = sort unpack("C*", $sector);
      my $len = @chars;
      
      my $code = 0;
      my $i    = 1;
      
      foreach my $char (@chars) 
      {
         $code += $char * 31^($len - $i);
         $i++;
      }
      srand( $code );
   }
   
   
   
   
   sub setLocation($$$)
   {
      my ($self, $col, $row) = @_;
      $self->loc = sprintf( "%02d%02d", $col, $row );
   }
   
   
   
   
   sub setTranslation($$)
   {
      my ($dr, $dc) = @_;
      
      return 0 if $translation{row}
               && $translation{row} == $dr 
               && $translation{col} == $dc;
               
      $translation{row} = $dr;
      $translation{col} = $dc;
      return 1;
   }
   
   
   
   
   sub translate($)
   {
      my $self = shift;
      $self->loc = sprintf( "%02d%02d", $self->col, $self->row );
   }




   #
   #   There's going to be 1, 2, or 3 stars, I think.  But maybe 4.
   #
   sub getStars($)
   {
      my $self  = shift;
      my $stars = $self->stars;
      chomp $stars;
      
      return [ "$1 $2", "$3 $4", "$5 $6", "$7 $8" ]
         if ( $stars =~ /(\w\d) (\w+) (\w\d) (\w+) (\w\d) (\w+) (\w\d) (\w+)/ );
         
      return [ "$1 $2", "$3 $4", "$5 $6" ]
         if ( $stars =~ /(\w\d) (\w+) (\w\d) (\w+) (\w\d) (\w+)/ );
   
      return [ "$1 $2", "$3 $4" ]
         if ( $stars =~ /(\w\d) (\w+) (\w\d) (\w+)/ );
   
      return [ $stars ];
   }




   sub calculateTradeIndex($)
   {
   	my $self = shift;   
      my $tradeIndex = 0;
      #
      #   EXAMPLES: 
      #
      #      B788844-C Ag Ri  has an index of 4.
      #      A788944-F Hi In  has an index of 3.
      #      D862A44-A Hi In  has an index of 2.
      #      C456456-8 Ag     has an index of 1.
      #      D456456-4 Lo Po  has an index of -4.
      #
      $tradeIndex++ if $self->starport   =~ /[AB]/;
      $tradeIndex-- if $self->starport   =~ /[DEX]/;
      $tradeIndex++ if $self->tl         !~ /\d/;
      $tradeIndex-- if $self->tl         =~ /[01234]/;
      
      $tradeIndex++ if $self->isHi();
      $tradeIndex-- if $self->isLo();
      $tradeIndex++ if $self->isRi();
      $tradeIndex-- if $self->isPo();
      $tradeIndex++ if $self->isAg();
      $tradeIndex++ if $self->isIn();
      
      $tradeIndex++ if $self->isCp() || $self->isCx();
         
      return $tradeIndex;
   }   
   
   
   
   
   sub countBillionsOfPeople($)
   {
      my $self = shift;
      my $pm   = $self->pm() || 1;
      
      return $pm * 10 if $self->popul eq 'A';
      return $pm      if $self->popul eq '9';
      return $pm/10   if $self->popul eq '8';
      return $pm/100  if $self->popul eq '7';
      return 0;
   }
   
   
   
   
   sub regenerateTradeCodes($)
   {
      my $self = shift;
      my $s = '';
                  
      $self->codes =~ s/Ag|Na|Po|Ri|In|Ni|Lo|Hi|Wa|De|As|Va|Ic|Fl//g;      
      
      $s .= $self->isBa || $self->isLo || $self->isHi || '';
      $s .= $self->isAg || $self->isNa || '';
      $s .= $self->isIn || $self->isNi || '';
      $s .= $self->isRi || $self->isPo || '';
      $s .= $self->isWa || $self->isDe || '';
      $s .= $self->isAs || $self->isVa || '';
      $s .= $self->isIc || $self->isFl || '';
      
      $self->codes = $s . $self->codes;
   }
   
   
   
   
   sub toString($)
   {
      my $self = shift;
      
      my $xboat = $self->xboat;
            
      sprintf( "%-18s  %s %s %s %-15s %s %3s %2s %s %s\n",
                $self->name,
                $self->loc,
                $self->uwp,
                $self->base,
                $self->codes,
                $self->zone,
                $self->pbg,
                $self->alleg,
                $self->stars,
                $xboat );
   }
}

1;

__END__

=head1 NAME

Games::Traveller::UWP - The Universal World Profile parser for the Traveller role-playing game.

=head1 SYNOPSIS

   use Games::Traveller::UWP qw(createUwp);
   
   print "This is UWP $Games::Traveller::UWP::VERSION\n";

   my $line  = "My World  0980 X123456-8 N  Ri Ag Cp          R 123";

   my $world = createUwp( $line );

   print $world->toString();

=head1 DESCRIPTION

The UWP package is a module that creates instances of UWP objects by parsing
a valid UWP line, stored in a scalar string.  The data is parsed and made
available to the user via a rich set of accessors, some of which are usable
as L-values (but most are read-only).

=head1 OVERVIEW OF CLASS AND METHODS

To create an instance of a UWP, pass a line of UWP sector data into the
'create' method:

   my $uwp = Games::Traveller::UWP::create( $data );

The following accessors can be either RValues (read) or LValues (write):

=over 3

   $uwp->sector     # the name of the owning sector
   $uwp->name       # the name of the world
   $uwp->loc        # the hex location of the world
   $uwp->uwp        # the world's actual UWP string
   $uwp->base       # the base code
   $uwp->codes      # the list of trade codes
   $uwp->zone       # indicator for amber or red zone
   $uwp->pbg        # the PBG string
   $uwp->alleg      # system allegiance
   $uwp->stars      # stellar data
   $uwp->xboat      # xboat route data

   $uwp->hashFunc   # reference to the current hash function
   $uwp->rowXlt     # row translation applied to current data
   $uwp->colXlt     # col translation applied to current data

=back
   
In addition to the above, there is a large body of read-only accessors:

=over 3

   $uwp->col        # returns the column component of the hex location
   $uwp->row        # ibid for the row
   $uwp->starport   # starport class (A..X)
   $uwp->size       # world size
   $uwp->atm        # atmospheric code
   $uwp->hyd        # hydrospheric code
   $uwp->popul      # population code
   $uwp->gov        # gov't code
   $uwp->law        # law level
   $uwp->tl         # tech level
   $uwp->pm         # population multiple (P of the PBG)
   $uwp->belts      # number of asteroid belts (B of the PBG)
   $uwp->ggs        # number of gas giants (G of the PBG)
   $uwp->primary    # returns the primary star
   
   $uwp->isBa       # returns 'Ba' if the world is Barren
   $uwp->isLo       # returns 'Lo' if the world is Low-Pop
   $uwp->isHi       # high pop
   $uwp->isAg       # agricultural
   $uwp->isNa       # non-agri
   $uwp->isIn       # industrial
   $uwp->isNi       # non-ind
   $uwp->isRi       # rich
   $uwp->isPo       # poor
   $uwp->isWa       # water world
   $uwp->isDe       # desert
   $uwp->isAs       # mainworld is asteroid
   $uwp->isVa       # vacuum world
   $uwp->isIc       # all water is ice
   $uwp->isFl       # non-water fluid oceans
   
   $uwp->isCp       # subsector capital
   $uwp->isCx       # sector capital
   
   $uwp->getStars   # returns reference to array of the system's stars
   
   $uwp->calculateTradeIndex   # calculates a rule-of-thumb trade index
   
   $uwp->countBillionsOfPeople # returns the population in billions
   
   $uwp->regenerateTradeCodes  # re-does trade codes
   
   The previous method is useful if you've been changing the UWP values around.

=back
   
   Finally, 
   
=over 3

   $uwp->toString 

=back
   
   returns the UWP data encapsulated in a string, suitable for writing to
   an output stream.
   
=head1 AUTHOR

  Robert Eaglestone

=head1 COPYRIGHT

  Copyright 2004, Robert Eaglestone

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AVAILABILITY

The latest version of this library is likely to be available from CPAN.

=cut
