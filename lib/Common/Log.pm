# -*- perl -*-

# Cricket: a configuration, polling and data display wrapper for RRD files
#
#    Copyright (C) 1998 Jeff R. Allen and WebTV Networks, Inc.
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

package Common::Log;
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(Debug Warn Info Die Error LogMonitor isDebug);

$kLogDebug    = 9;
$kLogMonitor  = 8;
$kLogInfo     = 7;
$kLogWarn     = 5;
$kLogError    = 1;
$gCurLogLevel = $kLogWarn;

%kLogNameMap = (
                'debug' => $kLogDebug,
                'monitor' => $kLogMonitor,
                'info' => $kLogInfo,
                'warn' => $kLogWarn,
                'error' => $kLogError
                );
%kLogNameReverseMap = (
                $kLogDebug   => 'debug',
                $kLogMonitor => 'monitor',
                $kLogInfo    => 'info',
                $kLogWarn    => 'warn',
                $kLogError   => 'error'
                );

$kLogMinimal   = 1;
$kLogStandard  = 2;
$kLogExtended  = 3;
$gCurLogFormat = $kLogStandard;

%kLogFormatMap = (
                'minimal'     => $kLogMinimal,
                'standard'    => $kLogStandard,
                'extended'    => $kLogExtended
                );
sub Log {
    my($level, @msg) = @_;
    my($msg) = join('', @msg);

    return unless ($level <= $gCurLogLevel);

    my($severity) = ' ';
    $severity = '*' if (($level == $kLogWarn) || ($level == $kLogError));

    if ($gCurLogFormat == 2) {
        my($stuff) = timeStr(time()) . $severity;
        if(defined($main::th)) {
               print STDERR "[$stuff] ($main::th) $msg\n";
        } else {
               print STDERR "[$stuff] $msg\n";
        }
    } elsif ($gCurLogFormat == 3) {
        my($stuff) = timeStr(time()) . $severity;
        my($levelname) = ucfirst($kLogNameReverseMap{$level});
        printf STDERR ("[$stuff] %-5s $msg\n", $levelname);
    } else {
        my($levelname) = ucfirst($kLogNameReverseMap{$level});
        printf STDERR ("[%-5s%1s] $msg\n", $levelname, $severity);
    }
}

sub Die {
    Log($kLogError, @_);
    die("Exiting due to unrecoverable error.\n");
}

sub Error {
    Log($kLogError, @_);
}

sub Warn {
    Log($kLogWarn, @_);
}

sub Debug {
    Log($kLogDebug, @_);
}

sub Info {
    Log($kLogInfo, @_);
}

sub LogMonitor {
    Log($kLogMonitor, @_);
}

sub isDebug {
    return 1 if $gCurLogLevel >= $kLogDebug;
    return 0;
}

sub timeStr {
    my($t) = ($_[0] =~ /(\d*)/);
    my(@months) = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
                    "Aug", "Sep", "Oct", "Nov", "Dec");
    my($sec,$min,$hour,$mday,$mon,$year) = localtime($t);
    return sprintf("%02d-%s-%04d %02d:%02d:%02d", $mday, $months[$mon],
                   $year + 1900, $hour, $min, $sec);
}

sub setLevel {
    my($level) = @_;
    my($ilevel) = $gCurLogLevel;

    if (defined($kLogNameMap{lc($level)})) {
        $gCurLogLevel = $kLogNameMap{lc($level)};
        Common::Log::Info("Log level changed from ",
                           $kLogNameReverseMap{$ilevel}, " to $level.");
    } else {
        Common::Log::Warn("Log level name $level unknown. " .
                          "Defaulting to 'info'.");
        $gCurLogLevel = $kLogNameMap{lc('info')};
    }
}

sub setFormat {
    my($format) = @_;

    if (defined($kLogFormatMap{lc($format)})) {
        $gCurLogFormat = $kLogFormatMap{lc($format)};
    } else {
        Common::Log::Warn("Log format name $format unknown. " .
                          "Defaulting to 'standard'.");
        $gCurLogFormat = $kLogFormatMap{lc('standard')};
    }
}
1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 4
# perl-indent-level: 4
# End:
