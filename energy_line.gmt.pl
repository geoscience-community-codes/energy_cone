#######################################################
# energy_cone - a tool to calculate and plot the potential
# run-out of pyroclastic density currents
# written in perl
# uses GMT5 (Generic Mapping Tools) 
#
#    Copyright (C) 2018  Laura Connor, Chuck Connor
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
##########################################################################
# energy_line.gmt.pl - this part of the tool plots the output of the
# model as a .eps and PNG file. It also uses the configuration file.
##########################################################################
use Carp;

print STDERR "USAGE: $0 <config-file>\n\n";

# Open configuration file
my %Param;
my $conf = open_or_die ("<", $ARGV[0]);
while(<$conf>) {
	  if (/^$/ or /^#/) { next; }
    (my $key, my $value) = split " ",$_;
    chomp($value);
		$Param{$key} = $value;
    print STDERR "$key=$Param{$key}\n";
} 

# These variables are read in from the configuration file
#########################################################
# The output from the energy_cone code
my $in = $Param{DATA_OUT};

# The DEM saved as a GMT .grd file ( could be made using gdal: gdal_translate -of GMT dem.tif dem.grd ) 
my $grid = $Param{GRID_FILE}; 

# A GMT .grd file created with grdgradient, created below if it does not already exist
my $intensity = $Param{INTENSITY_FILE}; 

# The vent location
my $easting = $Param{VENT_EASTING};
my $northing = $Param{VENT_NORTHING};

# The map boundaries
my $west = $Param{DEM_WEST};
my $east = $Param{DEM_EAST};
my $south = $Param{DEM_SOUTH};
my $north = $Param{DEM_NORTH};
my $tick_spacing = $Param{TICK_SPACING};
# Map scale (e.g., 1:$scale)
my $scale = $Param{SCALE};
my $cellsize = $Param{GRID_SPACING};

# text file of city locations to plot on the map
my $cities = $Param{CITIES};

# Text file of additional vent locations to plot on the map
my $known_vents = $Param{KNOWN_VENTS};

# The final output
my $out = "energycone.eps";

# Name for color scale
my $dem_cpt = "dem.cpt";
#############################################################

# Get the dimensions of the DEM
`gmt grdinfo $grid | grep z_min 1> minmax.out 2>>stderr.log`;
my $minmax = open_or_die ("<", "minmax.out");
my $mmline = <$minmax>;
(my $s1, my $s2, my $minval, my $s3, my $maxval) = split " ", $mmline;
print STDERR "Topography: Min_val=$minval, Max_val=$maxval\n"; 

# This GMT command also creates a .grd of an x y z  text file
# `gmt surface $dem -Gdem.grd -I$cellsize -R$west/$east/$south/$north -V`;
# -T1447/2000

# Create color scale for DEM
`gmt makecpt -Cgray -T$minval/$maxval/2 -I -V > $dem_cpt `;
# `gmt makecpt -C$dem_cpt -T1377/2300/10 -I -V > dem.cpt`;

# Create the intensity file if it does not exist
unless (-e $intensity) {
	# `gmt grdgradient $grid -G$intensity -R$west/$east/$south/$north -E-80/20/.5/.2/.2/100 -Nt0.5 -V `;
	# -E-25/20/.5/.2/.2/100 -Nt0.5
	`gmt grdgradient $grid -G$intensity -R$west/$east/$south/$north -E-25/20/.5/.2/.2/100 -Nt.5  -V`;
}

# Start making the map
`gmt grdimage $grid -C$dem_cpt -Jx1:$scale -X2c -Y1.5c -R$west/$east/$south/$north -I$intensity -K -V -P > $out `;

# Plot the volcano
`gmt psxy -Jx -R -Sc0.2c -Gblack -Wblack -O -K -V <<EOF>> $out
$easting $northing 
EOF`;

# plot the energy lines
`gmt psxy $in -Jx -R -Sp -Gred -Wthin,red -V -O -K >> $out `;

# Plot the cities
`gmt psxy $cities -R -Jx -Ss0.6c -Gwhite -Wthinnest,green -O -K -V >> $out `;
`gmt pstext -F+f+a+j $cities -G250 -C0.1p -R -Jx -O -K -V >> $out `;

# Plot some known vent locations
`gmt psxy $known_vents -Jx -R -Sp -Wblack -O -K -V >> $out `;
`gmt pstext --FONT_ANNOT_PRIMARY=10p,Helvetica-Bold,0 $known_vents -R -Jx -O -K -V >> $out `;

# Draw the map axes and annotations
my $annot = "a" . $tick_spacing . "g20000";
`gmt psbasemap --MAP_FRAME_TYPE=inside --FONT_ANNOT_PRIMARY=10p,Helvetica,0 -Jx -R -Bx$annot -By$annot -BWseN -O -V >> $out `; 

# Create a PNG file
`gmt ps2raster $out -A -V -Tg `;

# `rm $out $dem_cpt 2> /dev/null`;

###########################
# Subroutine to open a file
###########################
sub open_or_die {
	my ($mode, $filename) = @_;
	open my $h, $mode, $filename
		or croak "Could not open '$filename': $!";
return $h;
}
