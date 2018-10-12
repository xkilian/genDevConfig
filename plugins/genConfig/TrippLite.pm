# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2015 Francois Mikus
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

package TrippLite;

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

      ### TrippLite MIB
      'OidtlUpsInputVoltage'                      => '.1.3.6.1.4.1.850.100.1.3.1',
      'OidtlUpsInputVoltage'                      => '.1.3.6.1.4.1.850.100.1.3.2',
      'OidtlUpsIdentSerialNum'                    => '.1.3.6.1.4.1.850.100.1.1.2',
      'OidtlUpsAlarmsPresent'                     => '.1.3.6.1.4.1.850.100.1.6.1',
      ### TrippLite SNMPWEB MIB - MIB not available
      'OidTrippLitePDUtype'                       => '.1.3.6.1.2.1.33.1.1.2.0',
      'OidTrippLitePDUfirmware'                   => '.1.3.6.1.2.1.33.1.1.4.0',
   
    );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "POWERALERT 12",
            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $script = "TrippLite PDU genDevConfig Module";
my $module = "TrippLite";


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
    Debug ("$module Trying to match sysDescr : " . $opts->{sysDescr});

    foreach my $type (@types) {
        Debug ("$module Type : " . $type);
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
    ### interface descriptions and which
    ### MIBs are supported.
    
    
    ($opts->{model}) = get('OidTrippLitePDUtype');;
    
    # Default options for all tripplite class devices
    $opts->{class} = 'tripplite';
    $opts->{chassisinst} = "0";
    ($opts->{vendor_soft_ver}) = get('OidTrippLitePDUfirmware');
    $opts->{vendor_descr_oid} = "ifName";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation} . "<BR>" . $opts->{model};
 

    Debug("Model : " . $opts->{model});
    
    # class is used for rancid integration
    # chassis type is used to map to a Shinken SNMPBooster DS template
    # trigger group is used to map to a Shinken SNMPBooster Trigger group (thresholds)
    # instance is used for snmp instance mapping
    #
    
    if ($opts->{model} =~ /PDUMH15ATNET/) {
        $opts->{chassisttype} = 'TrippLite-PDUMH15ATNET';
        $opts->{chassisname} = 'chassis.TrippLite-PDUMH15ATNET';
        $opts->{chassistriggergroup} = 'chassis_PDUMH15ATNET';
        $opts->{class} = 'tripplite';
        $opts->{chassisinst} = "0";
        $opts->{dtemplate} = "default-snmp-template";
    } else {
        $opts->{chassisttype} = 'TrippLite-Generic';
        $opts->{chassisname} = 'chassis.TrippLite-Generic';
        $opts->{chassistriggergroup} = 'chassis_Generic';
        $opts->{class} = 'tripplite';
        $opts->{chassisinst} = "0";
        $opts->{dtemplate} = "default-snmp-template";
    }
    
    # Default feature promotions for Alcatel routing switches
    $opts->{usev2c} = 1      if ($opts->{req_usev2c});
    $opts->{tripplitebox} = 1;
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
    my $c          = $data->{c};
    my $target = $data->{target};

    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###
    
   
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
    $data->{target} = $target;
    $data->{c} = $c;
    
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
