# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2015 Flavien Peyre
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

package IbmIMM_x3550;

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

      'productVersion' => '1.3.6.1.4.1.2.3.51.3.1.5.2.1.5.0',
      'rcIbmImm'       => '1.3.6.1.4.1.8072.3.2.10',
      'rcIbmImm2'       => '1.3.6.1.4.1.2.3.51.3',
      'IbmAMM'         => '1.3.6.1.4.1.2.6.158.5',
      'OidIMMSystemHealth' => '1.3.6.1.4.1.2.3.51.3.1.4.1',

      'OidAMMBladeHealth' => '1.3.6.1.4.1.2.3.51.2.2.8.2.1.1.5',
      'OidAMMSwitchHealth' => '1.3.6.1.4.1.2.3.51.2.22.3.1.1.1.15',
      'OidAMMPowerHealth' => '1.3.6.1.4.1.2.3.51.2.2.4.1.1.3',
      'OidAMMBladePower'  => '1.3.6.1.4.1.2.3.51.2.2.8.2.1.1.4'
    );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'rcIbmImm'}",
               $OIDS{'rcIbmImm2'}",
              "$OIDS{'IbmAMM'}",
            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $script = "IBM IMM and AMM genDevConfig Module";
my $module = "IbmIMM_x3550";

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
    
    Debug ("$module Trying to match sysObjectID : " . $opts->{sysObjectID});
    
    foreach my $type (@types) {
        $type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        Debug ("$module Type : " . $type);
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
    if ($opts->{sysObjectID} =~ m/$OIDS{'IbmAMM'}/gi) {
        $opts->{class} = 'IbmAMM';
    } else {
        $opts->{class} = 'IbmIMM';
        $opts->{vendor_soft_ver} = get('productVersion');
    }

    $opts->{chassisinst} = "0";
    $opts->{vendor_descr_oid} = "ifName";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation} . "<BR>" . $opts->{sysName};
 
    Debug("$module Model : " . $opts->{model});
    
    $opts->{usev2c} = 0;
    $opts->{dtemplate} = "generic-imm-service";
    $opts->{htemplates} = "SnmpBooster-host-MDG";
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
    my %idtable;
    if ($opts->{class} =~ /IbmIMM/) {
        %idtable = gettable('OidIMMSystemHealth');


        foreach my $id (keys %idtable) {
         $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "health_statistic_" . $id,
               'notes'               => "IBM IMM Health Stats. Any number under 255 is a problem<BR>Error indicates hardware problem, action required on the server.",
               'display_name'        => "Health statistic " . $id,
               '_inst'               => $id,
               '_dstemplate'         => "ibm-system-health-stat",
               '_triggergroup'       => "Ibm_Health_Stat",
               'use'                 => $opts->{dtemplate},
            );

        }
    }

    if ($opts->{class} =~ /IbmIMM/) {

        $file->writetarget("service {", '',
            'host_name'           => $opts->{devicename},
            'service_description' => "IMM_temperature",
        'notes'            => "IBM IMM Temperature. Permits tracking of intake temperature of ESX servers. System Health will show alarm above 41 degree celsiius. <BR> Service warning above 25 degrees and alarm over 30 degrees celsius.",
            'display_name' => "IBM IMM Temperature",
        '_inst' => 0,
        '_dstemplate'       => "ibm-imm-temperature",
            '_triggergroup' => "Ibm_IMM_temperature",
            'use'           => $opts->{dtemplate},
            );

    }


    my %idtableAMMbladehealth;
    my %idtableAMMswitch;
    my %idtableAMMpower;
    my %idtableAMMbladepower;

    if ($opts->{class} =~ /IbmAMM/) {
        %idtableAMMbladehealth = gettable('OidAMMBladeHealth');

        foreach my $idAMM (keys %idtableAMMbladehealth) {
         $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "health_AMM_blade_overall" . $idAMM,
               'notes'               => "IBM AMM Overall Blade Health Stats. 1 = good, 2 = warning, 3 = bad, action required on the server.",
               'display_name'        => "Health AMM Blade Overall " . $idAMM,
               '_inst'               => $idAMM,
               '_dstemplate'         => "ibm-amm-blade-health",
               '_triggergroup'       => "Ibm_AMM_Blade_Health",
               'use'                 => $opts->{dtemplate},
            );

        }

        %idtableAMMswitch = gettable('OidAMMSwitchHealth');
        foreach my $idAMMswitch (keys %idtableAMMswitch) {
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "health_switch_module_" . $idAMMswitch,
                'notes'               =>
                "IBM AMM Switch Module Health. The LED status of the switch module indicates its health.  0 = unknown, 1 = good, 2 = warning, 3 = bad., action required on the server.",
                'display_name'        => "Health AMM switch module " . $idAMMswitch,
                '_inst'               => $idAMMswitch,
                '_dstemplate'         => "ibm-amm-switch-module-health",
                '_triggergroup'       => "Ibm_AMM_Switch_Health",
                'use'                 => $opts->{dtemplate},
            );
        }

        %idtableAMMpower = gettable('OidAMMPowerHealth');
        foreach my $idAMMpower (keys %idtableAMMpower) {
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "health_power_module_" . $idAMMpower,
                'notes'               =>
                "IBM AMM Power Module Health. The LED status of the Power module indicates its health.  0 = unknown, 1 = good, 2 = warning, 3 = bad., action required on the server.",
                'display_name'        => "Health AMM power module " . $idAMMpower,
                '_inst'               => $idAMMpower,
                '_dstemplate'         => "ibm-amm-power-module-health",
                '_triggergroup'       => "Ibm_AMM_Power_Health",
                'use'                 => $opts->{dtemplate},
            );
        }

        $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "temperature",
               'notes'               => "IBM AMM, Temperature, call Datacenter Maintenance Team. If temperature too high, Blade center will auto-shutdown.",
               'display_name'        => "Temperature chassis AMM",
               '_dstemplate'         => "ibm-amm-temperature",
               #'_triggergroup'       => "Ibm_AMM_Temperature",
               'use'                 => $opts->{dtemplate},
            );

        $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "blower1",
               'notes'               => "IBM AMM, blower 1. 0 = unknown, 1 = good, 2 = warning, 3 = bad.",
               'display_name'        => "Blower 1 chassis AMM",
               '_dstemplate'         => "ibm-amm-blower1",
               '_triggergroup'       => "Ibm_AMM_Blower1",
               'use'                 => $opts->{dtemplate},
            );
        $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "blower2",
               'notes'               => "IBM AMM, blower 2. 0 = unknown, 1 = good, 2 = warning, 3 = bad.",
               'display_name'        => "Blower 2 chassis AMM",
               '_dstemplate'         => "ibm-amm-blower2",
               '_triggergroup'       => "Ibm_AMM_Blower2",
               'use'                 => $opts->{dtemplate},
            );

        %idtableAMMbladepower = gettable('OidAMMBladePower');
        foreach my $idAMMbladepower (keys %idtableAMMbladepower) {
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "state_blade_power_module_" . $idAMMbladepower,
                'notes'               =>
                "IBM AMM Blade Power. Indicates if a blade is powered on.  0 = powered off, 1 = powered on.",
                'display_name'        => "AMM blade power status " . $idAMMbladepower,
                '_inst'               => $idAMMbladepower,
                '_dstemplate'         => "ibm-amm-blade-power",
                'use'                 => $opts->{dtemplate},
            );
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
    my $c = $data->{c};
    

    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###
    
    # Set a non-sticky interface setting for invalid speed in nortel MIBs
    
    Debug ("$module Interface name: $ifdescr{$index}, $intdescr{$index}");
    
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
