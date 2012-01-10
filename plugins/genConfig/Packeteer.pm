# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2005 Francois Mikus
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

package Packeteer;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.00;

### End package init


# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
my %OIDS = (

       ### Packeteer OIDs
       'partitionMinimumBps'     => '1.3.6.1.4.1.2334.2.1.3.2.1.24',
       'classFullName'           => '1.3.6.1.4.1.2334.2.1.4.2.1.36',
       
      );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "Packeteer");

# Examples
# my @types = ( "$OIDS{'RapidCityMIB'}", # Nortel Accelar sysObjectID
#             );
# my @types = ('1.3.6.1.4.1.1991', # Foundry Generic sysObjectID
#             );
# my @types = ('^VendorName\d\d$', # Example of simple regex
#             );

###############################################################################
### Private variables
###############################################################################

my $snmp;

my $script = "Packeteer genDevConfig Module";

###############################################################################
###############################################################################

#-------------------------------------------------------------------------------
# plugin_name
# IN : N/A
# OUT: returns the name of the plugin
#-------------------------------------------------------------------------------

sub plugin_name {
   my $self = shift;
   return $script; 
}

#-------------------------------------------------------------------------------
# device_types
# IN : N/A
# OUT: returns an array ref of devices this plugin can handle
#-------------------------------------------------------------------------------

sub device_types {
   my $self = shift;
   return \@types;
}

#-------------------------------------------------------------------------------
# can_handle
# IN : opts reference
# OUT: returns a true if the device can be handled by this plugin
#-------------------------------------------------------------------------------

sub can_handle {
    my($self, $opts) = @_;

    foreach my $type (@types) {
        return ($opts->{sysDescr} =~ m/$type/gi)

        # Example using OIDs instead of a string match
        #$type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        #return ($opts->{sysObjectID} =~ m/$type/gi)
    }
    return 0;

}

#-------------------------------------------------------------------------------
# discover
# IN : options reference
# OUT: N/A
#-------------------------------------------------------------------------------

sub discover {
    my($self, $opts) = @_;

    ### Add our OIDs to the the global OID list

    register_oids(%OIDS);

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    ### Figure out the OS version number this device is running.  
    ### We need this to figure out which oid to use to get
    ### interface descriptions and which MIBs are supported.


    ### PACKETEER GENERIC SECTION
    
    $opts->{model} = 'packeteer'; # Informational for plugin not included in cricket config
    $opts->{class} = 'packeteer'; # Informational for Chassis target useful for Rancid integration
    $opts->{chassisttype} = 'Generic-Device'; # targetType of Chassis target
    $opts->{chassisname} = 'Chassis-Packeteer'; # name of Chassis target

    # Example of additional info to add to sysDescr
    #$opts->{vendor_soft_ver} = get('versionOID');
    #$opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver};

    # Example of forcing descr_oid used to get interface descriptions
    #$opts->{vendor_descr_oid} = "ifName";

    ### Insert IF/ELSIF block to modify generic options based on $opts->{model}
    #
    ###
  
    # Default feature promotions for Packeteer
    $opts->{chassiscollect} = 0; # Do not collect any stats on the chassis. No OIDs defined. :-(

    return;
}

#-------------------------------------------------------------------------------
# custom_targets
# IN : data reference for transient data, options reference
# OUT: N/A
#-------------------------------------------------------------------------------

sub custom_targets {
    my ($self,$data,$opts) = @_;
        
    # Saving local copies of runtime data
    my %ifspeed    = %{$data->{ifspeed}};
    my %ifdescr    = %{$data->{ifdescr}};
    my %intdescr   = %{$data->{intdescr}};
    my %iftype     = %{$data->{iftype}};
    my %ifmtu      = %{$data->{ifmtu}};
    my %slotPortMapping   = %{$data->{slotPortMapping}};
    my $file = $opts->{file};

    ###
    ### START DEVICE CUSTOM CONFIG SECTION
    ###

    # Simple example of writing out a target
    #
    # my $someOID = get('someOID');
    # my $ldesc = "Total number of widgets for card $someOID";
    # my $sdesc = "Total number of widgets for card $someOID";
    # $targetname = 'packeteer-cardinfo';
    # 
    # $file->writetarget($targetname, '',
    #                (
    #                # --default is set to 'display-name' => '%devicename% %interface-name%',
    #                # If you wish something different, you canoverride it here.
    #                'interface-name' => $targetname,
    #                # target-type must be defined to collect statistics
    #                'target-type'  => 'packeteer-special-target',
    #                'short-desc'     => $sdesc,
    #                'long-desc'      => $ldesc,
    #                'order'          => $opts->{order},
    #                'inst'           => 0 # You could reference an index or a map, --default-- is set to map(%interface-name%).
    #                ) );
    # # Decrease the order in which each target appears
    # $opts->{order} -= 1;


    # CAR Traffic shaping stats for packeteer

    my %classFullName;
    my %partitionMinimumBps;
    if ($opts->{model} =~ /packeteer/) {
        %classFullName = gettable('classFullName');
        %partitionMinimumBps = gettable('partitionMinimumBps');
    }

    if (keys(%classFullName)) {
        my $index;
        my $speed_str;
        foreach $index (sort { $a <=> $b } keys(%classFullName)) {
            if (defined $partitionMinimumBps{$index}) {
                    my $b = ($opts->{units} eq "bytes") ? 8 : 1;
                    my $speed = int($partitionMinimumBps{$index} / $b); # bits to bytes
                    $speed_str = ($speed) ? fmi($speed, $opts->{units}) : '';
            } else {
                    $speed_str = "nil";
            }
            my $name = "$opts->{devicename}.$index";
            my $target = $classFullName{$index};
            ### If we already have _ in the name, replace them with -, other wies it will stuff up the split function below.
            $target =~ s/\_/\-/g;

            ### Drop the leading /, and replace / : or space with _
            $target =~ s/^\///;
            $target =~ s/[\/\s:]/\_/g;
            my $ldesc = ((defined $classFullName{$index}) ? $classFullName{$index} : '');
            $ldesc .= "<BR>$name" if ($name);

            my $sdesc;
            if ($speed_str eq "nil") {
                    $sdesc = "";
            }else{
                    $ldesc .= "<BR>$speed_str";
                    $sdesc = "$speed_str";
            }

            $file->writetarget($target, '',
                    ('interface-name' => $classFullName{$index},
                    'target-type'  => 'packeteer-class',
                    'short-desc'     => $sdesc,
                    'long-desc'      => $ldesc,
                    'order'          => $opts->{order},
                    'inst'           => $index
                    ) );

        $opts->{order} -= 1;
       }
    }
  
        
    ###
    ### END DEVICE CUSTOM CONFIG SECTION
    ###

    # Saving local copies of runtime data
    %{$data->{ifspeed}} = %ifspeed;
    %{$data->{ifdescr}} = %ifdescr;
    %{$data->{intdescr}} = %intdescr;
    %{$data->{iftype}} = %iftype;
    %{$data->{ifmtu}} = %ifmtu;
    %{$data->{slotPortMapping}} = %slotPortMapping;

    return;
}

#-------------------------------------------------------------------------------
# custom_interfaces
# IN : current ifIndex, 
#      data reference for transient data
#      options reference
# OUT: N/A
#-------------------------------------------------------------------------------

sub custom_interfaces {
    my ($self,$index,$data,$opts) = @_;

    # Saving local copies of runtime data
    my %ifspeed    = %{$data->{ifspeed}};
    my %ifdescr    = %{$data->{ifdescr}};
    my %intdescr   = %{$data->{intdescr}};
    my %iftype     = %{$data->{iftype}};
    my %ifmtu      = %{$data->{ifmtu}};
    my %slotPortMapping   = %{$data->{slotPortMapping}};
    my @config     = @{$data->{config}};
    my $hc         = $data->{hc};
    my $class      = $data->{class};
    my $match      = $data->{match};
    my $customsdesc = $data->{customsdesc};
    my $customldesc = $data->{customldesc};

    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###

    # Example of processing special cases for interfaces
    # Special cases are tried first then processing falls back
    # on standard/extended MIB-II statistics.
    #
    #if ($iftype{$index} == 32 &&  $ifdescr{$index} =~ /\.\d+$/) {

    #     push(@config, 'target-type' => 'packeteer-sub-interface' . $hc);
    #     # Override runtime data for the mtu of this interface
    #     $ifmtu{$index} = 1 if (!defined($ifmtu{$index}) || $ifmtu{$index} == 0);
    #     # tell the main script that you the plugin did process this interface
    #     $match = 1;

    #} elsif ($opts->{packeteerint}) {
    #     # Check if NU Cast packet statistics are requested
    #     my ($nu) = $opts->{nustats} ? '-nu' : '';
    #     push(@config, 'target-type' => 'packeteer-interface'. $nu . $hc);
    #     $match = 1;
    #}


    ###
    ### END INTERFACE CUSTOM CONFIG SECTION
    ###

    # Saving local copies of runtime data
    %{$data->{ifspeed}}  = %ifspeed;
    %{$data->{ifdescr}}  = %ifdescr;
    %{$data->{intdescr}} = %intdescr;
    %{$data->{iftype}}   = %iftype;
    %{$data->{ifmtu}}    = %ifmtu;
    %{$data->{slotPortMapping}} = %slotPortMapping;
    @{$data->{config}} = @config;
    $data->{hc}     = $hc;
    $data->{class}  = $class;
    $data->{match}  = $match;
    $data->{customsdesc} = $customsdesc;
    $data->{customldesc} = $customldesc;

    return;
}

#-------------------------------------------------------------------------------
# custom_files
# IN : options hash
# OUT: returns the options hash
#-------------------------------------------------------------------------------

sub custom_files {
    my ($self,$data,$opts) = @_;

    # Saving local copies of runtime data
    my $file           = $data->{file};
    my $c              = $data->{c};
    my $target         = $data->{target};
    my @config         = @{$data->{config}};
    my $wmatch         = $data->{wmatch};

    ###
    ### START FILE CUSTOM CONFIG SECTION
    ###

    ###
    ### END FILE CUSTOM CONFIG SECTION
    ###

    # Save return value in the reference hash
    $data->{wmatch}  = $wmatch;
}

1;
