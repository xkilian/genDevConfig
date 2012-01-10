# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2007 Optek Pty Ltd (snmp@optekconsulting.com) 
#    Loosely based on other modules from the genDevConfig beta distribution.
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

package CiscoCSS;

use strict;

use Data::Dumper;
use SNMP_util;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.01;

### End package init


# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.

my $entBase = '1.3.6.1.4.1';
my %entOIDs = (
	'Ap' => '2467',
	'Cs' => '9.9.368',
);

my %CSS_OIDS = (
 'apCnt' => {
     'Table'  => '1.16.4.1',
     'Fields' => {
	  'apCntOwner' => '1',
	  'apCntName' => '2',
	  'apCntIndex' => '3',
	  'apCntIPAddress' => '4',
	  'apCntIPProtocol' => '5',
	  'apCntPort' => '6',
	  'apCntUrl' => '7',
	  'apCntSticky' => '8',
	  'apCntBalance' => '9',
	# 'apCntQOSTag' => '10',
	  'apCntEnable' => '11',
	  'apCntRedirect' => '12',
	  'apCntDrop' => '13',
	  'apCntSize' => '14',
	# 'apCntPersistence' => '15',
	# 'apCntAuthor' => '16',
	# 'apCntSpider' => '17',
	  'apCntHits' => '18',
	  'apCntRedirects' => '19',
	  'apCntDrops' => '20',
	# 'apCntRejNoServices' => '21',
	# 'apCntRejServOverload' => '22',
	# 'apCntSpoofs' => '23',
	# 'apCntNats' => '24',
	  'apCntByteCount' => '25',
	  'apCntFrameCount' => '26',
	# 'apCntZeroButton' => '27',
	# 'apCntHotListEnabled' => '28',
	# 'apCntHotListSize' => '29',
	# 'apCntHotListThreshold' => '30',
	# 'apCntHotListType' => '31',
	# 'apCntHotListInterval' => '32',
	# 'apCntFlowTrack' => '33',
	# 'apCntWeightMask' => '34',
	# 'apCntStickyMask' => '35',
	# 'apCntCookieStartPos' => '36',
	# 'apCntHeuristicCookieFence' => '37',
	# 'apCntEqlName' => '38',
	# 'apCntCacheFalloverType' => '39',
	# 'apCntLocalLoadThreshold' => '40',
	  'apCntStatus' => '41',
	# 'apCntRedirectLoadThreshold' => '42',
	  'apCntContentType' => '43',
	# 'apCntStickyInactivity' => '44',
	# 'apCntDNSBalance' => '45',
	# 'apCntStickyGroup' => '46',
	# 'apCntAppTypeBypasses' => '47',
	# 'apCntNoSvcBypasses' => '48',
	# 'apCntSvcLoadBypasses' => '49',
	# 'apCntConnCtBypasses' => '50',
	# 'apCntUrqlTblName' => '51',
	# 'apCntStickyStrPre' => '52',
	# 'apCntStickyStrEos' => '53',
	# 'apCntStickyStrSkipLen' => '54',
	# 'apCntStickyStrProcLen' => '55',
	# 'apCntStickyStrAction' => '56',
	# 'apCntStickyStrAsciiConv' => '57',
	# 'apCntPrimarySorryServer' => '58',
	# 'apCntSecondSorryServer' => '59',
	# 'apCntPrimarySorryHits' => '60',
	# 'apCntSecondSorryHits' => '61',
	# 'apCntStickySrvrDownFailover' => '62',
	# 'apCntStickyStrType' => '63',
	# 'apCntParamBypass' => '64',
	# 'apCntAvgLocalLoad' => '65',
	# 'apCntAvgRemoteLoad' => '66',
	# 'apCntDqlName' => '67',
	# 'apCntIPAddressRange' => '68',
	# 'apCntTagListName' => '69',
	# 'apCntStickyNoCookieAction' => '70',
	# 'apCntStickyNoCookieString' => '71',
	# 'apCntStickyCookiePath' => '72',
	# 'apCntStickyCookieExp' => '73',
	# 'apCntStickyCacheExp' => '74',
	# 'apCntTagWeight' => '75',
	# 'apCntDNSEnable' => '76',
	# 'apCntRedundancyL4StatelessEnabled' => '77',
	# 'apCntStickyCookieText' => '78',
	# 'apCntStickyCookieUrl' => '79',
	# 'apCntStickyCookieBrowserExpire' => '80',
	# 'apCntStickyCookieServerExpire' => '81',
	# 'apCntStickyCookieHeadUrl' => '82',
	# 'apCntSessionRedundantIndex' => '83',
     }, 
 },
 'apOwn' => {
     'Table'  => '1.25.2.1',
     'Fields' => {
	  'apOwnName' => '1',
	  'apOwnIndex' => '2',
	# 'apOwnMaxFlowPipeBwdth' => '3',
	# 'apOwnFlowPipeBurstTolerance' => '4',
	# 'apOwnMaxPrioritizedFlows' => '5',
	# 'apOwnBillingInfo' => '6',
	# 'apOwnAddress' => '7',
	  'apOwnEmailAddress' => '8',
	# 'apOwnFlowPipeBwdthAlloc' => '9',
	# 'apOwnFlowPipeActiveFlows' => '10',
	# 'apOwnFlowPipeTotalFlows' => '11',
	# 'apOwnFlowPipeTotalMisses' => '12',
	# 'apOwnQosBwdthAlloc' => '13',
	# 'apOwnBEBwdthAlloc' => '14',
	# 'apOwnHits' => '15',
	# 'apOwnDrops' => '17',
	# 'apOwnRejNoServices' => '18',
	# 'apOwnRejServOverload' => '19',
	# 'apOwnSpoofs' => '20',
	# 'apOwnNats' => '21',
	# 'apOwnByteCount' => '22',
	# 'apOwnFrameCount' => '23',
	# 'apOwnDNSPolicy' => '24',
	# 'apOwnStatus' => '25',
	# 'apOwnCaseSensitive' => '26',
	# 'apOwnDNSBalance' => '27',
     },
 },
 'apSvc' => {
     'Table'  => '1.15.2.1',
     'Fields' => {
	  'apSvcName' => '1',
	  'apSvcIndex' => '2',
	  'apSvcIPAddress' => '3',
	  'apSvcIPProtocol' => '4',
	  'apSvcPort' => '5',
	  'apSvcKALType' => '6',
	# 'apSvcKALFrequency' => '7',
	# 'apSvcKALMaxFailure' => '8',
	# 'apSvcKALRetryPeriod' => '9',
	# 'apSvcKALUri' => '10',
	# 'apSvcKALMethod' => '11',
	# 'apSvcEnable' => '12',
	# 'apSvcType' => '13',
	# 'apSvcQOSMinRate' => '14',
	# 'apSvcQOSMinBW' => '15',
	# 'apSvcWeight' => '16',
	# 'apSvcState' => '17',
	# 'apSvcShortLoad' => '18',
	# 'apSvcMaxConnections' => '19',
	# 'apSvcConnections' => '20',
	# 'apSvcTransitions' => '21',
	# 'apSvcMaxContent' => '22',
	# 'apSvcMaxUsage' => '23',
	# 'apSvcMaxAge' => '24',
	# 'apSvcAccessRecordName' => '25',
	# 'apSvcStatus' => '26',
	# 'apSvcCookie' => '27',
	# 'apSvcKALPersistence' => '28',
	# 'apSvcKALName' => '29',
	# 'apSvcLongLoad' => '30',
	# 'apSvcKALPort' => '31',
	# 'apSvcPublishName' => '32',
	# 'apSvcPublishState' => '33',
	# 'apSvcPublishInterval' => '34',
	# 'apSvcAccessType' => '35',
	# 'apSvcKALHash' => '36',
	# 'apSvcKALFTPRecord' => '37',
	# 'apSvcPublishFile' => '38',
	# 'apSvcRedirectDomain' => '39',
	# 'apSvcAvgLoad' => '40',
	# 'apSvcIPAddressRange' => '41',
	# 'apSvcPortRange' => '42',
	# 'apSvcKALScriptName' => '43',
	# 'apSvcKALScriptArgs' => '44',
	# 'apSvcKALScriptLog' => '45',
	# 'apSvcCacheByPass' => '46',
	# 'apSvcRedirectString' => '47',
	# 'apSvcKALScriptOutput' => '48',
	# 'apSvcTransparentHosttag' => '49',
	# 'apSvcBypassHosttag' => '50',
	# 'apSvcKALState' => '51',
	# 'apSvcRedirectPrepend' => '52',
	# 'apSvcSessionRedundantIndex' => '53',
	# 'apSvcSlot' => '54',
	# 'apSvcSubSlot' => '55',
	# 'apSvcSslSessCache' => '56',
	# 'apSvcDFPState' => '57',
	# 'apSvcDFPWeight' => '58',
	# 'apSvcKALMethodDesiredRsp' => '59',
	# 'apSvcTotalBackupConnections' => '60',
	# 'apSvcTotalLocalConnections' => '61',
	# 'apSvcCurrentBackupConnections' => '62',
	# 'apSvcCurrentLocalConnections' => '63',
	# 'apSvcAuthor' => '64',
	# 'apSvcLoad' => '65',
     },
 },
 'apCntsvc' => {
     'Table'  => '1.18.2.1',
     'Fields' => {
	  'apCntsvcOwnName' => '1',
	  'apCntsvcCntName' => '2',
	  'apCntsvcSvcName' => '3',
	# 'apCntsvcHits' => '4',
	# 'apCntsvcBytes' => '5',
	# 'apCntsvcFrames' => '6',
	# 'apCntsvcBucket' => '7',
	# 'apCntsvcStatus' => '8',
	# 'apCntsvcWeight' => '9',
	# 'apCntsvcDnsHits' => '10',
	# 'apCntsvcDnsProximityHits' => '11',
	# 'apCntsvcState' => '12',
	# 'apCntsvcDFPState' => '13',
	# 'apCntsvcDFPWeight' => '14',
     },
 },
);

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################

my @types = ( '^Content Switch ',
            );

###############################################################################
### Private variables
###############################################################################

my $script = "CiscoCSS genDevConfig Module";

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
        $type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        return ($opts->{sysObjectID} =~ m/$type/gi)
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

    if ($opts->{sysDescr} =~ /Version (\d+)\.(\d+)/) {
      if ($1 <= 7 && $2 < 40) {
        $opts->{apVer} = 'Ap';
      } else {
        $opts->{apVer} = 'Cs';
      }
    }

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    $opts->{model} = 'CiscoCSS';
    $opts->{class} = 'CiscoCSS';

    #$opts->{vendor_soft_ver} = get('xxxx');

    $opts->{chassisttype} = 'CiscoCSS';
    $opts->{chassisname} = 'CiscoCSS';
    $opts->{sysDescr} .= "<BR>" . $opts->{apVer} . "<BR>" . $opts->{sysLocation};
    $opts->{ttype} = 'CiscoCSS';

    # Default feature promotions
    $opts->{usev2c} = 1      if ($opts->{req_usev2c});
    $opts->{ciscocss} = 1;

    return;
}

sub target_safe_rrd_name
{
  my ($target) = @_;
  if ($target =~ /:/) {
    $target =~ s/:/_/g;
    return ('rrd-datafile','%dataDir%/'.$target.'.rrd');
  } else {
    return ();
  }
}
#-------------------------------------------------------------------------------
# custom_targets
# IN : options hash
# OUT: returns the options hash
#-------------------------------------------------------------------------------

sub custom_targets {
    my ($self, $data, $opts) = @_;

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

    my $css = {};
    foreach my $tbl (keys %CSS_OIDS) {
      my $b_oid = $entBase.'.'.$entOIDs{$opts->{apVer}}.'.'.$CSS_OIDS{$tbl}->{Table}; 
      foreach my $col (keys %{ $CSS_OIDS{$tbl}->{Fields} }) {
        my $oid = $b_oid . '.' . $CSS_OIDS{$tbl}->{Fields}->{$col};
        register_oids($col,$oid);
        my %t_h = gettable($col);
        $col =~ s/^$tbl//;
        foreach (keys %t_h) {
          $css->{$tbl}->{$_}->{$col} = $t_h{$_};
        }
        foreach ( keys %{ $css->{$tbl} } ) {
          $css->{$tbl}->{$_}->{oid} = $_;
        }
      }
    }
    $self->{cssinfo} = $css;

    # build an index
    my $by_own = {};
    foreach ( values %{ $css->{apCntsvc} } )
    {
      $by_own->{$_->{OwnName}}->{$_->{CntName}}->{$_->{SvcName}} = $_;
    }

    # create an owner subtree
    my $own_sub = subdir($opts->{rdir}.'/Owners',
                           $opts->{lowercase});
    foreach my $c_own ( values %{ $css->{apOwn} } )
    {
      my $own_dir = subdir($own_sub.'/'.$c_own->{Name},
                           $opts->{lowercase});
      my $own_file = new genConfig::File($own_dir.'/targets');

      genConfig::File::set_file_header("# Generated by $script\n".
                 "# Args: $opts->{savedargs}\n".
                 "# Date: ". scalar(localtime(time)). "\n\n");

      Info ("Writing owner $c_own->{Name}");
      $own_file->writetarget('--default--', '',
          'directory-desc' => 'Owner '.$c_own->{Name}
                              .' ['.$c_own->{EmailAddress}.']',
          'target-type'    => 'CiscoCSS-Owner'.$opts->{apVer},
          );

      $own_file->writetarget($c_own->{Name}, '',
          'order'	   => $opts->{order},
          'inst' 	   => 'qw('.$c_own->{oid}.')',
          'target-type'    => 'CiscoCSS-Owner'.$opts->{apVer},
          );
      $opts->{order}--;

      my $sum_order = $opts->{order};
      my @sum_cnts;

      $opts->{order}--;

      foreach my $c_cnt ( sort keys %{ $by_own->{$c_own->{Name}} } )
      {
        ($c_cnt) = grep { $_->{Name} eq $c_cnt } values %{ $css->{apCnt} };

        my $cnt_dir = subdir($own_dir.'/'.$c_cnt->{Name},
                           $opts->{lowercase});
        my $cnt_file = new genConfig::File($cnt_dir.'/targets');

        genConfig::File::set_file_header("# Generated by $script\n".
                   "# Args: $opts->{savedargs}\n".
                   "# Date: ". scalar(localtime(time)). "\n\n");

        my $sdesc = 'Name: ' . $c_cnt->{Name} . '<br>'.
		    'Address: ' .
		    join('/',map {$c_cnt->{$_}} 
                             qw/IPAddress IPProtocol Port/);

        my @svcs = sort keys %{$by_own->{$c_own->{Name}}->{$c_cnt->{Name}}};

        my $ldesc = $sdesc .'<br>';
           $ldesc .= 'Services:<ul>' 
                     . join('', map { "<li>$_</li>" } @svcs)
                     . '</ul>';

       $cnt_file->writetarget('--default--', '',
          'directory-desc' => 'Content: '.$sdesc,
          );

        $cnt_file->writetarget('Content-Totals', '',
            'inst' 	   => 'qw('.$c_cnt->{oid}.')',
            'display-name' => 'Content Totals',
            'target-type'  => 'CiscoCSS-Content'.$opts->{apVer},
            'short-desc'   => $sdesc,
            'long-desc'    => $ldesc,
            'order'	   => $opts->{order},
            );
        $opts->{order}--;

        push @sum_cnts, $c_cnt->{Name}.'/Content-Totals';

        $cnt_file->writetarget('Service-Comparison', '',
            'mtargets'     => join(';',@svcs),
            'display-name' => 'Service Comparison',
            'target-type'  => 'CiscoCSS-ContentService'.$opts->{apVer},
            'short-desc'   => 'Comparison of load over all configured Services',
            'long-desc'    => 'Comparison of load over all configured Services',
            'order'	   => $opts->{order},
            );
        $opts->{order}--;

        foreach my $c_svc (@svcs) {

          ($c_svc) = grep { $_->{Name} eq $c_svc } values %{ $css->{apSvc} };

          $sdesc = 'Service: ' . $c_svc->{Name} . '<br>'.
		    'Address: ' .
		    join('/',map {$c_svc->{$_}} 
                             qw/IPAddress IPProtocol Port/);
      
           my $inst = $by_own->{$c_own->{Name}}
                      ->{$c_cnt->{Name}}
                      ->{$c_svc->{Name}}
                      ->{oid};

           $cnt_file->writetarget($c_svc->{Name}, '',
               'inst'         => 'qw('.$inst.')',
               'display-name' => $c_svc->{Name},
               'target-type'  => 'CiscoCSS-ContentService'.$opts->{apVer},
               'short-desc'   => $sdesc,
               'long-desc'    => $sdesc,
               'order'	      => $opts->{order},
               );
           $opts->{order}--;
        }
      }

      $own_file->writetarget($c_own->{Name}.'-ContentSummary', '',
          'order'	   => $opts->{order},
          'display-name'   => 'Content Summary',
          'short-desc'     => "Comparison of all services under owner $c_own->{Name}",
          'long-desc'      => "Comparison of all services under owner $c_own->{Name}",
          'target-type'    => 'CiscoCSS-Content'.$opts->{apVer},
          'targets'	   => join('; ', @sum_cnts),
          );

    }

    # write a service tree

    my $svc_dir = subdir($opts->{rdir}.'/Services',
                         $opts->{lowercase});

    my $svc_file = new genConfig::File($svc_dir.'/targets');

    genConfig::File::set_file_header("# Generated by $script\n".
               "# Args: $opts->{savedargs}\n".
               "# Date: ". scalar(localtime(time)). "\n\n");

    foreach my $c_svc ( values %{ $css->{apSvc} } )
    {
      my $sdesc = 'Name: ' . $c_svc->{Name} . '<br>'.
                  'Address: ' .
                  join('/',map {$c_svc->{$_}}
                           qw/IPAddress IPProtocol Port/);

      $svc_file->writetarget($c_svc->{Name}, '',
          'order'	   => $opts->{order},
          'inst' 	   => 'qw('.$c_svc->{oid}.')',
          'short-desc'     => $sdesc,
          'long-desc'      => $sdesc,
          'target-type'    => 'CiscoCSS-Service'.$opts->{apVer},
          );

      $opts->{order}--;
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
# IN : options hash
# OUT: returns the options hash
#-------------------------------------------------------------------------------

sub custom_interfaces {
    my ($self, $index, $data, $opts) = @_;

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
    my $peerid     = $data->{peerid};
    my $match      = $data->{match};
    my $sdesc      = $data->{sdesc};
    my $ldesc      = $data->{ldesc};
    
    ###
    ### DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###

    # Apply logic for filtering --gigonly interfaces
    next if ($opts->{gigonly} && int($ifspeed{$index}) != 1000000000 );

    push(@config, 'target-type' => 'standard-interface' . $hc);
    $match = 1;

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
    $data->{config} = @config;
    $data->{hc}     = $hc;
    $data->{class}  = $class;
    $data->{peerid} = $peerid;
    $data->{match}  = $match;
    $data->{sdesc}  = $sdesc;
    $data->{ldesc}  = $ldesc;

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
