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

my $VERSION = 1.12;

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

      );

###############################################################################
### Private variables
###############################################################################

my (%frCircuitState, %cfrExtCircuitSubifIndex);
my (%PeerCfgOrigAddr, %PeerCfgIfType);
my $peerid;
my $snmp;
my $customfile;

my $script = "CiscoIOS genDevConfig Module";

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

    # Validation is based on sysDescr, but could also be based
    # on sysObject OIDs or other well referenced value.
    return (grep { $opts->{sysDescr} =~ m/$_/gi } @types)

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
    } elsif ($opts->{sysDescr} =~ /Cisco Systems Catalyst/) {
        ($opts->{model}) = $opts->{sysDescr} =~ /Cisco Systems Catalyst (\d+)/;
        Info("Found an IOS device (alternate sysDescr) : $opts->{model}");
    } elsif ($opts->{sysDescr} =~ /C\d\d\d+ Software \(/ ) {
 	 ($opts->{model}) = $opts->{sysDescr} =~ /(\S+) Software \(/;
        Info("Found an IOS device (alternate sysDescr) : $opts->{model}");
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
    $opts->{class} = 'cisco';

    if  ($opts->{model} eq 'C3500XL' || $opts->{model} eq 'C2900XL') {
        $opts->{chassisttype} = 'Catalyst-XL-Switch';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "C3550") {
        $opts->{chassisttype} = 'Catalyst-3550-Switch';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "C2950") {
        $opts->{chassisttype} = 'Catalyst-2950-Switch';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "1900") {
        $opts->{chassisttype} = 'Catalyst-1900-Switch';
        $opts->{chassisname} = 'Chassis';
    } elsif ($opts->{model} eq "7500") {
        $opts->{chassisttype} = 'Cisco-7500-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "7200") {
        $opts->{chassisttype} = 'Cisco-7200-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq "7000") {
        $opts->{chassisttype} = 'Cisco-7000-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /4500/) {
        $opts->{chassisttype} = 'Cisco-4500-Router';
        $opts->{chassisname} = 'Chassis'; 
    } elsif ($opts->{model} =~ /3600/) {
        $opts->{chassisttype} = 'Cisco-3600-Router';
        $opts->{chassisname} = 'Chassis';
   } elsif ($opts->{model} =~ /2800/) {
        $opts->{chassisttype} = 'Cisco-2800-Router';
        $opts->{chassisname} = 'Chassis';
    } elsif ($opts->{model} eq "C1200") {
        $opts->{chassisttype} = 'Cisco-1200-AP';
        $opts->{chassisname} = 'Chassis';
    } elsif ($opts->{model} =~ /2600/) {
        $opts->{chassisttype} = 'Cisco-2600-Router';
        $opts->{chassisname} = 'Chassis';
    } elsif ($opts->{model} =~ /1700/) {
        $opts->{chassisttype} = 'Cisco-1700-Router';
        $opts->{chassisname} = 'Chassis';
    } elsif ($opts->{model} =~ /1600/) {
        $opts->{chassisttype} = 'Cisco-1600-Router';
        $opts->{chassisname} = 'Chassis';
    } elsif ($opts->{model} =~ /3000/) {
        $opts->{chassisttype} = 'Cisco-Terminal';
        $opts->{chassisname} = 'Chassis-Terminal';
        $opts->{collect} = 0;
    } elsif ($opts->{model} =~ /80./) {
        $opts->{chassisttype} = 'Cisco-800-Router';
        $opts->{chassisname} = 'Chassis';
    } elsif ($opts->{model} =~ /2500/) {
        $opts->{chassisttype} = 'Cisco-2500-Router';
        $opts->{chassisname} = 'Chassis';
    } elsif ($opts->{model} =~ /c6sup2_rp/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /WS-X5530/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /MSFC2/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /LS1010/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /C5RSM/) {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} eq 'GS') {
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{model} =~ /RSP/) {
        $opts->{chassisttype} = 'Cisco-7500-Router';
        $opts->{chassisname} = 'Chassis';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    } elsif ($opts->{ciscobox}) {   # Default Cisco config
        $opts->{chassisttype} = 'Cisco-Generic-Router';
        $opts->{chassisname} = 'Chassis';
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
    my %slotPortList      = %{$data->{slotPortList}};
    my %slotNameList      = %{$data->{slotNameList}};
    my %slotList          = %{$data->{slotList}};
    my $file = $opts->{file};

    ###
    ### START DEVICE CUSTOM CONFIG SECTION
    ###

    ### Cisco Specific Slot/Port mapping tables

    my %cardIfSlotNumber;
    my %cardIfPortNumber;
    if ($opts->{ciscoslotport}) {
        %cardIfSlotNumber = gettable('cardIfSlotNumber');
        %cardIfPortNumber = gettable('cardIfPortNumber');

        # Build a Cisco specific Slot/Port Mapping using deprecated MIB
        foreach my $index (keys %cardIfSlotNumber) {
            if (defined($cardIfPortNumber{$index})){
            next if $cardIfSlotNumber{$index} eq "-1"; # Bug fix for invalid slots numbers
                $slotPortMapping{$index} = "$cardIfSlotNumber{$index}/$cardIfPortNumber{$index}";
            } else {
		$slotPortMapping{$index} = "$cardIfSlotNumber{$index}/0";
            }
        }
    }
    # Build generic two level Slot/Port mapping for Cisco devices.
    foreach my $index (keys %ifdescr) {
        if ($ifdescr{$index} =~ /([a-zA-Z]+)(\d+)$/) {
            next if (%cardIfSlotNumber && %cardIfPortNumber);
            ### Fudge the slot/port mapping to the ifdescr for Cisco devices
            $slotPortMapping{$index} = "$1$2";
        }
        next unless $ifdescr{$index} =~ m(([a-zA-Z]+)(\d+)/(\d+)(/?)(\d*));
        ### Build a mapping between the ifDescr and its associated Slot.
        $slotPortList{$ifdescr{$index}} = $2;
        ### Build a mapping between the Slot number and its name.
        $slotNameList{$2} = "$1_$2";
        ### Build a list of existing slots. This will serve to store the 
        $slotList{$2}++;
        next if (%cardIfSlotNumber && %cardIfPortNumber);
        if (!$4){
                $slotPortMapping{$index} = "$1$2/$3";
        }else{
                $slotPortMapping{$index} = "$1$2/$3$4$5";
        }

    }

    ### Get frame relay DLCI info if needed.

    if ($opts->{framestats}) {
        %frCircuitState          =         gettable('frCircuitState');
        %cfrExtCircuitSubifIndex = reverse gettable('cfrExtCircuitSubifIndex');
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

    ### Walk cpu statistics for VIPs on Cisco 12000 and 7500s with RSPs
    ### CPU Statistics per VIP

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

    ### Walk ccarStatSwitchedPkts if this is a cisco router
    ### Traffic shaping counters based on CAR

    my %cisco_car;
    if ($opts->{ciscobox}) {
        %cisco_car = gettable('ccarConfigAccIdx');
    }

    ### Walk  1.3.6.1.4.1.9.9.166.1.7.1.1.1 if this is a cisco router
    ### Traffic shaping counters based on Class Based Weighted Fair Queued QoS

    my %cisco_cbwfq_obj; # Object
    my %cisco_cbwfq_pol; # Policy
    if ($opts->{ciscobox}) {
        %cisco_cbwfq_obj = gettable('cbwfqObject');
        %cisco_cbwfq_pol = gettable('cbwfqPolicy');
    }

    ### Building CPU VIP Stats for Cisco 7500, 12000 series routers

    if ($opts->{vipstats}) {

        foreach  my $cpu (keys %cpu1min) {
            next if ( defined $physindex{$cpu} && ($physindex{$cpu} == 0 ));

            my ($cpuname) = $cpunames{$physindex{$cpu}};
            my ($slotnum) = $cpuname;
            $slotnum =~ /(.*) ([0-9]+$)/;
            $slotnum = $2;
            my ($cpudescr) = $cpudescrs{$physindex{$cpu}};
            my ($cpumodel) = $cpumodels{$physindex{$cpu}};
            my($target) = "cpu_" . $cpuname;
            $target =~ s/[\/\s:,\.]/\_/g;
            my $ldesc = $opts->{devicename} if ($opts->{devicename});
            $ldesc .= "<BR>" . $cpuname;
            $ldesc .= "<BR>" . $cpudescr;
            $ldesc .= "<BR>" . $cpumodel;
            $cpudescr =~ s/,.*$//g;
            my $sdesc = "CPU " . $cpuname . ": " . $cpudescr;

            $file->writetarget($target, '',
                    'cpu' => $cpu,
                    'long-desc' => $ldesc,
                    'short-desc' => $sdesc,
                    'target-type' => "cisco-vip-cpu",
                    'display-name' => "%auto-target-name%",
                    'inst'        => 0,
                    'order' => $opts->{order},
            );

            $opts->{order} -= 1;
        }
    }

    ### Build frame relay stats config if required.
    my %dlcis;
    if ($opts->{framestats}) {
        foreach my $key (keys %frCircuitState) {
            next if ($frCircuitState{$key} != 2);       # active DLCIs only.
            my($inst, $dlci) = split(/\./,$key);
            push(@{$dlcis{$ifdescr{$inst}}}, $dlci);
        }
    }

    ### Build the Class Based Weighted Fair Queued QoS Statistics
    ### Cisco Only
    if (%cisco_cbwfq_obj && %cisco_cbwfq_pol) {
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
                    $instance = "\'$pol_id_cell.$obj_id_cell\'";
                    $ldesc = "CBWFQ QoS for $ifdescr\[$policydirection\]: $name_cell";
                    $sdesc = "QoS $ifdescr\[$policydirection\]: $name_cell";
                    $targetdesc = "QoS_$ifdescr\_$policydirection\_$name_cell";
                    $targetname = "qos_$ifacedescr\_$policydirection\_$name_cell";
        
                    $file->writetarget($targetname, '',
                        'interface-name' => $targetdesc,
                        'long-desc'      => $ldesc,
                        'short-desc'     => $sdesc,
                        'target-type'    => $qostype,
                        'inst'           => $instance,
                        'hide'           => 'true',
                        'order'          => $opts->{order},
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
        foreach my $key (keys %servicepolicy) {
            my $targetname;
            my $targetdesc;
            my ($ldesc, $sdesc);
            my $policydirection;
            my $ifdescr;
            my $ifacedescr;
    
            ($ifdescr, $policydirection)= split(/\,/,$key);
            $ifacedescr = $ifdescr;
            $ifacedescr =~ s/[\/\s:,\.]/\_/g;
            $ldesc = "CBWFQ QoS for $ifdescr\[$policydirection\]";
            $sdesc = "QoS $ifdescr\[$policydirection\]";
            $targetdesc = "QoS_$ifdescr\_$policydirection";
            $targetname = "qos_$ifacedescr\_$policydirection";
    
    
            $file->writetarget($targetname, '',
                'interface-name'=> $targetdesc,
                'long-desc' => $ldesc,
                'short-desc'    => $sdesc,
                'target-type'   => $qostype,
                'mtargets'  => "$servicepolicy{$key}",
                            'order'         => $opts->{order},
            );
                    $opts->{order} -= 1;
        }
    }

### Build Cisco Traffic shaping based on CAR

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
            'order'         =>      $opts->{order},
            'short-desc'        =>    $sdesc,
            'long-desc'         =>    $ldesc,
            'interface-name'    =>    $ifdescr{$ifindex},
            'rest'              =>    $rest,
            'target-type'       =>    'rate-limit'
        );
        $file->writetarget($ifname , '', @config);

        $opts->{order} -= 1;
    }
}

### Build the SAA(RTR) rtt agent stats for the specified instances

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

           $file->writetarget($targetname, '',
            'inst'        => $key,
            'order'          => $opts->{order},
            'interface-name'   => $targetname,
            'long-desc'   => $ldesc,
            'short-desc'  => $sdesc,
            'target-type' => $protocol
        );
        $opts->{order} -= 1;
    }
}

## Avoids creating empty directory if no VOIP targets found.
if ($opts->{voip} && %PeerCfgOrigAddr) {

    my $customdir = subdir("$opts->{rdir}/dialpeers",$opts->{lowercase});

    $customfile = $opts->{dpfile} = new genConfig::File("$customdir/targets");

    genConfig::File::set_file_header("# Generated by $script\n".
                 "# Args: $opts->{savedargs}\n".
                 "# Date: ". scalar(localtime(time)). "\n\n");

    Info ("Writing dialpeer default configuration");
    $customfile->writetarget('--default--', '',
        'directory-desc' => 'Dial Peer Stats',
        'target-type'    => 'dial-peer',
        );
    foreach my $key (keys %PeerCfgOrigAddr) {
      Debug ("PeerCfgOrigAddr for peer $key: $PeerCfgOrigAddr{$key}\n");
    }

} else {
    $opts->{voip} = 0;
}

    # Saving local copies of runtime data
    %{$data->{ifspeed}} = %ifspeed;
    %{$data->{ifdescr}} = %ifdescr;
    %{$data->{intdescr}} = %intdescr;
    %{$data->{iftype}} = %iftype;
    %{$data->{ifmtu}} = %ifmtu;
    %{$data->{slotPortMapping}} = %slotPortMapping;
    %{$data->{slotPortList}}    = %slotPortList;
    %{$data->{slotNameList}}    = %slotNameList;
    %{$data->{slotList}}        = %slotList;
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
    my $class      = $data->{class};
    my $match      = $data->{match};
    my $customsdesc = $data->{customsdesc};
    my $customldesc = $data->{customldesc};

    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###

    $peerid = '';
    if ($iftype{$index} == 103 || $iftype{$index} == 104) {

        ### If it's a dial peer interface, get it's peer ID and add it
        ### to the config.

        if ($opts->{voip}) {
            ($peerid) = $ifdescr{$index} =~ /Peer:\s+(\d+)/;
            push(@config, 'peer-id' => $peerid);
            $customfile = $opts->{dpfile}; # Select the file to store configs
            $customsdesc .= $PeerCfgOrigAddr{$peerid.'.'.$index}; 
            $customldesc = "Call Address: $PeerCfgOrigAddr{$peerid.'.'.$index}";
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

            push(@config,      'dlci'           => $dlci,
                               'display-name'   => "$opts->{devicename} $dspname",
                               'target-type'    => 'frame-interface');

            $match = 1;

        } else {

            push(@config, 'target-type' => 'sub-interface' . $hc);
            $match = 1;
        }
        $opts->{nomtucheck} = 1;

    }  elsif ($opts->{ciscoint}) {

        ### Collect extra info from Cisco MIB

        # Override global classification to only apply minimal thresholds
        #$class = '-access' if (($iftype{$index} == 81 ) || ($iftype{$index} == 77) || ($iftype{$index} == 23)); # ISDN

	# Check if NU Cast packet statistics are required
        my ($nu) = $opts->{nustats} ? '-nu' : '';

        push(@config, 'target-type' => 'cisco-interface' . $nu . $hc);
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
        $customfile->writetarget($target, $c, @config);
        $wmatch = 1;
    }

    ###
    ### END FILE CUSTOM CONFIG SECTION
    ###

    # Save return value in the reference hash
    ${$data->{wmatch}}  = $wmatch;
}

1;
