#!/usr/bin/perl

#This program does loan calculations.
#It takes a "banking statement" (list of transactions) and outputs
#a banking statement of the same form, with interest amounts and loan
#amounts inserted.

#To calculate the interest earned in a tax year, use the -t option.

use warnings; use strict; use Data::Dumper;
use Time::Piece;
use Time::Seconds;
use POSIX;

my $compoundedEvery = 3;  #interest is compounded every 3 months (quarterly)

my $interestRate = 0;  #The interest rate on the loan
my $loan = 0;   #The amount of the loan up to the point we've processed

my $currentDate = localtime;

#Only care about the current day, not the time
$currentDate = Time::Piece->strptime($currentDate->dmy, "%d-%m-%Y");

my $taxYear = 0;  #Year for which to calculate the interest earned, for taxes

if (scalar(@ARGV) == 2)
{
    my ($thearg) = shift;

    if ($thearg eq "-y")
    {
        #Compound interest yearly instead of the default
        $compoundedEvery = 12;
    }
    elsif ($thearg =~ /([0-9A-Za-z-]*)/)
    {
        #Pretend the current date is something else (mainly for debugging)
        $currentDate = Time::Piece->strptime($1, "%d-%b-%Y");
    }
}
elsif (scalar(@ARGV) == 3)
{
    if ($ARGV[0] eq "-t")
    {
        shift;
        $taxYear = $ARGV[0] + 0;
        shift;
    }
    else
    {
        die "Usage: $0 FILENAME\n";
    }
}

my $filename = shift or die "Usage: $0 FILENAME\n";
open(DATA, "<" . $filename) or die "File not found.\n";

#Read interest rate from the top of the input
$_ = <DATA>;
if ($_ && /^InterestRate (.*)/)
{
    $interestRate = $1 + 0;
    print;
}
else
{
    die "Error: invalid interest rate at start\n";
}

#Convert from dollars in the input file to pennies for calculations
sub toPennies {
    my $amt = shift;
    return floor($amt * 100 + 0.5);
}

#Convert from pennies to dollars for printing
sub printMoney {
    my $amtInPennies = shift;
    return $amtInPennies / 100.0;
}

my $dateItr;  #Iterator in the below loop

#Read loan amount on the second line
$_ = <DATA>;
if($_ && /^([0-9.]*) (.*)/)
{
    #Amount of the loan on a particular date
    $loan = toPennies($1);
    $dateItr = Time::Piece->strptime($2, "%d-%b-%Y");
    print;
}
else
{
    die "Error: invalid second line\n";
}

my $targetDate = $dateItr;  #The date we have to process interest up until,
    #before moving to the next line of the input.

#The date we have to accumulate interest until, at which point we
#pay out (compound) the interest and reset it.
my $nextInterestPayment = $dateItr->add_months($compoundedEvery);

my $lineno = 2;  #Line number for error reporting
my $interest = 0;  #Interest accumulated
my $endOfInput = 0;  #Boolean value indicating whether we've reached the end of the input

my $paidBackRep = 0;
my $paidBackRepAmt = 0;

my $totalInterest = 0;

#Pay out interest when it's reached the compounding date
sub payoutInterest {
    $interest = floor($interest);  #Discard fractions of pennies

    if ($interest == 0)
    {
        return;
    }

    print "Interest " . printMoney($interest) . "\n";

    if ($dateItr->year == ($taxYear))
    {
        $totalInterest += $interest;
    }

    $loan += $interest;
    $interest = 0;
    print printMoney($loan) . " " . $dateItr->strftime("%d-%b-%Y") . "\n";
}

while ($dateItr < $currentDate)
{
    #These are the values for PaidBack lines
    my $paidBackAmt = 0;  #The amount paid back

    if ($paidBackRep != 0)
    {
        #Regular repayments - keep accumulating them
        $paidBackAmt = $paidBackRepAmt;
        if ($paidBackRep != -1)
        {
            --$paidBackRep;
        }
        $targetDate = $targetDate->add_months(1);
    }
    elsif (!$endOfInput and ($_ = <DATA>))
    {
        ++$lineno;

        if(/^([0-9.-]*) (.*)/)
        {
            #Amount of the loan on a particular date
            #Ignore these lines - we'll be outputting this ourself
            #They're here so that the bank statement can be re-input into the program again
        }
        elsif (/^Interest (.*)/)
        {
            #Interest lines - also ignored for the same reason
        }
        elsif(/^PaidBack ([0-9.-]*) (.*)/)
        {
            $targetDate = Time::Piece->strptime($2, "%d-%b-%Y");

            $paidBackAmt = $1;

            #Paid back amounts printed and handled below
        }
        elsif(/^PayBackRegular ([0-9.-]*) (\d*) ([0-9A-Za-z-]*)/)
        {
            #Pay back regular amounts for a set number of payments
            $paidBackRepAmt = $1;
            $paidBackRep = $2;
            $targetDate = Time::Piece->strptime($3, "%d-%b-%Y");
            $paidBackAmt = $paidBackRepAmt;
            --$paidBackRep;
        }
        elsif(/^PayBackRegular ([0-9.-]*) ([0-9A-Za-z-]*)/)
        {
            #Pay back regular amounts forever
            $paidBackRepAmt = $1;
            $paidBackRep = -1;
            $targetDate = Time::Piece->strptime($2, "%d-%b-%Y");
            $paidBackAmt = $paidBackRepAmt;
        }
        elsif ($_ eq "\n")
        {
            #Ignore blank lines
        }
        else
        {
            die "Error: invalid entry at line " . $lineno . "\n";
        }
    }
    else
    {
        #No more input - but keep processing and adding interest up to the current date.
        $endOfInput = 1;
        $targetDate = $currentDate;
    }

    #Keep increasing the date, calculating interest as you go
    while ($dateItr < $targetDate and $dateItr < $currentDate)
    {
        $dateItr += ONE_DAY;

        #Accumulate interest for one day
        if ($loan > 0)
        {
            $interest += $loan * ($interestRate / 100.0) / 365.25;
        }

        if ($dateItr == $nextInterestPayment)
        {
            payoutInterest;
            #Set the next point where interest is added
            $nextInterestPayment = $nextInterestPayment->add_months($compoundedEvery);
        }
    }

    if ($paidBackAmt != 0 and $targetDate <= $currentDate)
    {
        #An amount was paid back
        $loan -= toPennies($paidBackAmt);

        print "PaidBack " . $paidBackAmt . " " 
            . $targetDate->strftime("%d-%b-%Y") . "\n";

        #Print the current loan value
        print printMoney($loan) . " " . $dateItr->strftime("%d-%b-%Y") . "\n";
    }
}

#Put the regular payments at the end of the file if there are still some
if ($paidBackRep == -1)
{
    #$targetDate = $targetDate->add_months(1);
    print "PayBackRegular " . $paidBackRepAmt . " " 
        . $targetDate->strftime("%d-%b-%Y") . "\n";
}
elsif ($paidBackRep != 0)
{
    $paidBackRep = $paidBackRep + 1;
    print "PayBackRegular " . $paidBackRepAmt . " " . $paidBackRep . " " 
        . $targetDate->strftime("%d-%b-%Y") . "\n";
}

#Print the final amount, adding the fraction of interest that has accumulated since
#the last interest payout.
payoutInterest;

if ($taxYear > 0)
{
    print "Interest for year " . $taxYear . ": " . printMoney($totalInterest) . "\n";
}

#Print a newline at the end, to make the output text file nicer
print "\n";

