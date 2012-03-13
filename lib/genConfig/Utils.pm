# -*-perl-*-
###############################################################################
#
#    genConfig::Utils module
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
#
###############################################################################

package genConfig::Utils;

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
use Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(fmi translateRttTargetAddr applyMonitoringThresholds);

my ($gInstallRoot);
BEGIN {
    $gInstallRoot = (($0 =~ m:^(.*/):)[0] || "./") . "..";
}

use lib "$gInstallRoot/lib";
use Data::Dumper qw(Dumper);

use Common::Log;
use Socket;

###############################################################################
# Convert bits and bytes to SI units.
###############################################################################

sub fmi {
  my($number, $units) = @_;
  my @short;


  my @abrv = ('','k','M','G','T','P','E');
  my $b = ($units eq 'bytes') ? 'Bytes' : 'Bits';

  my $digits = length("".$number);
  my $divm = 0;
  while ($digits - $divm*3 > 4) { $divm++; }
  my $divnum = $number/10**($divm*3);

  return sprintf("%1.1f %s%s/s", $divnum, $abrv[$divm], $b);
}

###############################################################################
#
# HEX Address conversion for SAA SNMP responses
#
###############################################################################

sub translateRttTargetAddr {
    my ($type, $value) = @_;
    return ("unknown") if (($type ne "ipIcmpEcho") &&
                           ($type ne "ipUdpEchoAppl") &&
                           ($type ne "jitterAppl"));
    $value = inet_ntoa($value);
    Debug("TranslateRttTarget: $value");
    return ( $value );
}


###############################################################################
#
# Interface types based on IANA types
#
###############################################################################

(%ifType_d)=('1'   => 'Other',
           '2'   => 'regular1822',
           '3'   => 'hdh1822',
           '4'   => 'ddnX25',
           '5'   => 'rfc877x25',
           '6'   => 'ethernetCsmacd',
           '7'   => 'iso88023Csmacd',
           '8'   => 'iso88024TokenBus',
           '9'   => 'iso88025TokenRing',
           '10'  => 'iso88026Man',
           '11'  => 'starLan',
           '12'  => 'proteon10Mbit',
           '13'  => 'proteon80Mbit',
           '14'  => 'hyperchannel',
           '15'  => 'fddi',
           '16'  => 'lapb',
           '17'  => 'sdlc',
           '18'  => 'ds1',
           '19'  => 'e1',
           '20'  => 'basicISDN',
           '21'  => 'primaryISDN',
           '22'  => 'propPointToPointSerial',
           '23'  => 'ppp',
           '24'  => 'softwareLoopback',
           '25'  => 'eon',
           '26'  => 'ethernet-3Mbit',
           '27'  => 'nsip',
           '28'  => 'slip',
           '29'  => 'ultra',
           '30'  => 'ds3',
           '31'  => 'sip',
           '32'  => 'frame-relay',
           '33'  => 'rs232',
           '34'  => 'para',
           '35'  => 'arcnet',
           '36'  => 'arcnetPlus',
           '37'  => 'atm',
           '38'  => 'miox25',
           '39'  => 'sonet',
           '40'  => 'x25ple',
           '41'  => 'iso88022llc',
           '42'  => 'localTalk',
           '43'  => 'smdsDxi',
           '44'  => 'frameRelayService',
           '45'  => 'v35',
           '46'  => 'hssi',
           '47'  => 'hippi',
           '48'  => 'modem',
           '49'  => 'aal5',
           '50'  => 'sonetPath',
           '51'  => 'sonetVT',
           '52'  => 'smdsIcip',
           '53'  => 'propVirtual',
           '54'  => 'propMultiplexor',
           '55'  => '100BaseVG',
           #### New IF Types added 9/24/98 by Russ Carleton
               #### (roccor@livenetworking.com)
           #### based on the IANA file updated at
           #### ftp://ftp.isi.edu/mib/ianaiftype.mib
           '56'  => 'Fibre Channel',
           '57'  => 'HIPPI Interface',
           '58'  => 'Obsolete for FrameRelay',
           '59'  => 'ATM Emulation of 802.3 LAN',
           '60'  => 'ATM Emulation of 802.5 LAN',
           '61'  => 'ATM Emulation of a Circuit',
           '62'  => 'FastEthernet (100BaseT)',
           '63'  => 'ISDN & X.25',
           '64'  => 'CCITT V.11/X.21',
           '65'  => 'CCITT V.36',
           '66'  => 'CCITT G703 at 64Kbps',
           '67'  => 'Obsolete G702 see DS1-MIB',
           '68'  => 'SNA QLLC',
           '69'  => 'Full Duplex Fast Ethernet (100BaseFX)',
           '70'  => 'Channel',
           '71'  => 'Radio Spread Spectrum (802.11)',
           '72'  => 'IBM System 360/370 OEMI Channel',
           '73'  => 'IBM Enterprise Systems Connection',
           '74'  => 'Data Link Switching',
           '75'  => 'ISDN S/T Interface',
           '76'  => 'ISDN U Interface',
           '77'  => 'Link Access Protocol D (LAPD)',
           '78'  => 'IP Switching Opjects',
           '79'  => 'Remote Source Route Bridging',
           '80'  => 'ATM Logical Port',
           '81'  => 'AT&T DS0 Point (64 Kbps)',
           '82'  => 'AT&T Group of DS0 on a single DS1',
           '83'  => 'BiSync Protocol (BSC)',
           '84'  => 'Asynchronous Protocol',
           '85'  => 'Combat Net Radio',
           '86'  => 'ISO 802.5r DTR',
           '87'  => 'Ext Pos Loc Report Sys',
           '88'  => 'Apple Talk Remote Access Protocol',
           '89'  => 'Proprietary Connectionless Protocol',
           '90'  => 'CCITT-ITU X.29 PAD Protocol',
           '91'  => 'CCITT-ITU X.3 PAD Facility',
           '92'  => 'MultiProtocol Connection over Frame/Relay',
           '93'  => 'CCITT-ITU X213',
           '94'  => 'Asymetric Digitial Subscriber Loop (ADSL)',
           '95'  => 'Rate-Adapt Digital Subscriber Loop (RDSL)',
           '96'  => 'Symetric Digitial Subscriber Loop (SDSL)',
           '97'  => 'Very High Speed Digitial Subscriber Loop (HDSL)',
           '98'  => 'ISO 802.5 CRFP',
           '99'  => 'Myricom Myrinet',
           '100' =>    'Voice recEive and transMit (voiceEM)',
           '101' =>    'Voice Foreign eXchange Office (voiceFXO)',
           '102' =>    'Voice Foreign eXchange Station (voiceFXS)',
           '103' =>    'Voice Encapulation',
           '104' =>    'Voice Over IP Encapulation',
           '105' =>    'ATM DXI',
           '106' =>    'ATM FUNI',
           '107' =>    'ATM IMA',
           '108' =>    'PPP Multilink Bundle',
           '109' =>    'IBM IP over CDLC',
           '110' =>    'IBM Common Link Access to Workstation',
           '111' =>    'IBM Stack to Stack',
           '112' =>    'IBM Virtual IP Address (VIPA)',
           '113' =>    'IBM Multi-Protocol Channel Support',
           '114' =>    'IBM IP over ATM',
           '115' =>    'ISO 802.5j Fiber Token Ring',
           '116' =>    'IBM Twinaxial Data Link Control (TDLC)',
           '117' =>    'Gigabit Ethernet',
           '118' =>    'Higher Data Link Control (HDLC)',
           '119' =>    'Link Access Protocol F (LAPF)',
           '120' =>    'CCITT V.37',
           '121' =>    'CCITT X.25 Multi-Link Protocol',
           '122' =>    'CCITT X.25 Hunt Group',
           '123' =>    'Transp HDLC',
           '124' =>    'Interleave Channel',
           '125' =>    'Fast Channel',
           '126' =>    'IP (for APPN HPR in IP Networks)',
           '127' =>    'CATV MAC Layer',
           '128' =>    'CATV Downstream Interface',
           '129' =>    'CATV Upstream Interface',
           '130' =>    'Avalon Parallel Processor',
           '131' =>    'Encapsulation Interface',
           '132' =>    'Coffee Pot',
           '133' =>    'Circuit Emulation Service',
           '134' =>    'ATM Sub Interface',
           '135' =>    'Layer 2 Virtual LAN using 802.1Q',
           '136' =>    'Layer 3 Virtual LAN using IP',
           '137' =>    'Layer 3 Virtual LAN using IPX',
           '138' =>    'IP Over Power Lines',
           '139' =>    'Multi-Media Mail over IP',
           '140' =>    'Dynamic synchronous Transfer Mode (DTM)',
           '141' =>    'Data Communications Network',
           '142' =>    'IP Forwarding Interface',
           #### New IF Types added 09/26/00
           #### based on the IANA file updated at
           #### ftp://ftp.isi.edu/mib/ianaiftype.mib
               '143' => 'Multi-rate Symmetric DSL',
               '144' => 'IEEE1394 High Performance Serial Bus',
               '145' => 'HIPPI-6400',
           '146' => 'DVB-RCC MAC Layer',
           '147' => 'DVB-RCC Downstream Channel',
           '148' => 'DVB-RCC Upstream Channel',
           '149' => 'ATM Virtual Interface',
           '150' => 'MPLS Tunnel Virtual Interface',
           '151' => 'Spatial Reuse Protocol',
           '152' => 'Voice Over ATM',
           '153' => 'Voice Over Frame Relay',
           '154' => 'Digital Subscriber Loop over ISDN',
           '155' => 'Avici Composite Link Interface',
           '156' => 'SS7 Signaling Link',
           '157' => 'Prop. P2P wireless interface',
           '158' => 'Frame Forward Interface',
           '159' => 'Multiprotocol over ATM AAL5',
           '160' => 'USB Interface',
           '161' => 'IEEE 802.3ad Link Aggregate',
           '162' => 'BGP Policy Accounting',
           '163' => 'FRF .16 Multilink Frame Relay',
           '164' => 'H323 Gatekeeper',
           '165' => 'H323 Voice and Video Proxy',
           '166' => 'MPLS',
           '167' => 'Multi-frequency signaling link',
           '168' => 'High Bit-Rate DSL - 2nd generation',
           '169' => 'Multirate HDSL2',
           '170' => 'Facility Data Link 4Kbps on a DS1',
           '171' => 'Packet over SONET/SDH Interface',
           '172' => 'DVB-ASI Input',
           '173' => 'DVB-ASI Output',
           '174' => 'Power Line Communtications',
           '175' => 'Non Facility Associated Signaling',
           '176' => 'TR008',
           '177' => 'Remote Digital Terminal',
           '178' => 'Integrated Digital Terminal',
           '179' => 'ISUP',
           '180' => 'prop/Maclayer',
           '181' => 'prop/Downstream',
           '182' => 'prop/Upstream',
           '183' => 'HIPERLAN Type 2 Radio Interface',
           '184' => 'PropBroadbandWirelessAccesspt2multipt',
           '185' => 'SONET Overhead Channel',
           '186' => 'Digital Wrapper',
           '187' => 'aal2 ATM adaptation layer 2',
           '188' => 'radioMAC MAC layer over radio links',
           '189' => 'atmRadio ATM over radio links',
           '190' => 'imt Inter Machine Trunks',
           '191' => 'mvl Multiple Virtual Lines DSL',
           '192' => 'reachDSL Long Reach DSL',
           '193' => 'frDlciEndPt Frame Relay DLCI End Point',
           '194' => 'atmVciEndPt ATM VCI End Point',
           '195' => 'opticalChannel',
           '196' => 'opticalTransport',
           '197' => 'propAtm',
           '198' => 'voiceOverCable',
           '199' => 'infiniband',
           '200' => 'teLink',
           '201' => 'q2931',
           '202' => 'virtualTg Virtual Trunk Group',
           '203' => 'sipTg SIP Trunk Group',
           '204' => 'sipSig SIP Signaling',
           '205' => 'docsCableUpstreamChannel',
           '206' => 'econet',
           '207' => 'pon155 FSAN 155Mb Symetrical PON interface',
           '208' => 'pon622 FSAN622Mb Symetrical PON interface',
           '209' => 'bridge Transparent bridge interface',
           '210' => 'linegroup Interface common to multiple lines',
           '211' => 'voiceEMFGD voice E&M Feature Group D',
           '212' => 'voiceFGDEANA voice FGD Exchange Access North American',
           '213' => 'voiceDID voice Direct Inward Dialing',
           '214' => 'mpegTransport MPEG transport interface',
           '215' => 'sixToFour 6to4 interface',
           '216' => 'gtp GTP GPRS Tunneling Protocol',
           '217' => 'pdnEtherLoop1 Paradyne EtherLoop 1',
           '218' => 'pdnEtherLoop2 Paradyne EtherLoop 2',
           '219' => 'opticalChannelGroup Optical Channel Group',
           '220' => 'homepna HomePNA ITU-T G.989',
           '221' => 'gfp Generic Framing Procedure (GFP)',
           '222' => 'ciscoISLvlan Layer 2 Virtual LAN using Cisco ISL',
           '223' => 'actelisMetaLOOP Acteleis proprietary MetaLOOP',
           '224' => 'fcipLink FCIP Link',
           '225' => 'rpr Resilient Packet Ring Interface Type',
           '226' => 'qam RF Qam Interface',
           '227' => 'lmp Link Management Protocol',
           );
