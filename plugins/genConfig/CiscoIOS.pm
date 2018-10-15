# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2002 Francois Mikus
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

package CiscoIOS;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.16;

### End package init


###############################################################################
# These are device types we can handle in this plugin
# the names should be contained in the sysdescr string
# returned by the devices. The name is a regular expression.
###############################################################################
my @types = ( 'IOS ',
    '^C\d\d\d+ Software \(',
    'Cisco Systems Catalyst'
);


###############################################################################
# These are the type and scale of sensor data
###############################################################################

my(%SensorDataType)=('1'  =>  'other',
    '2'   =>  'unknown',
    '3'   =>  'voltsAC',
    '4'   =>  'voltsDC',
    '5'   =>  'amperes',
    '6'   =>  'watts',
    '7'   =>  'hertz',
    '8'   =>  'celsius',
    '9'   =>  'percentRH',
    '10'  =>  'rpm',
    '11'  =>  'cmm',
    '12'  =>  'truthvalue',
    '13'  =>  'specialEnum',
    '14'  =>  'dBm',
);
my(%SensorDataScale)=('1'  =>  'yocto',
    '2'   =>  'zepto',
    '3'   =>  'atto',
    '4'   =>  'femto',
    '5'   =>  'pico',
    '6'   =>  'nano',
    '7'   =>  'micro',
    '8'   =>  'milli',
    '9'   =>  'units',
    '10'  =>  'kilo',
    '11'  =>  'mega',
    '12'  =>  'giga',
    '13'  =>  'tera',
    '14'  =>  'exa',
    '15'  =>  'peta',
    '16'  =>  'zetta',
    '17'  =>  'yotta',
);

###############################################################################
### SAA RTR Agent type definitions.
###############################################################################

my(%rttprotocol)=('1'   =>  'notApplicable',
    '2'   =>  'ipIcmpEcho',
    '3'   =>  'ipUdpEchoAppl',
    '4'   =>  'snaRUEcho',
    '5'   =>  'snaLU0EchoAppl',
    '6'   =>  'snaLU2EchoAppl',
    '7'   =>  'snaLU62Echo',
    '8'   =>  'snaLU62EchoAppl',
    '9'   =>  'appleTalkEcho',
    '10'  =>  'appleTalkEchoAppl',
    '11'  =>  'decNetEcho',
    '12'  =>  'decNetEchoAppl',
    '13'  =>  'ipxEcho',
    '14'  =>  'ipxEchoAppl',
    '15'  =>  'isoClnsEcho',
    '16'   =>  'isoClnsEchoAppl',
    '17'  =>  'vinesEcho',
    '18'  =>  'vinesEchoAppl',
    '19'  =>  'xnsEcho',
    '20'  =>  'xnsEchoAppl',
    '21'  =>  'apolloEcho',
    '22'  =>  'apolloEchoAppl',
    '23'  =>  'netbiosEchoAppl',
    '24'  =>  'ipTcpConn',
    '25'  =>  'httpAppl',
    '26'  =>  'dnsAppl',
    '27'  =>  'jitterAppl',
    '28'  =>  'dlswAppl',
    '29'  =>  'dhcpAppl',
    '30'  =>  'ftpAppl',
    '31'  =>  'mplsLspPingAppl',
    '32'  =>  'voipAppl',
    '33'  =>  'rtpAppl',
    '34'  =>  'icmpJitterAppl'
);

# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
my %OIDS = (

    ### from mib-2.entityMIB.entityMIBObjects.entityPhysical.
    ###      entPhysicalTable.entPhysicalEntry

    'entPhysicalName'            => '1.3.6.1.2.1.47.1.1.1.1.7',
    'entPhysicalDescr'           => '1.3.6.1.2.1.47.1.1.1.1.2',
    'entPhysicalParent'       => '1.3.6.1.2.1.47.1.1.1.1.4',

    'entPhysicalModelName'       => '1.3.6.1.2.1.47.1.1.1.1.13',

    ### from cisco.ciscoMgmt.ciscoRttMonMIB.ciscoRttMonObjects.
    ### rttMonCtrl.rttMonCtrlAdminTable.rttMonCtrlAdminEntry. *

    'rttMonCtrlAdminTag'           => '1.3.6.1.4.1.9.9.42.1.2.1.1.3',
    'rttMonCtrlOperState'         => '1.3.6.1.4.1.9.9.42.1.2.9.1.10',

    ### from cisco.ciscoMgmt.ciscoRttMonMIB.ciscoRttMonObjects...
    ### I can't figure out in what format the TargetAdress is encoded in?
    ### If anyone can figure it out it would be very cool.

    'rttMonEchoAdminProtocol'      => '1.3.6.1.4.1.9.9.42.1.2.2.1.1',
    'rttMonEchoAdminTargetAddress' => '1.3.6.1.4.1.9.9.42.1.2.2.1.2',

    'ccarConfigAccIdx'      =>          '1.3.6.1.4.1.9.9.113.1.1.1.1.4',

    'cbwfqObject' => '1.3.6.1.4.1.9.9.166.1.7.1.1.1',
    'cbwfqPolicy' => '1.3.6.1.4.1.9.9.166.1.5.1.1.2',
    'cbQosPolicyDirection' => '1.3.6.1.4.1.9.9.166.1.1.1.1.3',
    'cbQosIfIndex' => '1.3.6.1.4.1.9.9.166.1.1.1.1.4',

    ### from Cisco OLD-CHASSIS-MIB

    'cardIfSlotNumber'      =>          '1.3.6.1.4.1.9.3.6.13.1.2',
    'cardIfPortNumber'      =>          '1.3.6.1.4.1.9.3.6.13.1.3',

    ### from CISCO-PROCESS-MIB
    ###

    'cpmCPUTotal1minRev'         => '1.3.6.1.4.1.9.9.109.1.1.1.1.7',
    'cpmCPUTotalPhysicalIndex'   => '1.3.6.1.4.1.9.9.109.1.1.1.1.2',

    ### from cisco.ciscoMgmt.ciscoFrameRelayMIB.ciscoFrMIBObjects.
    ###      cfrCircuitObjs.cfrExtCircuitTable.cfrExtCircuitEntry

    'cfrExtCircuitSubifIndex' => '1.3.6.1.4.1.9.9.49.1.2.2.1.3',

    ### from mib-2.transmission.frame-relay.frCircuitTable.
    ###      frCircuitEntry.

    'frCircuitState'   => '1.3.6.1.2.1.10.32.2.1.3',

    ### from cisco.local.linterfaces.lifTable.lifEntry

    'CiscolocIfDescr'  => '1.3.6.1.4.1.9.2.2.1.1.28',

    ### from Cisco ESSWITCH-MIB
    'swPortName' => '1.3.6.1.4.1.437.1.1.3.3.1.1.3',

    ### from mib-2.transmission.dialControlMib.dialControlMibObjects.
    ###      dialCtlPeer.dialCtlPeerCfgTable.dialCtlPeerCfgEntry.
    'dialCtlPeerCfgOriginateAddress' => '1.3.6.1.2.1.10.21.1.2.1.1.4',
    'dialCtlPeerCfgIfType' => '1.3.6.1.2.1.10.21.1.2.1.1.2',

    ### from Cisco-EnvMon-MIB
    'ciscoEnvMonFanState' => '1.3.6.1.4.1.9.9.13.1.4.1.3',
    'ciscoEnvMonFanStatusDescr' => '1.3.6.1.4.1.9.9.13.1.4.1.2',

    'ciscoEnvMonSupplyState' => '1.3.6.1.4.1.9.9.13.1.5.1.3',
    'ciscoEnvMonSupplyStatusDescr' => '1.3.6.1.4.1.9.9.13.1.5.1.2',

    'entSensorDataType'  => '1.3.6.1.4.1.9.9.91.1.1.1.1.1',
    'entSensorDataScale'  => '1.3.6.1.4.1.9.9.91.1.1.1.1.2',
    'entSensorPrecision'  => '1.3.6.1.4.1.9.9.91.1.1.1.1.3',
    'entSensorValue'  => '1.3.6.1.4.1.9.9.91.1.1.1.1.4',

);

###############################################################################
### Private variables
###############################################################################

my (%frCircuitState, %cfrExtCircuitSubifIndex);
my (%PeerCfgOrigAddr, %PeerCfgIfType);
my (%ciscoEnvMonFanState, %ciscoEnvMonFanStatusDescr);
my (%ciscoEnvMonSupplyState, %ciscoEnvMonSupplyStatusDescr);
my $peerid;
my $snmp;
my $customfile;

my $script = "CiscoIOS genDevConfig Module";
my $module = "CiscoIOS";

###############################################################################
###############################################################################

#-------------------------------------------------------------------------------
# plugin_name
# IN : 
# OUT: returns the plugin name defined in $script
#-------------------------------------------------------------------------------

sub plugin_name {
    my $self = shift;
    return $script;
}

#-------------------------------------------------------------------------------
# can_handle
# IN : opts reference
# OUT: returns a true if the device can be handled by this plugin
#-------------------------------------------------------------------------------

sub can_handle {
    my($self, $opts) = @_;

    Debug ("$module Trying to match sysDescr : " . $opts->{sysDescr});

    #return (grep { $opts->{sysDescr} =~ m/$_/gi } @types)
    foreach my $type (@types) {
        $type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        Debug ("$module Type : " . $type);
        return 1 if ($opts->{sysDescr} =~ m/$type/gi)
    }
    return 0;
}

#-------------------------------------------------------------------------------
# discover
# IN : options reference
# OUT: N/A
#-------------------------------------------------------------------------------


sub pad {
    my( $str, $width, $pad )= @_;
    $width= 2   if  ! defined $width;
    $pad= "0"   if  ! defined $pad;
    my ($mapping) = map {sprintf"%${width}s",$_} $str;
    $mapping =~ s/ /$pad/g;
    return  $mapping;
}

sub discover {
    my($self, $opts) = @_;

    ### Add our OIDs to the global OID list

    register_oids(%OIDS);

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    ### Figure out the IOS version number.  We need this
    ### to figure out which oid to use to get interface descriptions and which
    ### MIBs are supported.

    ($opts->{vendor_soft_ver}) = ($opts->{sysDescr} =~ m/Version\s+([\d\.]+)\(\d/o);
    if (defined $opts->{vendor_soft_ver}) {
        $opts->{vendor_descr_oid} = ($opts->{vendor_soft_ver} ge "11.1") # IOS 11.1 supports ifAlias
            ? "ifAlias" : "CiscolocIfDescr";
        $opts->{req_framestats} = 0 if ($opts->{vendor_soft_ver} le "11.2"); # Demote framestats for unsupported IOS

        ## 12.2+ supports ifInOctets/ifOutOctets on
        #fast ethernet sub-interfaces (ifType 53 & 135).
        $opts->{req_vlans} = 0 if ($opts->{req_vlans} && $opts->{sysDescr} =~ / C\d\d\d0 / && $opts->{vendor_soft_ver} lt "12.0");
        $opts->{req_vlans} = 0 if ($opts->{req_vlans} && $opts->{sysDescr} !~ / C\d\d\d0 |Catalyst 4000/ && $opts->{vendor_soft_ver} lt "12.2");

    } elsif ($opts->{sysDescr} =~ /IOS-XE Software/) {
        $opts->{vendor_descr_oid} = "ifAlias";
        $opts->{noql} = 1;
        Debug ("interface description : ifAlias");
    } elsif ($opts->{sysDescr} =~ m/Cisco Systems Catalyst/) {
        $opts->{vendor_descr_oid} = "swPortName";
    } else { ### Maybe it's a Micro Switch...
        $opts->{vendor_descr_oid} = "ifName";
    }

    # Some platforms support additional CPU monitoring
    # currently it's only for cisco 12k and 75xx platforms
    $opts->{req_vipstats} = 0  unless ($opts->{chassisstats} && ($opts->{sysDescr} =~ / GS / || $opts->{sysDescr} =~ / RSP /));
    # 7x00 Series platforms are starting to show some issues with the OLD-CHASSIS-MIB.
    $opts->{req_ciscoslotport} = 0  if (($opts->{sysDescr} =~ / GS / || $opts->{sysDescr} =~ / RSP /));

    if ($opts->{sysDescr} =~ /IOS\s+(\(tm\)|Software,)/) {
        ($opts->{model}) = $opts->{sysDescr} =~ /IOS\s+(?:\(tm\)|Software,)\s+(\S+)/;
        Info("Found an IOS device: model: $opts->{model}");
        $opts->{dtemplate} = "default-snmp-template";
    } elsif ($opts->{sysDescr} =~ /Cisco Systems Catalyst/) {
        ($opts->{model}) = $opts->{sysDescr} =~ /Cisco Systems Catalyst (\d+)/;
        Info("Found an IOS device (alternate sysDescr) : $opts->{model}");
        $opts->{dtemplate} = "default-snmp-template";
    } elsif ($opts->{sysDescr} =~ /C\d\d\d+ Software \(/ ) {
        ($opts->{model}) = $opts->{sysDescr} =~ /(\S+) Software \(/;
        Info("Found an IOS device (alternate sysDescr) : $opts->{model}");
        $opts->{dtemplate} = "default-snmp-template";
    }

    if ($opts->{model} =~ /MSFC/) {
        $opts->{chassisPhysicalDescr} = $opts->{model};
    }

    # Default feature promotions for IOS Devices
    # Note: Auto-demote extended mib-ii as we already use cisco proprietary
    # mibs.
    $opts->{ciscobox} = 1    if ($opts->{req_vendorbox});
    $opts->{ciscoint} = 1    if ($opts->{req_vendorint});
    $opts->{extendedint} = 0    if ($opts->{req_extendedint});
    $opts->{namedonly} = 1   if ($opts->{req_namedonly});
    $opts->{framestats} = 1  if ($opts->{req_framestats});
    $opts->{voip} = 1        if ($opts->{req_voip});
    $opts->{vipstats} = 1    if ($opts->{req_vipstats});
    $opts->{ciscoslotport} = 1    if ($opts->{req_ciscoslotport});
    $opts->{fanstatus} = 1    if ($opts->{req_fanstatus});
    $opts->{supplystatus} = 1    if ($opts->{req_supplystatus});
    $opts->{class} = 'cisco';
    $opts->{cbqos} = 1    if ($opts->{req_cbqos});
    $opts->{noql} = 1    if ($opts->{req_noql});

    if  ($opts->{model} eq 'C3500XL' || $opts->{model} eq 'C2900XL') {
        $opts->{chassisttype} = 'Catalyst-XL-Switch';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "C3550") {
        $opts->{chassisttype} = 'Catalyst-3550-Switch';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "C2950") {
        $opts->{chassisttype} = 'Catalyst-2950-Switch';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "C2960S") {
        $opts->{chassisttype} = 'Catalyst-2960S-Switch';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
        $opts->{maxoidrequest} = "32";
    } elsif ($opts->{model} eq "1900") {
        $opts->{chassisttype} = 'Catalyst-1900-Switch';
    } elsif ($opts->{model} eq "7500") {
        $opts->{chassisttype} = 'Cisco-7500-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "7200") {
        $opts->{chassisttype} = 'Cisco-7200-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "7000") {
        $opts->{chassisttype} = 'Cisco-7000-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /4500/) {
        $opts->{chassisttype} = 'Cisco-4500-Router';
    } elsif ($opts->{model} =~ /3[789]00/) {
        $opts->{chassisttype} = 'Cisco-3800-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /3600/) {
        $opts->{chassisttype} = 'Cisco-3600-Router';
    } elsif ($opts->{model} =~ /2[789]00/) {
        $opts->{chassisttype} = 'Cisco-2900-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "C1200") {
        $opts->{chassisttype} = 'Cisco-1200-AP';
    } elsif ($opts->{model} =~ /2600/) {
        $opts->{chassisttype} = 'Cisco-2600-Router';
    } elsif ($opts->{model} =~ /1[89]00/) {
        $opts->{chassisttype} = 'Cisco-1800-Router';
    } elsif ($opts->{model} =~ /1700/) {
        $opts->{chassisttype} = 'Cisco-1700-Router';
    } elsif ($opts->{model} =~ /1600/) {
        $opts->{chassisttype} = 'Cisco-1600-Router';
    } elsif ($opts->{model} =~ /3000/) {
        $opts->{chassisttype} = 'Cisco-Terminal';
        $opts->{chassisname} = 'chassis.TerminalSvr';
        $opts->{collect} = 0;
    } elsif ($opts->{model} =~ /8[06789]./) {
        $opts->{chassisttype} = 'Cisco-800-Router';
    } elsif ($opts->{model} =~ /2500/) {
        $opts->{chassisttype} = 'Cisco-2500-Router';
    } elsif ($opts->{model} =~ /c6sup2_rp/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /WS-X5530/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /MSFC2/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /LS1010/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /C5RSM/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq 'GS') {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /RSP/) {
        $opts->{chassisttype} = 'Cisco-7500-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /IOS-XE/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
        $opts->{maxoidrequest} = "32";
    } elsif ($opts->{model} =~ /s2t54/) { #Catalyst 6K Sup2
        $opts->{chassisttype} = 'Cisco-Generic-Sup2';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
        $opts->{maxoidrequest} = "32";
    } elsif ($opts->{ciscobox}) {   # Default Cisco config
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    }

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

    #    ### Cisco Specific Slot/Port mapping tables
    #
    #my %cardIfSlotNumber;
    #my %cardIfPortNumber;
    #if ($opts->{ciscoslotport}) {
    #    %cardIfSlotNumber = gettable('cardIfSlotNumber');
    #    %cardIfPortNumber = gettable('cardIfPortNumber');
    #
    #    # Build a Cisco specific Slot/Port Mapping using deprecated MIB
    #    foreach my $index (keys %cardIfSlotNumber) {
    #        if (defined($cardIfPortNumber{$index})){
    #        next if $cardIfSlotNumber{$index} eq "-1"; # Bug fix for invalid slots numbers
    #            $slotPortMapping{$index} = "$cardIfSlotNumber{$index}/$cardIfPortNumber{$index}";
    #        } else {
    #		$slotPortMapping{$index} = "$cardIfSlotNumber{$index}/0";
    #            }
    #        }
    #    }
    #    # Build generic two level Slot/Port mapping for Cisco devices.
    #    foreach my $index (keys %ifdescr) {
    #        if ($ifdescr{$index} =~ /([a-zA-Z]+)(\d+)$/) {
    #            next if (%cardIfSlotNumber && %cardIfPortNumber);
    #            ### Fudge the slot/port mapping to the ifdescr for Cisco devices
    #            $slotPortMapping{$index} = "$1$2";
    #        }
    #        next unless $ifdescr{$index} =~ m(([a-zA-Z]+)(\d+)/(\d+)(/?)(\d*));
    #        ### Build a mapping between the ifDescr and its associated Slot.
    #        $slotPortList{$ifdescr{$index}} = $2;
    #        ### Build a mapping between the Slot number and its name.
    #        $slotNameList{$2} = "$1_$2";
    #        ### Build a list of existing slots. This will serve to store the
    #        $slotList{$2}++;
    #        next if (%cardIfSlotNumber && %cardIfPortNumber);
    #        if (!$4){
    #                $slotPortMapping{$index} = "$1$2/$3";
    #        }else{
    #                $slotPortMapping{$index} = "$1$2/$3$4$5";
    #        }
    #
    #}

    ### Get frame relay DLCI info if needed.
    Debug("$module Getting data from device to use in building");

    if ($opts->{framestats}) {
        %frCircuitState          =         gettable('frCircuitState');
        %cfrExtCircuitSubifIndex = reverse gettable('cfrExtCircuitSubifIndex');
    }

    ### Get fan status table

    if ($opts->{fanstatus}) {
        %ciscoEnvMonFanState         =         gettable('ciscoEnvMonFanState');
        %ciscoEnvMonFanStatusDescr        =         gettable('ciscoEnvMonFanStatusDescr');
    }

    if ($opts->{supplystatus}) {
        %ciscoEnvMonSupplyState         =         gettable('ciscoEnvMonSupplyState');
        %ciscoEnvMonSupplyStatusDescr        =         gettable('ciscoEnvMonSupplyStatusDescr');
    }

    ### Get VoIP dial peer info if needed.

    if ($opts->{voip}) {
        %PeerCfgOrigAddr = gettable('dialCtlPeerCfgOriginateAddress');
        %PeerCfgIfType   = gettable('dialCtlPeerCfgIfType');
    }

    ### Get SAA(RTR) Agent information if needed.

    my (%rttMonEchoAdminProtocol, %rttMonEchoAdminTargetAddress, %rttMonCtrlOperState, %rttMonCtrlAdminTag);
    if ($opts->{rtragents}) {
        %rttMonEchoAdminProtocol      =    gettable('rttMonEchoAdminProtocol');
        %rttMonCtrlOperState          =    gettable('rttMonCtrlOperState');
        %rttMonCtrlAdminTag           =    gettable('rttMonCtrlAdminTag');
        %rttMonEchoAdminTargetAddress =    gettable('rttMonEchoAdminTargetAddress');
    }

    ### Get CPU stats

    my %cpu1min;
    my %physindex;
    my %cpunames;
    my %cpudescrs;
    my %cpumodels;

    if ($opts->{vipstats}) {
        %cpu1min     =       gettable('cpmCPUTotal1minRev');
        %physindex   =       gettable('cpmCPUTotalPhysicalIndex');
        %cpunames    =       gettable('entPhysicalName');
        %cpudescrs   =       gettable('entPhysicalDescr');
        %cpumodels   =       gettable('entPhysicalModelName');
    }

    ### get CAR rate shaping

    my %cisco_car;
    if ($opts->{ciscobox}) {
        %cisco_car = gettable('ccarConfigAccIdx');
    }

    ### Get Class Based Qos statistics

    my %cisco_cbwfq_obj; # Object
    my %cisco_cbwfq_pol; # Policy
    if ($opts->{ciscobox} && $opts->{cbqos} ) {
        %cisco_cbwfq_obj = gettable('cbwfqObject');
        %cisco_cbwfq_pol = gettable('cbwfqPolicy');
    }

    ### Get sensor data, new style MIB for CPU, FAN, PS

    my %cisco_entSensorDataType; #  Integer { other(1), unknown(2), voltsAC(3), voltsDC(4), amperes(5), watts(6), hertz(7), celsius(8), percentRH(9), rpm(10), cmm(11), truthvalue(12), specialEnum(13), dBm(14) }
    my %cisco_entSensorDataScale; # Integer { yocto(1), zepto(2), atto(3), femto(4), pico(5), nano(6), micro(7), milli(8), units(9), kilo(10), mega(11), giga(12), tera(13), exa(14), peta(15), zetta(16), yotta(17) }
    my %cisco_entSensorPrecision; # This variable indicates the number of decimal places of precision in fixed-point sensor values reported by entSensorValue.
    my %cisco_entSensorValue; # The value
    my %entPhysicalName; # The value
    my %entPhysicalModel; # The value
    my %entPhysicalParent; # Relative position of the container name based on the sensor

    if ($opts->{ciscobox}) {
        %cisco_entSensorDataType  = gettable('entSensorDataType');
        %cisco_entSensorDataScale = gettable('entSensorDataScale');
        %cisco_entSensorPrecision = gettable('entSensorPrecision');
        %cisco_entSensorValue     = gettable('entSensorValue');
        %entPhysicalName         = gettable('entPhysicalName');
        %entPhysicalModel         = gettable('entPhysicalModelName');
        %entPhysicalParent  = gettable('entPhysicalParent');
    }

    ### Build Temperature and other blade sensors for Catalyst CatX690X

    # iso.3.6.1.2.1.47.1.1.1.1.2.2000 = STRING: "Chassis 1 WS-X6904-40G DCEF2T 4 port 40GE / 16 port 10GE Rev. 1.0"
    # iso.3.6.1.2.1.47.1.1.1.1.2.2001 = STRING: "Chassis 1 CPU of Module 1"
    # iso.3.6.1.2.1.47.1.1.1.1.2.2002 = STRING: "Chassis 1 module 1 power-output-fail Sensor"
    # iso.3.6.1.2.1.47.1.1.1.1.2.2003 = STRING: "Chassis 1 module 1 outlet temperature Sensor"
    # iso.3.6.1.2.1.47.1.1.1.1.2.2004 = STRING: "Chassis 1 module 1 inlet temperature Sensor"
    # iso.3.6.1.2.1.47.1.1.1.1.2.2005 = STRING: "Chassis 1 module 1 insufficient cooling Sensor"

    # iso.3.6.1.4.1.9.9.91.1.1.1.1.4.2002 = INTEGER: 1
    # iso.3.6.1.4.1.9.9.91.1.1.1.1.4.2003 = INTEGER: 42
    # iso.3.6.1.4.1.9.9.91.1.1.1.1.4.2004 = INTEGER: 25
    # iso.3.6.1.4.1.9.9.91.1.1.1.1.4.2005 = INTEGER: 1


    # Do stuff insufficient cooling Sensor, outlet temperature Sensor, inlet temperature Sensor
    Debug("$module Trying to build Chassis module for power-output-fail and insufficient cooling");

    if ($opts->{ciscobox} && %entPhysicalName) {
        foreach my $sensor (keys %entPhysicalName) {
            if ($entPhysicalName{$sensor} =~ /Chassis \d+ module \d+/ && $entPhysicalName{$sensor} =~ /power-output-fail Sensor|insufficient cooling Sensor|outlet temperature Sensor|inlet temperature Sensor|fan-upgrade required Sensor/ && defined($cisco_entSensorValue{$sensor})) {
                Debug("Sensor $sensor description: " . $entPhysicalName{$sensor});
                next if ($entPhysicalName{$sensor} =~ /outlet temperature Sensor|inlet temperature Sensor/ && $entPhysicalModel{$entPhysicalParent{$sensor}} !~ /VS-SUP/);
                Debug("Sensor $sensor passed");
                my $target = $entPhysicalName{$sensor};
                $target =~ s/[\/\s:]/\_/g;
                $target =~ s/\,/_/g;
                $target = "chassis-5min." . $target;

                my $ldesc = $entPhysicalName{$sensor};
                $ldesc .= "<BR> Chassis : " . $entPhysicalModel{$entPhysicalParent{$sensor}};
                $ldesc .= "<BR> Precision : Sensor 1 OK or 1+N FAIL" if $entPhysicalName{$sensor} =~ /power-output-fail Sensor/;
                $ldesc .= "<BR> Precision : Sensor 1 OK or 1+N FAIL" if $entPhysicalName{$sensor} =~ /insufficient cooling Sensor/;
                $ldesc .= "<BR> Precision : Sensor in Celsius" if $entPhysicalName{$sensor} =~ /outlet temperature Sensor/;
                $ldesc .= "<BR> Precision : Sensor in Celsius" if $entPhysicalName{$sensor} =~ /inlet temperature Sensor/;
                $ldesc .= "<BR> Precision : Sensor 1 OK or 1+N FAIL" if $entPhysicalName{$sensor} =~ /fan-upgrade required Sensor/;

                my $dstemplate = 'cisco-chassis-sensor';
                $dstemplate .= "-power-output-fail" if $entPhysicalName{$sensor} =~ /power-output-fail Sensor/;
                $dstemplate .= "-insufficient-cooling" if $entPhysicalName{$sensor} =~ /insufficient cooling Sensor/;
                $dstemplate .= "-outlet-temp" if $entPhysicalName{$sensor} =~ /outlet temperature Sensor/;
                $dstemplate .= "-inlet-temp" if $entPhysicalName{$sensor} =~ /inlet temperature Sensor/;
                $dstemplate .= "-fan-upgrade-required" if $entPhysicalName{$sensor} =~ /fan-upgrade required Sensor/;

                my $triggertemplate = "cisco_chassis_sensor";
                $triggertemplate .= "_power_output_fail" if $entPhysicalName{$sensor} =~ /power-output-fail Sensor/;
                $triggertemplate .= "_insufficient_cooling" if $entPhysicalName{$sensor} =~ /insufficient cooling Sensor/;
                $triggertemplate .= "_outlet_temp" if $entPhysicalName{$sensor} =~ /outlet temperature Sensor/;
                $triggertemplate .= "_inlet_temp" if $entPhysicalName{$sensor} =~ /inlet temperature Sensor/;
                $triggertemplate .= "_fan_upgrade_required" if $entPhysicalName{$sensor} =~ /fan_upgrade required Sensor/;

                $file->writetarget("service {", '',
                    'host_name'           => $opts->{devicename},
                    'service_description' => $target,
                    'notes'               => $ldesc,
                    'display_name'        => $target,
                    '_inst'               => $sensor,
                    '_display_order'      => $opts->{order},
                    '_dstemplate'         => "cisco-sensor-state",
                    '_triggergroup'       => $triggertemplate,
                    'use'                 => $opts->{dtemplate} . "_5min",

                );
                $opts->{order} -= 1;
            }
        }
    }

    ### Build Sensor supervision data for Optical Interfaces
    Debug("$module Trying to build Optical interface info");

    if ($opts->{ciscobox} && %entPhysicalName) {
        foreach my $sensor (keys %entPhysicalName) {
            Debug("Sensor $sensor description: " . $entPhysicalName{$sensor});

            if ($entPhysicalName{$sensor} =~ /Transmit Power Sensor|Receive Power Sensor/ && defined($cisco_entSensorValue{$sensor})) {
                Debug("In IF Sensor $sensor description: " . $entPhysicalName{$sensor});
                my $target = $entPhysicalName{$sensor};
                $target =~ s/[\/\s:]/\_/g;
                $target =~ s/\,/_/g;
                my $ldesc = $entPhysicalName{$sensor};
                $ldesc .= "<BR> Model : " . $entPhysicalModel{$entPhysicalParent{$sensor}} if ($entPhysicalName{$sensor} =~ /Transmit Power Sensor/);
                $ldesc .= "<BR> Model : " . $entPhysicalModel{$entPhysicalParent{$sensor}} if ($entPhysicalName{$sensor} =~ /Receive Power Sensor/);
                $ldesc .= "<BR> Type  : " . $SensorDataType{$cisco_entSensorDataType{$sensor}};
                $ldesc .= "<BR> Scale : " . $SensorDataScale{$cisco_entSensorDataScale{$sensor}};
                $ldesc .= "<BR> Precision : " . $cisco_entSensorPrecision{$sensor};


                my $triggertemplate = "chassis_cisco_ddm";

                # Process the target name to get it to something sortable and without slashes
                # TODO Convert this to a function, no reason to clutter main code.

                Debug ("Cleaned_target: $target");
                my $description;
                if ($entPhysicalName{$sensor} =~ /Transmit Power Sensor/){
                    ($target,$description) = split(/Transmit/,$target);
                    $description = "_Transmit" . $description;
                } else {
                    ($target,$description) = split(/Receive/,$target);
                    $description = "_Receive" . $description;
                }
                my ($cc, $bb, $aa) = split(/_/,$target);
                # Pad string if it exists, is a single character and is a number
                $aa = pad($aa) if (defined $aa && (scalar (split("", $aa))<2) && $aa =~ /^[0-9]+$/);
                $bb = pad($bb) if (defined $bb && (scalar (split("", $bb))<2) && $bb =~ /^[0-9]+$/);
                if (defined $cc && (substr $cc, -1) =~ /^[0-9]$/ && (substr $cc, -2) !~ /^[0-9]+$/) {
                    my $d = chop $cc;
                    $cc .= pad($d);
                }
                if (defined $aa) {
                    $target = join ('_', $cc, $bb, $aa);
                } elsif (defined $bb) {
                    $target = join ( '_', $cc, $bb);
                } else {
                    $target = $cc;
                }
                $target .= $description;
                Debug ("Padded_target: $target");
                # End process

                $file->writetarget("service {", '',
                    'host_name'           => $opts->{devicename},
                    'service_description' => $target,
                    'notes'               => $ldesc,
                    'display_name'        => $target,
                    '_inst'               => $sensor,
                    '_display_order'      => $opts->{order},
                    '_dstemplate'         => "cisco-sensor-ddm",
                    '_triggergroup'       => $triggertemplate,
                    'use'                 => "generic-sensor-service",
                );

                $opts->{order} -= 1;
            }
        }
    }
    ### Building CPU VIP Stats for Cisco 7500, 12000 series routers
    Debug("$module Trying to build VIP stats");

    if ($opts->{vipstats}) {

        foreach  my $cpu (keys %cpu1min) {
            next if ( defined $physindex{$cpu} && ($physindex{$cpu} == 0 ));

            my ($cpuname) = $cpunames{$physindex{$cpu}};
            my ($slotnum) = $cpuname;
            $slotnum =~ /(.*) ([0-9]+$)/;
            $slotnum = $2;
            my ($cpudescr) = $cpudescrs{$physindex{$cpu}};
            my ($cpumodel) = $cpumodels{$physindex{$cpu}};
            my($target) = "vip_cpu_" . $cpuname;
            $target =~ s/[\/\s:,\.]/\_/g;
            my $ldesc = $opts->{devicename} if ($opts->{devicename});
            $ldesc .= "<BR>" . $cpuname;
            $ldesc .= "<BR>" . $cpudescr;
            $ldesc .= "<BR>" . $cpumodel;
            $cpudescr =~ s/,.*$//g;
            my $sdesc = "CPU " . $cpuname . ": " . $cpudescr;

            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => $target,
                'notes'               => $ldesc,
                'display_name'        => $sdesc,
                '_inst'               => $cpu,
                '_display_order'              => $opts->{order},
                '_dstemplate'                 => "cisco-vip-cpu",
                'use'                 => $opts->{dtemplate},
            );

            $opts->{order} -= 1;
        }
    }

    ### Build frame relay stats config if required.
    Debug("$module Trying to build framerelay stats");

    my %dlcis;
    if ($opts->{framestats}) {
        foreach my $key (keys %frCircuitState) {
            next if ($frCircuitState{$key} != 2);       # active DLCIs only.
            my($inst, $dlci) = split(/\./,$key);
            push(@{$dlcis{$ifdescr{$inst}}}, $dlci);
        }
    }
    Debug("$module Trying to build CBQOS");
    ### Build the Class Based Weighted Fair Queued QoS Statistics
    ### Cisco Only
    if ($opts->{cbqos} && %cisco_cbwfq_obj && %cisco_cbwfq_pol) {
        my %servicepolicy;
        my $qostype = 'cisco-cbwfq-qos';

        foreach my $key (keys %cisco_cbwfq_obj) {
            my $name_cell;
            my $config_id1_cell;
            my $config_id2_cell;
            my $pol_id_cell;
            my $obj_id_cell;
            my $targetname;
            my $targetdesc;
            my $instance;
            my ($ldesc, $sdesc);
            my $ifindex;
            my $policydirection;
            my $ifdescr;
            my $ifacedescr;
            my $policy; # id: iface.directon
            my %dup_hash;

            $name_cell = $cisco_cbwfq_obj{$key};
            $config_id1_cell = $key;

            foreach $key (keys %cisco_cbwfq_pol) {
                ($pol_id_cell, $obj_id_cell)= split(/\./,$key);
                $config_id2_cell = $cisco_cbwfq_pol{$key};

                if ($config_id1_cell == $config_id2_cell) {
                    if ( exists $dup_hash{$pol_id_cell} ) {
                        next if $dup_hash{$pol_id_cell} = $config_id2_cell;
                    } else {
                        $dup_hash{$pol_id_cell}	= $config_id2_cell;
                    }
                    ($policydirection) = get('cbQosPolicyDirection' . "." . $pol_id_cell);
                    $policydirection = $policydirection == 1 ? "input" : "output";
                    ($ifindex) = get('cbQosIfIndex' . "." . $pol_id_cell);
                    Debug ("ifindex=$ifindex, policydirection=$policydirection, pol_id_cell=$pol_id_cell");
                    $ifdescr = $ifdescr{$ifindex} . "." . $ifindex;
                    $ifacedescr = $ifdescr;
                    $ifacedescr =~ s/[\/\s:,\.]/\_/g;
                    $instance = "$pol_id_cell.$obj_id_cell";
                    $ldesc = "CBWFQ QoS for $ifdescr\[$policydirection\]: $name_cell";
                    $sdesc = "QoS $ifdescr\[$policydirection\]: $name_cell";
                    $targetdesc = "QoS_$ifdescr\_$policydirection\_$name_cell";
                    $targetname = "qos_$ifacedescr\_$policydirection\_$name_cell";

                    $file->writetarget("service {", '',
                        'host_name'           => $opts->{devicename},
                        'service_description'   => $targetname,
                        '_interface_name' => $targetdesc,
                        'notes'          => $ldesc,
                        'display_name'   => $targetname,
                        '_dstemplate'            => $qostype,
                        '_inst'          => $instance,
                        '_hide'          => 'true',
                        '_display_order'          => $opts->{order},
                        'use'                 => $opts->{dtemplate},
                    );
                    $opts->{order} -= 1;

                    $policy = "$ifdescr,$policydirection";
                    if (exists($servicepolicy{$policy})) {
                        $servicepolicy{$policy} = "$servicepolicy{$policy};$targetname";
                    } else {
                        $servicepolicy{$policy} = "$targetname";
                    }
                }
            }
        }

    }

    ### Build Cisco Traffic shaping based on CAR
    Debug("$module Trying to build CAR");
    if ($opts->{ciscobox} && keys(%cisco_car)) {
        my $key;
        my ($ifindex,$direction,$rowindex,$rest);
        my $ifname;
        my $filename;
        my ($sdesc,$ldesc);
        my $acl;
        foreach $key (keys(%cisco_car)) {
            my @config = ();
            ($ifindex,$direction,$rowindex)=split/\./,$key;
            $ifname=$ifdescr{$ifindex};
            $ifname =~ s/[\/\s:]/\_/g;
            $rest=$direction.".".$rowindex;
            if ($direction eq "1"){
                $direction="input";
            } else {
                $direction="output"
            }
            if($cisco_car{$key}==0){
                $acl="ANY";
            }else{
                $acl="ACL".$cisco_car{$key};
            }
            $ifname.="_".$acl."_".$direction."_ratelimit";
            $sdesc="rate-limit $direction $ifdescr{$ifindex}  - $intdescr{$ifindex}";
            $ldesc="$ifdescr{$ifindex} $acl $direction ratelimit  - $intdescr{$ifindex}";

            push(@config,
                'host_name'           => $opts->{devicename},
                'service_description' =>  "ifcar." . $ifname,
                '_display_order'              =>  $opts->{order},
                'notes'               =>  $ldesc . " " . $rest,
                'display_name'        =>  $ifdescr{$ifindex},
                '_dstemplate'                 =>  'rate-limit',
                'use'                 => $opts->{dtemplate},
            );
            $file->writetarget("service {", '', @config);

            $opts->{order} -= 1;
        }
    }

    ### Build the SAA(RTR) rtt agent stats for the specified instances
    Debug("$module Trying to build rtragents");

    if ($opts->{rtragents} && %rttMonCtrlOperState) {
        foreach my $key (keys %rttMonCtrlOperState) {

            my ($ldesc, $sdesc);

            ### More verbose output
            #Debug ("RtrOperStatus for rtr $key: $rttMonCtrlOperState{$key}\n");

            ### Process only active agents
            next if ($rttMonCtrlOperState{$key} != 6);

            my ($protocol) = $rttprotocol{$rttMonEchoAdminProtocol{$key}};
            next if ($key == 1); # Invalid protocol
            my ($address) = translateRttTargetAddr($protocol, $rttMonEchoAdminTargetAddress{$key});
            $ldesc = 'Cisco SLA (RTR) using ' . $protocol . ' for destination <B>'. $address . " - " . $rttMonCtrlAdminTag{$key} . '</B>';
            #ICMP Operational values: <BR>Operational values: 1(Ok) 2(Disconnct) 4(Timeout) 5(Busy) 6(NoConnection) 7(LackIntRes) 8(BadSeqID) 9(BadData) 16(Error)' ;

            $sdesc = 'Cisco SLA (RTR) using ' . $protocol .
                ' for destination ip: ' . $address . ' tag: ' . $rttMonCtrlAdminTag{$key};

            #Debug ("Destination for $key tag: $rttMonCtrlAdminTag{$key} addr: $address\n");
            my ($targetname) = 'SaaRtt_Agent_' . $key;

            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description'        => $targetname,
                '_inst'        => $key,
                '_display_order'       => $opts->{order},
                'display_name' => $targetname,
                'notes'        => $ldesc,
                #'short-desc'   => $sdesc,
                '_dstemplate'          => $protocol,
                'use'                 => $opts->{dtemplate},
            );
            $opts->{order} -= 1;
        }
    }

    ## Avoids creating empty directory if no VOIP targets found.
    Debug("$module Trying to build dialpeer");
    if ($opts->{voip} && %PeerCfgOrigAddr) {

        my $customdir = subdir("$opts->{rdir}/dialpeers",$opts->{lowercase});

        $customfile = $opts->{dpfile} = new genConfig::File("$customdir/targets");

        genConfig::File::set_file_header("# Generated by $script\n".
            "# Args: $opts->{savedargs}\n".
            "# Date: ". scalar(localtime(time)). "\n\n");

        foreach my $key (keys %PeerCfgOrigAddr) {
            Debug ("PeerCfgOrigAddr for peer $key: $PeerCfgOrigAddr{$key}\n");
        }

    } else {
        $opts->{voip} = 0;
    }

    ### Build the fan stats
    # IOS iso.3.6.1.4.1.9.9.13.1.4.1.2.1007 = STRING: "Switch#1, Fan#1"
    Debug("$module Trying to build fan status for IOS");
    if ($opts->{fanstatus} && %ciscoEnvMonFanState && ($opts->{model} !~ /IOS-XE/) && ($opts->{model} !~ /s2t54/)) {
        foreach my $key (keys %ciscoEnvMonFanState) {

            my ($ldesc, $sdesc);
            $ldesc = 'Cisco Fan State for ' . $ciscoEnvMonFanStatusDescr{$key} . '. Status normal(1). On degraded status, replace fan.';
            $sdesc = 'Cisco Fan State for ' . $ciscoEnvMonFanStatusDescr{$key};
            $ldesc =~ tr/,/ /;
            $sdesc =~ tr/,/ /;

            my ($name, $fan, $rest) = split(/, /,$ciscoEnvMonFanStatusDescr{$key});
            Debug("$name $fan $ldesc");

            my ($targetname) = 'CiscoFan_state_for_switch' . chop($name) . "_fan" . chop($fan);

            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description'        => $targetname,
                '_inst'        => $key,
                '_display_order'       => $opts->{order},
                'display_name' => $targetname,
                'notes'        => $ldesc,
                '_triggergroup'   => 'chassis_cisco_fan_state',
                '_dstemplate'          => 'cisco-fan-state',
                'use'                 => $opts->{dtemplate},
            );
            $opts->{order} -= 1;
        }
    }

    ### Build the fan stats for IOS-XE
    # iso.3.6.1.4.1.9.9.13.1.4.1.2.1 = STRING: "Chassis Fan Tray 1"
    # iso.3.6.1.4.1.9.9.13.1.4.1.2.2 = STRING: "Chassis Fan Tray 2"
    # iso.3.6.1.4.1.9.9.13.1.4.1.2.3 = STRING: "Chassis Fan Tray 3"
    # iso.3.6.1.4.1.9.9.13.1.4.1.2.4 = STRING: "Chassis Fan Tray 4"
    # iso.3.6.1.4.1.9.9.13.1.4.1.2.5 = STRING: "Chassis Fan Tray 5"
    # iso.3.6.1.4.1.9.9.13.1.4.1.2.6 = STRING: "Power Supply 1 Fan"

    # iso.3.6.1.4.1.9.9.13.1.4.1.2.101 = STRING: "chassis-1 Chassis Fan Tray 1"
    # iso.3.6.1.4.1.9.9.13.1.4.1.2.102 = STRING: "chassis-1 Power Supply 1 Fan"
    # iso.3.6.1.4.1.9.9.13.1.4.1.2.103 = STRING: "chassis-1 Power Supply 2 Fan"
    # iso.3.6.1.4.1.9.9.13.1.4.1.2.201 = STRING: "chassis-2 Chassis Fan Tray 1"
    Debug("$module Trying to build fan status for IOS-XE, Cat 6K Sup s2t54");

    if ($opts->{fanstatus} && %ciscoEnvMonFanState && (($opts->{model} =~ /IOS-XE/) || ($opts->{model} =~ /s2t54/)) ) {
        foreach my $key (keys %ciscoEnvMonFanState) {

            my ($ldesc, $sdesc, $swid, $targetname, $chassis);
            my ($name, $fanid, $rest);

            ($chassis, $rest) = split(/ /,$ciscoEnvMonFanStatusDescr{$key});

            if ($opts->{model} =~ /IOS-XE/) {
                if ($key < 8 ){
                    $swid = 1;
                } else {
                    $swid = 2;
                }
            } else {
                $swid = chop $chassis;
            }
            $ldesc = 'Cisco Fan state for ' . $ciscoEnvMonFanStatusDescr{$key} . '. Status normal(1). On degraded status, replace fan.';
            $sdesc = 'Cisco Fan state for ' . $ciscoEnvMonFanStatusDescr{$key};
            $targetname = 'CiscoFan_state_for_switch_' . $swid . "_" . $rest if ($opts->{model} =~ /IOS-XE/);

            my ($description) = $ciscoEnvMonFanStatusDescr{$key};
            $description =~ tr/,/ /;
            $description =~ tr/ /_/;
            $targetname = 'CiscoFan_state_for_' . $description if ($opts->{model} =~ /s2t54/);

            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description'        => $targetname,
                '_inst'        => $key,
                '_display_order'       => $opts->{order},
                'display_name' => $targetname,
                'notes'        => $ldesc,
                '_triggergroup'   => 'chassis_cisco_fan_state',
                '_dstemplate'          => 'cisco-fan-state',
                'use'                 => $opts->{dtemplate},
            );
            $opts->{order} -= 1;
        }
    }

    # IOS-XE
    # iso.3.6.1.4.1.9.9.13.1.5.1.2.1 = STRING: "Power Supply 1"
    # iso.3.6.1.4.1.9.9.13.1.5.1.2.2 = STRING: "Power Supply 2"
    # IOS
    # iso.3.6.1.4.1.9.9.13.1.5.1.2.1006 = STRING: "Sw1, PS1 Normal, RPS NotExist"
    ### Build the power supply stats
    Debug("$module Trying to build power supply status for IOS and IOS-XE");
    if ($opts->{supplystatus} && %ciscoEnvMonSupplyState && ($opts->{model} !~ /s2t54/)) {
        foreach my $key (keys %ciscoEnvMonSupplyState) {

            my ($ldesc, $sdesc);
            $ldesc = 'Cisco Supply State for ' . $ciscoEnvMonSupplyStatusDescr{$key} . '. Status normal(1). On degraded status, replace powersupply or switch.';
            $sdesc = 'Cisco Supply State for ' . $ciscoEnvMonSupplyStatusDescr{$key};
            my ($name, $rest);
            my ($ps, $junk);
            Info (" Supplydescr: $ciscoEnvMonSupplyStatusDescr{$key}");
            if ($opts->{model} !~ /IOS-XE/) {
                ($name, $rest) = split(/, /,$ciscoEnvMonSupplyStatusDescr{$key});
                ($ps, $junk) = split(/\s+/,$rest);
            } else {
                $rest = $ciscoEnvMonSupplyStatusDescr{$key};
            }
            Debug("$module Power supply description: $ciscoEnvMonSupplyStatusDescr{$key}");

            my ($targetname) = '';
            $targetname = 'CiscoSupply_state_for_switch' . chop($name) . "_ps" . chop($ps) unless $opts->{model} =~ /IOS-XE/;

            $targetname = 'CiscoSupply_state_ps' . chop($rest) if $opts->{model} =~ /IOS-XE/;

            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description'        => $targetname,
                '_inst'        => $key,
                '_display_order'       => $opts->{order},
                'display_name' => $targetname,
                'notes'        => $ldesc,
                '_triggergroup'   => 'chassis_cisco_power_state',
                '_dstemplate'          => 'cisco-supply-state',
                'use'                 => $opts->{dtemplate},
            );
            $opts->{order} -= 1;
        }
    }

    # S2t54
    # iso.3.6.1.4.1.9.9.13.1.5.1.2.101 = STRING: "chassis-1 Power Supply 1, WS-CAC"
    # iso.3.6.1.4.1.9.9.13.1.5.1.2.102 = STRING: "chassis-1 Power Supply 2, WS-CAC"
    # iso.3.6.1.4.1.9.9.13.1.5.1.2.201 = STRING: "chassis-2 Power Supply 1, WS-CAC"
    # iso.3.6.1.4.1.9.9.13.1.5.1.2.202 = STRING: "chassis-2 Power Supply 2, WS-CAC"

    Debug("$module Trying to build power supply status for IOS-XE");
    if ($opts->{supplystatus} && %ciscoEnvMonSupplyState && ($opts->{model} =~ /s2t54/)) {
        foreach my $key (keys %ciscoEnvMonSupplyState) {

            my ($ldesc, $sdesc);
            $ldesc = 'Cisco Supply State for ' . $ciscoEnvMonSupplyStatusDescr{$key} . '. Status normal(1). On degraded status, replace powersupply or switch.';
            $sdesc = 'Cisco Supply State for ' . $ciscoEnvMonSupplyStatusDescr{$key};
            Debug("$module Power supply description: $ciscoEnvMonSupplyStatusDescr{$key}");

            my ($targetname) = '';
            my ($description) = $ciscoEnvMonSupplyStatusDescr{$key};
            $description =~ tr/,/ /;
            $description =~ tr/ /_/;
            $targetname = 'CiscoSupply_state_for_' . $description;

            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description'        => $targetname,
                '_inst'        => $key,
                '_display_order'       => $opts->{order},
                'display_name' => $targetname,
                'notes'        => $ldesc,
                '_triggergroup'   => 'chassis_cisco_power_state',
                '_dstemplate'          => 'cisco-supply-state',
                'use'                 => $opts->{dtemplate},
            );
            $opts->{order} -= 1;
        }
    }


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
    my %ifdescr    = %{$data->{ifdescr}}; # What is used for processing
    my %intdescr   = %{$data->{intdescr}}; # What is displayed for an interface
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
    my $target      = $data->{target};

    my @collectableuplinks = @{$opts->{collectableuplinks}};

    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###

    $peerid = '';
    if ($iftype{$index} == 103 || $iftype{$index} == 104) {

        ### If it's a dial peer interface, get it's peer ID and add it
        ### to the config.

        if ($opts->{voip}) {
            ($peerid) = $ifdescr{$index} =~ /Peer:\s+(\d+)/;
            push(@config,
                '_peerid' => $peerid,
                '_dstemplate'    => 'dial-peer',);

            $customfile = $opts->{dpfile}; # Select the file to store configs
            $customsdesc .= "Dial Peer stats: " . $PeerCfgOrigAddr{$peerid.'.'.$index};
            $customldesc = "Dial Peer stats: Call Address: $PeerCfgOrigAddr{$peerid.'.'.$index}";
        }
        # Set any non-sticky variables
        $opts->{show_max} = 0; # Do not display max and max_octets for dp interfaces
        $opts->{nomtucheck} = 1; # Do not skip the interface due to insane mtu
        $opts->{nospeedcheck} = 1; #Do not skip the interface due to insane speed

        $match = 1;

    } elsif ($iftype{$index} == 32 &&  $ifdescr{$index} =~ /\.\d+$/) {

        ### If we're collecting frame relay stats and this is a frame relay
        ### interface, get the main interface description and the DLCI
        ### add them to the config.  (frame stats are stored under the main
        ### interface index, so that's what we need from the instance map)
        ### Otherwise set the interface as a simple sub-interface.

        if ($opts->{framestats} && ($ifdescr{$index} =~ /\.\d+$/) &&
            exists $cfrExtCircuitSubifIndex{$index}) {

            if (defined $opts->{vendor_soft_ver} &&
                ($opts->{vendor_soft_ver} lt "11.1") &&
                !defined $intdescr{$index}) {

                ###  This is a frame-relay sub-interface *and* the router
                ###  is running an IOS older than 11.1. Therefore, we can
                ###  get neither ifAlias nor ciscoLocIfDesc. Do something
                ###  useful.
                $intdescr{$index} = "Cisco PVCs descriptions require IOS 11.1+.";
            }

            my $dspname = $ifdescr{$index};
            my ($mainif, $dlci);
            ($mainif, $dlci) = split(/\./, $cfrExtCircuitSubifIndex{$index});
            $ifdescr{$index} = $ifdescr{$mainif};
            $customsdesc = "dspname: $dspname dlci: $dlci";
            $customldesc = "dspname: $dspname dlci: $dlci";
            push(@config,      '_dlci'           => $dlci,
                '_dstemplate'             => 'frame-interface',);

            $match = 1;

        } else {

            push(@config,
                '_dstemplate' => 'sub-interface' . $hc,);

            $match = 1;
        }
        $opts->{nomtucheck} = 1;

    }  elsif ($opts->{ciscoint}) {

        ### Collect extra info from Cisco MIB

        # Override global classification to only apply minimal thresholds
        #$class = '-access' if (($iftype{$index} == 81 ) || ($iftype{$index} == 77) || ($iftype{$index} == 23)); # ISDN

        # Check if NU Cast packet statistics are required

        Debug ("Pushing dstemplate: cisco-interface to: $target");
        push(@config,
            '_dstemplate' => 'cisco-interface' . $nu . $hc,);

        my $porttemplate;

        if (($opts->{req_portuplinklist}) && inlist("$target $intdescr{$index}",@collectableuplinks) ){
            if ($opts->{triggers}) {
                Debug ("Triggers enabled : $opts->{triggers} : interface $opts->{triggerifstatus} $nu $hc");
                push(@config, '_triggergroup' => 'interface' . $opts->{triggerifstatus}  . $nu . $hc);
            }
        }


        $match = 1;
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
    $data->{nu}     = $nu;
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
    my $file           = ${$data->{file}};
    my $c              = ${$data->{c}};
    my $target         = ${$data->{target}};
    my @config         = @{$data->{config}};
    my $wmatch         = ${$data->{wmatch}};

    ###
    ### START FILE CUSTOM CONFIG SECTION
    ###

    if ($peerid) {
        $customfile->write("\n");
        Info ("Writing dialpeer configuration");
        $customfile->writetarget("service {", $c, @config);
        $wmatch = 1;
    }

    ###
    ### END FILE CUSTOM CONFIG SECTION
    ###

    # Save return value in the reference hash
    ${$data->{wmatch}}  = $wmatch;
}

sub inlist {
    my ($string,@list) = @_;
    foreach my $item (@list) {
        return 1 if ($string =~ /$item/);
    }
    return 0;
}

1;

