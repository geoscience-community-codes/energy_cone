#######################################################
# energy_cone - a tool to calculate and plot the potential
# run-out of pyroclastic density currents
# written in perl
# uses GMT5 (Generic Mapping Tools) 
#
#    Copyright (C) 2017  Laura Connor, Chuck Connor
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
###########################################################################
# energy_lines.pl
# This part of the code calculates the potential run-out of pyroclastic density
# currents (pdcs) using the Heim coefficient, the ratio of release height in the
# volcanic plume to total potential run-out length.
#
###########################################################################
print STDERR "USAGE: $0 <config_file>\n\n";

$DEG2RAD = 0.017453293;
my %Param;

my $conf = $ARGV[0];
print STDERR "Opening configuration file: $conf\n";
open CONF, "< $conf" or die "Can't open configuration file[$ARGV[0]]\n[USAGE]: $0 config_file \n$!";

while(<>) {
  if (/^$/ or /^#/) { next; }
    ($key, $value) = split " ",$_;
    chomp($value);
		$Param{$key} = $value;
    print STDERR "$key=$Param{$key}\n";
} 
	
my $slope = $Param{SLOPE};
my $height_min = $Param{HEIGHT_MIN};
my $height_max = $Param{HEIGHT_MAX};
my $height_int = $Param{HEIGHT_INTERVAL};
my $out = $Param{DATA_OUT};
open OUT, "> $out" or die "Unable to open $out : $!";

my $Dem = $Param{DEM_FILE};
print STDERR "Opening DEM: $Dem\n";
open DEM, "< $Dem" or die "Can't open $Dem : $!";

my @data;
my $nrows = 0;
while (<DEM>) {
		@data = split " ", $_;
		if ($nrows < 5) {$Param{$data[0]} = $data[1]; print STDERR "$data[0] = $data[1]\n";}
		else {push @Dem, [ @data ]; }
		$nrows++;
}
close DEM;
my $ncols = @data;
$nrows -= 5;
print STDERR "Number of Columns: $ncols, Number of Rows: $nrows\n";

my @height;
my $level = 0;
for ($i = $height_min; $i <= $height_max; $i += $height_int) {
	$height[$level] = $i;
	$level++;
}
print STDERR "Calculating deposits from height: $height_min to $height_max (km) in $height_int km intervals using a slope of $slope\n";



my $Dem_south = $Param{DEM_SOUTH}/1000;
my $Dem_north = $Param{DEM_NORTH}/1000;
my $Dem_east = $Param{DEM_EAST}/1000;
my $Dem_west = $Param{DEM_WEST}/1000;
#print STDERR "NW Corner of DEM (x,y): $Dem_west, $Dem_north\n";

my $Vent_easting = $Param{VENT_EASTING}/1000;
my $Vent_northing = $Param{VENT_NORTHING}/1000;
#print STDERR "\nVent location: $Vent_easting, $Vent_northing\n";


my $Grid_km = $Param{GRID_SPACING}/1000;

# Adjust grid location of vent. We want to find the grid location of the vent.
my $x = int(($Vent_easting - $Dem_west) / $Grid_km);
my $y = $nrows - int(($Vent_northing - $Dem_south) / $Grid_km);
#print STDERR "Grid location of vent: x = $x, y = $y, elevation = $Dem[$y][$x]\n";

my @Energy;
my $i;
# Do for each height of the colapsing column
foreach $h (@height) {
  $max_runout = $h/$slope;
  print STDERR "Height: $h km\n";
  print STDERR "Max runout: $max_runout km\n";
  $energy_line = $h;
  
  $i = 0;
  # Do for each distance interval along the energy line.
  my $dist_int = $Param{DISTANCE_INTERVAL};
  for ($y1 = $Vent_northing; $energy_line > 0;  $y1 -= $dist_int){
    $energy_line = ($slope * $y1) - ($slope * $Vent_northing) + $h;
    $Energy[$i] = $energy_line; 
    #print STDERR "$Vent_northing, $y1: $Energy[$i]\n";
    $i++;
  }


  my $deg;
  my $theta;
  my $distance;
  my $row;
  my $col;
  
  # Do for each radial line around the vent using degree increments.
  my $deg_min = $Param{DEGREE_MIN};
  my $deg_max = $Param{DEGREE_MAX};
  my $deg_int = $Param{DEGREE_INTERVAL};
  my $line = 0;
  print OUT "> $h\n";
 LINE:  for ($deg = $deg_min; $deg <= $deg_max; $deg += $deg_int, $line++) {
    $theta = $deg * $DEG2RAD;
    $i = 0;
    DISTANCE: for ($distance = 0; $distance <= $max_runout && $Energy[$i] > 0; $distance += $dist_int, $i++) {
      $x0 = $distance * cos($theta) + $Vent_easting;
      $y0 = $distance * sin($theta) + $Vent_northing;
      $col = int(($x0 -$Dem_west) / $Grid_km);
      $row = $nrows - int(($y0 - $Dem_south) / $Grid_km);
      $elev_km = $Dem[$row][$col]/1000;
#print STDERR "elevation = $elev_km\n";
      #print "[$i] X1 = $col, Y1 = $row, energy_line = $Energy[$i], topograpy = $elev_km\n";
      #if ($x0 > $Param{AOI_WEST} && $y0 < $Param{AOI_NORTH} && $elev_km <= $Param{AOI_ELEV}) {
      		#print STDOUT "$x0 $y0 $Energy[$i] $elev_km [$line] [$i] 1\n";
      		#last DISTANCE;
      #} # End if
      if ($Energy[$i] <= $elev_km) {
			  $xp =$x0*1000;
			  $yp = $y0*1000;
			print OUT "$xp $yp\n";
		 # print OUT "$xp $yp $Energy[$i] $elev_km [$line] [$i] 0\n";
 #       }
        last DISTANCE;
      } # End of if
      if ($x0 < $Dem_west || $y0 < $Dem_south || $x0 > $Dem_east || $y0 > $Dem_north ) {
      	last DISTANCE;
      } # End of if
    } # End of distance
  } # End of for each radial line
} # End of foreach height
# Uncomment this next line to run the plotting part of the code automatically
# system "perl energy_line.gmt.pl $conf";
