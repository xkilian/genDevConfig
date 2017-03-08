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

package AlcatelAOS;

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

      ### Alctale Omniswitch
      ### Undefined MIB
      'OidSoftwareRev'                            => '1.3.6.1.2.1.47.1.1.1.1.10.1',
      'OidSerialNum'                            => '1.3.6.1.2.1.47.1.1.1.1.11.1',
      'OidchasEntPhysOperStatus'                     => '1.3.6.1.4.1.6486.801.1.1.1.1.1.1.1.2',
      'OidAosalaOspfRouteNumber'                     => '1.3.6.1.4.1.6486.801.1.2.1.10.4.1.1.1.7.0',
      'OS6900X20'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.10.1.1',
      'OS6900X40'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.10.1.2',
      'OS6900T20'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.10.1.3',
      'OS6900T40'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.10.1.4',
      'OS6900Q32'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.10.1.3',
      'OS6900X72'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.10.1.4',
      'OS686024'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.11.1.1',
      'OS6860P24'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.11.1.2',
      'OS686048'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.11.1.3',
      'OS6860P48'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.11.1.4',
      'OS6860E24'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.11.1.5',
      'OS6860EP24'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.11.1.6',
      'OS6860E48'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.11.1.7',
      'OS6860EP48'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.11.1.8',
      'OS6860EU28'                            => '1.3.6.1.4.1.6486.801.1.1.2.1.11.1.9',
      'OS645024'                            => '1.3.6.1.4.1.6486.800.1.1.2.1.12.1.5',
      'OS645024L'                            => '1.3.6.1.4.1.6486.800.1.1.2.1.12.1.10',
      'OS6450P24L'                            => '1.3.6.1.4.1.6486.800.1.1.2.1.12.1.11',
      'OS625024'                             => '1.3.6.1.4.1.6486.800.1.1.2.1.11.2.1',
      'virtualChassisRole'                    => '1.3.6.1.4.1.6486.801.1.2.1.69.1.1.2.1.3',
      'virtualChassisRole2'                    => '1.3.6.1.4.1.6486.801.1.2.1.69.1.1.2.1.3.2',
      'virtualChassisRole8'                    => '1.3.6.1.4.1.6486.801.1.2.1.69.1.1.2.1.3.8.9',
      'AlcatelddmTemperature'                  => '1.3.6.1.4.1.6486.800.1.2.1.5.1.1.2.5.1.1',
      'AlcatelddmTxOutputPower'                => '1.3.6.1.4.1.6486.800.1.2.1.5.1.1.2.5.1.16',
      'AosddmPortTemperature'                  => '1.3.6.1.4.1.6486.801.1.2.1.5.1.1.2.6.1.1',
      'AosddmPortTxOutputPower'                => '1.3.6.1.4.1.6486.801.1.2.1.5.1.1.2.6.1.16',
      'AosQoSAppliedRuleCondition'             => '1.3.6.1.4.1.6486.801.1.2.1.22.1.1.2.1.5',
      'AosQoSAppliedRuleAction'                => '1.3.6.1.4.1.6486.801.1.2.1.22.1.1.2.1.6',
      'AlcatelQoSAppliedRuleCondition'         => '1.3.6.1.4.1.6486.800.1.2.1.22.1.1.2.1.5',
      'AlcatelQoSAppliedRuleAction'            => '1.3.6.1.4.1.6486.800.1.2.1.22.1.1.2.1.6',
      'AlcatelSspHelperStatus'                 => '1.3.6.1.4.1.6486.801.1.2.1.24.1.1.9.1.0',
    );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'OS6900X20'}",
              "$OIDS{'OS6900X40'}",
              "$OIDS{'OS6900T20'}",
              "$OIDS{'OS6900T40'}",
              "$OIDS{'OS6900Q32'}",
              "$OIDS{'OS6900X72'}",
              "$OIDS{'OS686024'}",
              "$OIDS{'OS686048'}",
              "$OIDS{'OS6860P24'}",
              "$OIDS{'OS6860P48'}",
              "$OIDS{'OS6860E24'}",
              "$OIDS{'OS6860E48'}",
              "$OIDS{'OS6860EP24'}",
              "$OIDS{'OS6860EP48'}",
              "$OIDS{'OS6860EU28'}",
              "$OIDS{'OS645024'}",
              "$OIDS{'OS645024L'}",
              "$OIDS{'OS6450P24L'}",
              "$OIDS{'OS6450P48L'}",
              "$OIDS{'OS645048L'}",
              "$OIDS{'OS625024'}",
            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $chassispowersupply = 0;
my $chassispowersupply_alcatel = 0;
my $chassisfilter = 0;
my $chassisfilter_alcatel = 0;
my $chassisospf = 0;
my $chassisfan = 0;
my $chassishelper = 0;
my $chassisconfig = 0;
my $script = "Alcatel AOS Omniswitch genDevConfig Module";
my %alcatelddmtemperaturetable;
my %alcatelddmtxmtable;
my %aosddmtemperaturetable;
my %aosddmtxmtable;
my $vcsize;

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
    
    Debug ("AlcatelAOS Trying to match sysObjectID : " . $opts->{sysObjectID});
    
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
    
    my $vcrole;

    my $sysNotes;
    
    $opts->{model} = $opts->{sysDescr};
    
    # Default options for all AOS class devices
    $opts->{class} = 'aos';
    $opts->{chassisinst} = "0";
    ($opts->{vendor_soft_ver}) = get('OidSoftwareRev');
    my %vcroles     = gettable('virtualChassisRole');

    
    $opts->{vendor_descr_oid} = "ifName";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation} . "<BR>" . get('OidSoftwareRev');
 
    if ($opts->{model} =~ /6900/ || $opts->{model} =~ /6860/){
        if (keys(%vcroles) eq 8) {
            $vcsize = '-VC8';
        } elsif (keys(%vcroles) eq 7) {
            $vcsize = '-VC7';
        } elsif (keys(%vcroles) eq 6) {
            $vcsize = '-VC6';
        } elsif (keys(%vcroles) eq 5) {
            $vcsize = '-VC5';
        } elsif (keys(%vcroles) eq 4) {
            $vcsize = '-VC4';
        } elsif (keys(%vcroles) eq 3) {
            $vcsize = '-VC3';
        } else {
            if (keys(%vcroles) eq 2) {
                $vcsize = '-VC2';
            } else {
                $vcsize = '';
            }
        }
    }
 
    Debug("Model : " . $opts->{model});
    
    # class is used for rancid integration
    # chassis type is used to map to a Shinken SNMPBooster DS template
    # trigger group is used to map to a Shinken SNMPBooster Trigger group (thresholds)
    # instance is used for snmp instance mapping
    #
    
    if ($opts->{model} =~ /6900/) {
        $opts->{chassisttype} = 'Alcatel-OS6900' . $vcsize;
        $opts->{chassisname} = 'chassis.Alcatel-OS6900';
        $opts->{chassistriggergroup} = 'chassis_OS6900';
        $opts->{class} = 'aos';
        $opts->{chassisinst} = "0";
        $opts->{dtemplate} = "default-snmp-template";
        $chassispowersupply = 1;
        $chassisfilter = 1;
        $chassisfan = 0;
        $chassisospf = 1;
        $chassisconfig = 1;
        $opts->{sysNotes} = 'Alcatel OS6900 Chassis. General supervised statistics, alarms should be treated in priority, such as power failed powersupply or failed VC members. Control status notSynchronized(3),synchronized(4). Powersupply notApplicable (0), off (1), greenOn (2), greenBlink (3), amberOn (4), amberBlink (5).';
    } elsif ($opts->{model} =~ /6860/) {
        $opts->{chassisttype} = 'Alcatel-OS6860' . $vcsize;
        $opts->{chassisname} = 'chassis.Alcatel-OS6860';
        $opts->{chassistriggergroup} = 'chassis_OS6860';        
        #$opts->{chassistriggergroup} = 'chassis_OS6860' . $vcsize if $vcsize ne '';
        $opts->{class} = 'aos';
        $opts->{chassisinst} = "0";
        $opts->{dtemplate} = "default-snmp-template";
        $chassispowersupply = 1;
        $chassisfilter = 1;
        $chassisfan = 0;
        $chassisospf = 1;
        $chassisconfig = 1;
        $opts->{sysNotes} = 'Alcatel OS6860 Chassis. General supervised statistics, alarms should be treated in priority, such as power failed powersupply or failed VC members. Control status notSynchronized(3),synchronized(4). Powersupply notApplicable (0), off (1), greenOn (2), greenBlink (3), amberOn (4), amberBlink (5). Note :Temperature is internal temp, not external, threshold is ';

    } elsif ($opts->{model} =~ /6450/) {
        # AOS 6.x 6250, 6450, etc.
        $opts->{chassisttype} = 'Alcatel-OS6450';
        $opts->{chassisname} = 'chassis.Alcatel-OS6450';
        $opts->{chassistriggergroup} = 'chassis_OS6450';
        $opts->{class} = 'alcatel';
        $opts->{chassisinst} = "0";
        $opts->{dtemplate} = "default-snmp-template";
        $opts->{sysNotes} = 'Alcatel OS6450 Chassis. General supervised statistics, alarms should be treated in priority, such as power failed powersupply.Powersupply notApplicable (0), off (1), greenOn (2), greenBlink (3), amberOn (4), amberBlink (5).';
        $chassispowersupply_alcatel = 1;
        $chassisfilter_alcatel = 1;
        $chassisfan = 0;
        $chassisospf = 0;
        $chassishelper = 1;
    } elsif ($opts->{model} =~ /6250/) {
        # AOS 6.x 6250, 6450, etc.
        $opts->{chassisttype} = 'Alcatel-OS6250';
        $opts->{chassisname} = 'chassis.Alcatel-OS6250';
        #$opts->{chassistriggergroup} = 'chassis_OS6250';
        $opts->{class} = 'alcatel';
        $opts->{chassisinst} = "0";
        $opts->{dtemplate} = "default-snmp-template";
        $opts->{sysNotes} = 'Alcatel OS6250 Chassis. General supervised statistics, alarms should be treated in priority, such as power failed powersupply.Powersupply notApplicable (0), off (1), greenOn (2), greenBlink (3), amberOn (4), amberBlink (5).';
        $chassispowersupply_alcatel = 1;
        $chassisfilter_alcatel = 1;
        $chassisfan = 0;
        $chassisospf = 0;
        $ chassishelper = 1;
    } else {
        # Default to AOS 6.x
        $opts->{chassisttype} = 'Alcatel-Generic';
        $opts->{chassisname} = 'chassis.Alcatel-Generic';
        $opts->{class} = 'alcatel';
        $opts->{sysNotes} = 'Alcatel Generic Chassis. General supervised statistics, alarms should be treated in priority.';
      
        $chassispowersupply_alcatel = 0;
        $chassisfan = 0;
        $chassisospf = 0;
        $opts->{req_ddm} = 0;
    }
    $opts->{ddm} = 1      if ($opts->{req_ddm});
    
    if ($opts->{ddm} == 1 && $opts->{class} eq 'aos') {
        %aosddmtemperaturetable         = gettable('AosddmPortTemperature');
        %aosddmtxmtable                 = gettable('AosddmPortTxOutputPower');
    }
    if ($opts->{ddm} == 1 && $opts->{class} eq 'alcatel') {
        %alcatelddmtemperaturetable     = gettable('AlcatelddmTemperature');
        %alcatelddmtxmtable             = gettable('AlcatelddmTxOutputPower');
    }

    # Default feature promotions for Alcatel routing switches
    $opts->{usev2c} = 1      if ($opts->{req_usev2c});
    $opts->{alcatelbox} = 1;
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
    
    # Power Supply
    my %idtable;
    
    # OSPF number of routes
    my $OspfRouteNumber;
    
    # QoS Filters on the switch
    my %AlcatelQoSAppliedRuleConditiontable     = gettable('AlcatelQoSAppliedRuleCondition');
    my %AlcatelQoSAppliedRuleActiontable        = gettable('AlcatelQoSAppliedRuleAction');
    my %AosQoSAppliedRuleConditiontable     = gettable('AosQoSAppliedRuleCondition');
    my %AosQoSAppliedRuleActiontable        = gettable('AosQoSAppliedRuleAction');


    # Fan status
    my %FanId;
    my $ldesc;
    my $sdesc;
    
    ### Build OSPF status for AOS 7.x 8.x
    if ($chassisospf){
        ($OspfRouteNumber) =              get('OidAosalaOspfRouteNumber');
        if (defined ($OspfRouteNumber)) {
            Debug ("Building chassis OSPF target...");
            $ldesc = "Number of OSPF neighbors and routes. Variations in these metrics is a sign of instability.";
            $sdesc = "Number of OSPF neighbors and routes. Variations in these metrics is a sign of instability.";
            my ($targetname) = 'ospf';
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "chassis." . $targetname,
                'notes'               => $ldesc,
                'display_name'        => $sdesc,
                '_inst'               => 0,
                '_display_order'              => $opts->{order},
                '_dstemplate'                 => "Alcatel-Chassis-OSPF",
                #'_triggergroup'               => "Alcatel-Chassis-OSPF",
                'use'                 => $opts->{dtemplate},
            );
            # If using custom Alcatel OPSF metrics, do not use MIB-II OSPF runs
            $opts->{req_ospfruns} = 0;    
            $opts->{order} -= 1;
            
        }

       
    }
    if ($chassisfan){

    }
    ### Build powersupply status for AOS 6.x
    if ($chassispowersupply_alcatel) {
            $ldesc = "Powersupply LED status : notApplicable (0), off (1), greenOn (2), greenBlink (3), amberOn (4), amberBlink (5)";
            $sdesc = "Powersupply LED status : notApplicable (0), off (1), greenOn (2), greenBlink (3), amberOn (4), amberBlink (5)";
            Debug ("Building chassis power supply target AOS 6.x...");
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "chassis.powersupply",
                'notes'               => $ldesc,
                'display_name'        => $sdesc,
                '_inst'               => 0,
                '_display_order'              => $opts->{order},
                '_dstemplate'                 => "Alcatel-OS6450-Powersupply-1",
                '_triggergroup'               => "Chassis_OS6450_Powersupply-1",
                'use'                 => $opts->{dtemplate},
            );

        $opts->{order} -= 1;

    }
    
        ### Build powersupply status for AOS 7.x 8.x
    if ($chassispowersupply) {
            $ldesc = "Powersupply LED status : notApplicable (0), off (1), greenOn (2), greenBlink (3), amberOn (4), amberBlink (5)";
            $sdesc = "Powersupply LED status : notApplicable (0), off (1), greenOn (2), greenBlink (3), amberOn (4), amberBlink (5)";
            Debug ("Building chassis power supply target AOS 7.x...");
            
            my $dstemplate = "Alcatel-OS6860-Powersupply";
            $dstemplate = "Alcatel-OS6860-Powersupply" . $vcsize if $vcsize ne '';
            my $triggertemplate = "Chassis_OS6860_Powersupply";
            $triggertemplate = "Chassis_OS6860_Powersupply" . $vcsize if $vcsize ne '';
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "chassis.powersupply",
                'notes'               => $ldesc,
                'display_name'        => $sdesc,
                '_inst'               => 0,
                '_display_order'              => $opts->{order},
                '_dstemplate'                 => $dstemplate,
                '_triggergroup'               => $triggertemplate,
                'use'                 => $opts->{dtemplate},
            );

        $opts->{order} -= 1;

    }
    
    ### Build filter status for AOS 6.x
    if ($chassisfilter_alcatel){
        foreach  my $id (keys %AlcatelQoSAppliedRuleConditiontable) {
            # Skip it in case the power supply table is not supported
            Info("id: " . $id);
            next if (!defined($AlcatelQoSAppliedRuleConditiontable{$id}));
            # Customize the ID of the filter(s) you wish to supervise.
            next unless ($id eq "10.114.73.67.77.80.116.121.112.101.51");
            Debug ("Building chassis filter target...");           
            Debug ("Qos Rule condition :" . $AlcatelQoSAppliedRuleConditiontable{$id});
            Debug ("Qos Rule action : " . $AlcatelQoSAppliedRuleActiontable{$id});
            my ($targetname) = $AlcatelQoSAppliedRuleConditiontable{$id};
            $ldesc = "Number of matches for the filter rule rICMPtype3. Action required.";
            $sdesc = "Number of matches for the filter rule rICMPtype3. Action required.";

            
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "chassis.rulematch." . $targetname,
                'notes'               => $ldesc,
                'display_name'        => $sdesc,
                '_inst'               => "10.114.73.67.77.80.116.121.112.101.51",
                '_display_order'              => $opts->{order},
                '_dstemplate'                 => "Alcatel-AOS6-QoS-Filter",
                '_triggergroup'               => "AOS6_rulematch",
                'use'                 => $opts->{dtemplate},
            );

        $opts->{order} -= 1;
        }
    }


    ### Build chassis helper status for AOS 6.x
    if ($chassishelper){
            my ($helperstatus) = get('AlcatelSspHelperStatus');
            # Skip it in case the helper status is not enabled
            Info("id: " . $id);
            next if (!defined($helperstatus));

            Debug ("Building chassis helper status target...");
            $ldesc = "Alcatel Stack Switch Helper Status VCSP - enabled (1) disabled (2). If disabled, check Virtual chassis VCSP status and helper switch configruation and status.";
            $sdesc = "Alcatel Stack Switch Helper Status VCSP - enabled (1) disabled (2)";


            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "chassis.helper.status",
                'notes'               => $ldesc,
                'display_name'        => $sdesc,
                '_inst'               => "0",
                '_display_order'              => $opts->{order},
                '_dstemplate'                 => "Alcatel-AOS6-HelperStatus",
                '_triggergroup'               => "AOS6_helper",
                'use'                 => $opts->{dtemplate},
            );

        $opts->{order} -= 1;

    }
       

  ### Build filter status for AOS 8.x                                                                                                                                                     
    if ($chassisfilter){                                                                                                                                                                    
        foreach  my $id (keys %AosQoSAppliedRuleConditiontable) {                                                                                                                       
            # Skip it in case the power supply table is not supported                                                                                                                       
            Info("id: " . $id);                                                                                                                                                             
            next if (!defined($AosQoSAppliedRuleConditiontable{$id}));                                                                                                                  
            # Customize the ID of the filter(s) you wish to supervise.                                                                                                                      
            next unless ($id eq "10.114.73.67.77.80.116.121.112.101.51");                                                                                                                   
            Debug ("Building chassis filter target...");                                                                                                                                    
            Debug ("Qos Rule condition :" . $AosQoSAppliedRuleConditiontable{$id});                                                                                                     
            Debug ("Qos Rule action : " . $AosQoSAppliedRuleActiontable{$id});                                                                                                          
            my ($targetname) = $AosQoSAppliedRuleConditiontable{$id};                                                                                                                   
            $ldesc = "Number of matches for the filter rule rICMPtype3. Action required.";                                                                                                  
            $sdesc = "Number of matches for the filter rule rICMPtype3. Action required.";                                                                                                  
                                                                                                                                                                                            
                                                                                                                                                                                            
            $file->writetarget("service {", '',                                                                                                                                             
                'host_name'           => $opts->{devicename},                                                                                                                               
                'service_description' => "chassis.rulematch." . $targetname,                                                                                                                        
                'notes'               => $ldesc,                                                                                                                                            
                'display_name'        => $sdesc,                                                                                                                                            
                '_inst'               => "10.114.73.67.77.80.116.121.112.101.51",                                                                                                           
                '_display_order'              => $opts->{order},                                                                                                                            
                '_dstemplate'                 => "Alcatel-AOS8-QoS-Filter",                                                                                                                      
                '_triggergroup'               => "AOS8_rulematch",                                                                                                                          
                'use'                 => $opts->{dtemplate},                                                                                                                                
            );                                                                                                                                                                              
                                                                                                                                                                                            
        $opts->{order} -= 1;                                                                                                                                                                
        }                                                                                                                                                                                   
    }


    ### Build config and synch status for AOS 8.x
    if ($chassisconfig){

            Debug ("Building chassis config and synch status");
            $ldesc = "Configuration status and synchronisation status for chassis 1. If synchronisation and config status OID .1.3.6.1.4.1.6486.801.1.1.1.3.1.1.1.1.6 are missing, chassis 1 may be down.";
            $sdesc = "Configuration status and synchronisation status for chassis 1. If OID missing, chassis 1 may be down.";


            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "chassis.config.status",
                'notes'               => $ldesc,
                'display_name'        => $sdesc,
                '_inst'               => "0",
                '_display_order'              => $opts->{order},
                '_dstemplate'                 => "Alcatel-AOS8-Config",
                '_triggergroup'               => "AOS8_config",
                'use'                 => $opts->{dtemplate},
            );

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
    my $nu         = $data->{nu};
    my $class      = $data->{class};
    my $match      = $data->{match};
    my $customsdesc = $data->{customsdesc};
    my $customldesc = $data->{customldesc};
    my $c          = $data->{c};
    my $target = $data->{target};

    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###

    # Add DDM statistics if required
    
    CONDITION1:
    {
        if ($target =~ /Alcatel-Lucent_/) {
            #DDM Optical DAC
            next if $opts->{ddm} == 0;
            next if ($opts->{class} eq 'aos' && !defined ($aosddmtemperaturetable{$index . ".1"}));
            next if ($opts->{class} eq 'alcatel' && !defined ($alcatelddmtemperaturetable{$index . ".1"}));
    
            if ($opts->{class} eq 'alcatel' && defined ($alcatelddmtxmtable{$index . ".1"}) && $alcatelddmtxmtable{$index . ".1"} eq -200) {
                push(@config, '_dstemplate' => 'standard-interface' . $nu . $hc . '-alcatelddmDAC');
                Debug ("Found an alcatelddmDAC interface: " . $alcatelddmtxmtable{$index . ".1"});
                Debug ("Found an alcatelddmDAC interface.temp:" . $alcatelddmtemperaturetable{$index . ".1"});

                $match = 1;
            } elsif ($opts->{class} eq 'aos' && defined ($aosddmtxmtable{$index . ".1"}) && $aosddmtxmtable{$index . ".1"} eq -200 ) {
                push(@config, '_dstemplate' => 'standard-interface' . $nu . $hc . '-aosddmDAC');
                Debug ("Found an aosddmDAC interface.tx:" . $aosddmtxmtable{$index . ".1"});
                Debug ("Found an aosddmDAC interface.temp:" . $aosddmtemperaturetable{$index . ".1"});
                $match = 1;
            } elsif ($opts->{class} eq 'aos') {
                push(@config, '_dstemplate' => 'standard-interface' . $nu . $hc . '-aosddm');
                Debug ("Found an aosddm interface.:" . $aosddmtxmtable{$index . ".1"});
                Debug ("Found an aosddm interface.temp:" . $aosddmtemperaturetable{$index . ".1"});
                $match = 1;
            } elsif ($opts->{class} eq 'alcatel') {
                push(@config, '_dstemplate' => 'standard-interface' . $nu . $hc . '-alcatelddm');
                Debug ("Found an alcatelddm interface.:" . $alcatelddmtxmtable{$index . ".1"});
                Debug ("Found an alcatelddm interface.temp:" . $alcatelddmtemperaturetable{$index . ".1"});
                $match = 1;
            }
        }
    }
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
    $data->{nu}        = $nu;
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
