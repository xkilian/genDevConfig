# -*- mode: Perl -*-
###############################################################################
#
#    genConfig::SNMP module
#
#    Copyright (C) 2004 Mike Fisher
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

package genConfig::SNMP;

use Common::Log;
use genConfig::snmpUtils;

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
use Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(register_oids snmp_def get gettable);

my ($gInstallRoot);
BEGIN {
    $gInstallRoot = (($0 =~ m:^(.*/):)[0] || "./") . "..";
}

### Private stuff...

my %OIDs;
my $snmp;


###############################################################################
# register_oids - Register name/OID pairs for later use. This is a class 
#                 method.
###############################################################################

sub register_oids {
    shift if ($_[0] eq 'genConfig::SNMP');
    my(%oids) = @_;

    my $err = 0;

    foreach (keys %oids) {
	if (exists $OIDs{$_} && $OIDs{$_} ne $oids{$_}) {
	    Error("Attempt to redefine $_ = $OIDs{$_}");
	    $err = 1;
	} else {
	    $OIDs{$_} = $oids{$_};
	}
    }

    return(!$err);
}
	

###############################################################################
# snmp_def - Set the SNMP target node, community, and version (1 or 2c) as 
#            needed.  This is a class method.
###############################################################################

sub snmp_def {
    shift if ($_[0] eq 'genConfig::SNMP');
    my($node, $comm, $ver) = @_;
    
    if (!defined $node) {
	    ($node, $comm, $ver) = split(/@|:+/, $snmp);
	    return($node, $comm, $ver);
    } else {
	    $comm = 'public' if (!defined $comm);
	    $ver = ($ver eq '2c') ? ':::::2c' : '';
	    $snmp = "$comm\@$node$ver";
    }
}

###############################################################################
# get - Do an SNMP get of the specified OID.
###############################################################################

sub get {
    my($oid) = @_;
    my $name;
    my $suffix = "";
    ($name,$suffix) = split (/\./,$oid);
    $oid = $OIDs{$name} . "." . $suffix if ($suffix);
    $oid = $OIDs{$name}                 if (!$suffix);
    return genConfig::snmpUtils::get($snmp, $oid);
}

###############################################################################
# gettable - Walk an SNMP OID table and return it's values in an array suitable
#            for conversion to a hash.
###############################################################################

sub gettable {
    my($name) = @_;

    if (!defined $OIDs{$name}) {
	Error ("$name is undefined");
	return undef;
    }

    Info ("Walking $name... ");

    my (@data) = genConfig::snmpUtils::walk($snmp, $OIDs{$name});

    Info ("......................... " . scalar(@data));

    return(map({split(/:/,$_,2)}  @data));
}

###############################################################################

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 4
# perl-indent-level: 4
# End:
