# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2004 Francois Mikus
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

package Accedian;

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

      ### Accedian MIB
      'acdPaaResultOneWayDelayPrevMaxValue'                         => '1.3.6.1.4.1.22420.2.5.1.1.52',
      'acdPaaResultOneWayDvPrevMaxValue'                            => '1.3.6.1.4.1.22420.2.5.1.1.19',
      'acdPaaResultTwoWayDelayPrevMaxValue'                         => '1.3.6.1.4.1.22420.2.5.1.1.30',
      'acdPaaResultTwoWayDvPrevMaxValue'                            => '1.3.6.1.4.1.22420.2.5.1.1.41',
      'acdPaaResultPktLossPrevLargestGap'                           => '1.3.6.1.4.1.22420.2.5.1.1.101',

      
      'acdDescFirmwareVersion'                        => '1.3.6.1.4.1.22420.2.5.1.1.52',
      'acdDescIdentifier'                             => '1.3.6.1.4.1.22420.2.5.1.1.19',
      'acdDescSerialNumber  '                         => '1.3.6.1.4.1.22420.2.5.1.1.30',
      'acdDescCpuUsageCurrent  '                      => '1.3.6.1.4.1.22420.2.5.1.1.41',
      'acdDescCpuUsageAverage15  '                    => '1.3.6.1.4.1.22420.2.5.1.1.101',
      
      # Invented OID names
      'acdPaaKeyName'                                 => '1.3.6.1.4.1.22420.2.5.3.1.2',
      'acdPaaKeyMtu'                                  => '1.3.6.1.4.1.22420.2.5.3.1.4',
      'AMN-1000-TE'                                   => '1.3.6.1.4.1.22420.1.1',

   
     );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'AMN-1000-TE'}",
            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $script = "Accedian genDevConfig Module";

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
    
    Debug ("Trying to match sysObjectID : " . $opts->{sysObjectID});
    
    foreach my $type (@types) {
        $type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        Debug ("Type : " . $type);
        return 1 if ($opts->{sysObjectID} =~ m/$type/gi)
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
    
    $opts->{model} = $opts->{sysDescr};
    
    # Default options for all passport class devices
    $opts->{class} = 'metronid';
    $opts->{chassisinst} = "0";
    $opts->{vendor_soft_ver} = get('acdDescFirmwareVersion');
    $opts->{vendor_descr_oid} = "ifName";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation};
 
    Debug("Model : " . $opts->{model});
    
    if ($opts->{model} =~ /AMN-1000-TE/) {
        $opts->{chassisttype} = 'Accedian-metronid';
        $opts->{chassisname} = 'chassis.Accedian-metronid';
    }
    
    # Default feature promotions for Nortel routing switches
    $opts->{usev2c} = 1      if ($opts->{req_usev2c});
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
    
    my %acdPaaKeyName     = gettable('acdPaaKeyName');
    my %acdPaaKeyMtu         = gettable('acdPaaKeyMtu');
    
    foreach my $key ( sort keys %acdPaaKeyName ) {
      my $Name     = $acdPaaKeyName{$key};
      my $Mtu        = $acdPaaKeyMtu{$key};
        Debug("Accedian table key: " . $key);
     
        my ($servicename) = "PAA_" . $Name;
        my ($ldesc) = "Metronid: $servicename Mtu: $Mtu";
        $file->writetarget("service {", '',
            'service_description'  => $servicename,
            'display_name'         => $servicename,
            'host_name'            => $opts->{devicename},
            '_inst'                => $key,
            '_display_order'       => $opts->{order},
            'notes'                => $ldesc,
            '_dstemplate'          => 'Accedian-metronid-paa',
            'use'                  => $opts->{dtemplate}
        );
        $opts->{order} -= 1;
        
        $servicename = "PAA_CPU_USAGE_" . $Name;
        $ldesc = "Metronid: $servicename";
        $file->writetarget("service {", '',
            'service_description'  => $servicename,
            'display_name'         => $servicename,
            'host_name'            => $opts->{devicename},
            '_inst'                => $key,
            '_display_order'       => $opts->{order},
            'notes'                => $ldesc,
            '_dstemplate'          => 'Accedian-metronid-paacpu',
            'use'                  => $opts->{dtemplate}
        );
         $opts->{order} -= 1;
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
