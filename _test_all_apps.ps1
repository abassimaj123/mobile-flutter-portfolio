# Full screenshot test for all 22 apps - with screen kept on
# ARCHIVÉS 2026-05-19: RideProfit (22) + ParkSmart (23) retirés
$apps = @(
    @{label="01_MortgageUS";    pkg="com.mortgageus.calculator";       act="com.mortgageus.calculator/com.mortgageus.mortgage_us.MainActivity"},
    @{label="02_MortgageCA";    pkg="com.mortgageca.calculator";       act="com.mortgageca.calculator/.MainActivity"},
    @{label="03_MortgageUK";    pkg="com.mortgageuk.calculator";       act="com.mortgageuk.calculator/.MainActivity"},
    @{label="04_AutoLoan";      pkg="com.autoloan.us.calculator";      act="com.autoloan.us.calculator/com.autoloan.auto_loan.MainActivity"},
    @{label="05_LoanPayoff";    pkg="com.loanpayoff.us.calculator";    act="com.loanpayoff.us.calculator/.MainActivity"},
    @{label="06_Refinance";     pkg="com.refinance.us.calculator";     act="com.refinance.us.calculator/.MainActivity"},
    @{label="07_StudentLoan";   pkg="com.studentloan.us.calculator";   act="com.studentloan.us.calculator/.MainActivity"},
    @{label="08_Affordability"; pkg="com.affordability.us.calculator"; act="com.affordability.us.calculator/.MainActivity"},
    @{label="09_HELOC";         pkg="com.heloc.us.calculator";         act="com.heloc.us.calculator/.MainActivity"},
    @{label="10_CreditCard";    pkg="com.creditcard.us.calculator";    act="com.creditcard.us.calculator/.MainActivity"},
    @{label="11_RentBuy";       pkg="com.rentbuy.us.calculator";       act="com.rentbuy.us.calculator/.MainActivity"},
    @{label="12_ExtraPayment";  pkg="com.calqwise.mortgageextrapayment"; act="com.calqwise.mortgageextrapayment/.MainActivity"},
    @{label="13_PropertyROISuite"; pkg="com.calqwise.propertyroisuite"; act="com.calqwise.propertyroisuite/.MainActivity"},
    @{label="14_PropertyROI";   pkg="com.propertyroi.us.calculator";   act="com.propertyroi.us.calculator/.MainActivity"},
    @{label="15_RentalExpenses";pkg="com.rentalexpenses.us.calculator"; act="com.rentalexpenses.us.calculator/.MainActivity"},
    @{label="16_RentalROI";     pkg="com.rentalroi.us.calculator";     act="com.rentalroi.us.calculator/.MainActivity"},
    @{label="17_BRRRR";         pkg="com.brrrr.us.calculator";         act="com.brrrr.us.calculator/.MainActivity"},
    @{label="18_CapRate";       pkg="com.caprate.us.calculator";       act="com.caprate.us.calculator/.MainActivity"},
    @{label="19_HouseFlip";     pkg="com.houseflip.us.calculator";     act="com.houseflip.us.calculator/.MainActivity"},
    @{label="20_LandlordCashFlow"; pkg="com.landlord.cashflow.calculator"; act="com.landlord.cashflow.calculator/.MainActivity"},
    @{label="21_SalaryApp";     pkg="com.salary.us.calculator";        act="com.salary.us.calculator/.MainActivity"},
    # @{label="22_RideProfit"; pkg="com.rideprofit.app"; ...}  ← ARCHIVÉ 2026-05-19
    # @{label="23_ParkSmart";  pkg="com.parksmart.app";  ...}  ← ARCHIVÉ 2026-05-19
    @{label="22_TaxeCA";        pkg="com.taxeca.calculator";           act="com.taxeca.calculator/.MainActivity"}
)

$outDir = "D:\mob\_screenshots"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Keep screen on throughout
adb shell "settings put system screen_off_timeout 600000"
adb shell "input keyevent 224"
Start-Sleep -Seconds 1

$results = @()

foreach ($app in $apps) {
    $label = $app.label
    $pkg   = $app.pkg
    $act   = $app.act

    # Wake screen before each launch
    adb shell "input keyevent 224" 2>$null

    adb shell "am force-stop $pkg" 2>$null
    adb logcat -c 2>$null
    Start-Sleep -Milliseconds 800

    # Launch app
    adb shell "am start -n $act" 2>$null | Out-Null
    Start-Sleep -Seconds 5

    # Wake screen again in case it dimmed
    adb shell "input keyevent 224" 2>$null
    Start-Sleep -Milliseconds 500

    # Screenshot
    $remote = "/sdcard/sc_test.png"
    $local  = "$outDir\$label.png"
    adb shell "screencap -p $remote" 2>$null
    adb pull $remote $local 2>$null | Out-Null
    adb shell "rm $remote" 2>$null

    # Check crash
    $log = adb logcat -d 2>$null
    $fatal = ($log | Select-String "FATAL EXCEPTION|$pkg.*has died").Count
    $ferr  = ($log | Select-String "E/flutter").Count

    $exists = Test-Path $local
    $size = if ($exists) { (Get-Item $local).Length } else { 0 }

    if ($fatal -gt 0) {
        $status = "CRASH"
        $prefix = "[CRASH]"
    } elseif ($ferr -gt 3) {
        $status = "FERR($ferr)"
        $prefix = "[WARN] "
    } else {
        $status = "OK"
        $prefix = "[OK]   "
    }

    $kb = [math]::Round($size / 1024)
    $scStatus = if ($size -gt 100000) { "[IMG ${kb}KB]" } else { "[BLACK ${kb}KB]" }
    Write-Host "$prefix $scStatus $label"

    $results += [PSCustomObject]@{
        App    = $label
        Status = $status
        ImgKB  = $kb
    }

    adb shell "am force-stop $pkg" 2>$null
    Start-Sleep -Milliseconds 500
}

# Restore normal timeout
adb shell "settings put system screen_off_timeout 60000"

Write-Host ""
Write-Host "=== RESULTS ==="
$results | Format-Table -AutoSize

$pass = ($results | Where-Object { $_.Status -eq "OK" }).Count
$imgs = ($results | Where-Object { $_.ImgKB -gt 100 }).Count
Write-Host "SCORE: $pass/24 OK | $imgs/24 screenshots captured"
