<#

Get-FileFromWeb -URL https://tohpsr.blob.core.windows.net/public/SR-TESTY/pl-pl_windows_11_business_editions_version_24h2.wim -File e:\pl-pl_windows_11_business_editions_version_24h2.wim
https://tohpsr.blob.core.windows.net/public/SR-TESTY/en-us_windows_11_business_editions_version_24h2.wim
https://tohpsr.blob.core.windows.net/public/SR-TESTY/pl-pl_windows_11_business_editions_version_24h2.wim

#>

function Get-FileFromWeb {
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]$URL,
  
        # Parameter help description
        [Parameter(Mandatory)]
        [string]$File 
    )
    Begin {
        function Show-Progress {
            param (
                # Enter total value
                [Parameter(Mandatory)]
                [Single]$TotalValue,
        
                # Enter current value
                [Parameter(Mandatory)]
                [Single]$CurrentValue,
        
                # Enter custom progresstext
                [Parameter(Mandatory)]
                [string]$ProgressText,
        
                # Enter value suffix
                [Parameter()]
                [string]$ValueSuffix,
        
                # Enter bar lengh suffix
                [Parameter()]
                [int]$BarSize = 40,

                # show complete bar
                [Parameter()]
                [switch]$Complete
            )
            
            # calc %
            $percent = $CurrentValue / $TotalValue
            $percentComplete = $percent * 100
            if ($ValueSuffix) {
                $ValueSuffix = " $ValueSuffix" # add space in front
            }
            if ($psISE) {
                Write-Progress "$ProgressText $CurrentValue$ValueSuffix of $TotalValue$ValueSuffix" -id 0 -percentComplete $percentComplete            
            }
            else {
                # build progressbar with string function
                $curBarSize = $BarSize * $percent
                $progbar = ""
                $progbar = $progbar.PadRight($curBarSize,[char]9608)
                $progbar = $progbar.PadRight($BarSize,[char]9617)
        
                if (!$Complete.IsPresent) {
                    Write-Host -NoNewLine "`r$ProgressText $progbar [ $($CurrentValue.ToString("#.###").PadLeft($TotalValue.ToString("#.###").Length))$ValueSuffix / $($TotalValue.ToString("#.###"))$ValueSuffix ] $($percentComplete.ToString("##0.00").PadLeft(6)) % complete"
                }
                else {
                    Write-Host -NoNewLine "`r$ProgressText $progbar [ $($TotalValue.ToString("#.###").PadLeft($TotalValue.ToString("#.###").Length))$ValueSuffix / $($TotalValue.ToString("#.###"))$ValueSuffix ] $($percentComplete.ToString("##0.00").PadLeft(6)) % complete"                    
                }                
            }   
        }
    }
    Process {
        try {
            $storeEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
        
            # invoke request
            $request = [System.Net.HttpWebRequest]::Create($URL)
            $response = $request.GetResponse()
  
            if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) {
                throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$URL'."
            }
  
            if($File -match '^\.\\') {
                $File = Join-Path (Get-Location -PSProvider "FileSystem") ($File -Split '^\.')[1]
            }
            
            if($File -and !(Split-Path $File)) {
                $File = Join-Path (Get-Location -PSProvider "FileSystem") $File
            }

            if ($File) {
                $fileDirectory = $([System.IO.Path]::GetDirectoryName($File))
                if (!(Test-Path($fileDirectory))) {
                    [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null
                }
            }

            [long]$fullSize = $response.ContentLength
            $fullSizeMB = $fullSize / 1024 / 1024
  
            # define buffer
            [byte[]]$buffer = new-object byte[] 1048576
            [long]$total = [long]$count = 0
  
            # create reader / writer
            $reader = $response.GetResponseStream()
            $writer = new-object System.IO.FileStream $File, "Create"
  
            # start download
            $finalBarCount = 0 #show final bar only one time
            do {
          
                $count = $reader.Read($buffer, 0, $buffer.Length)
          
                $writer.Write($buffer, 0, $count)
              
                $total += $count
                $totalMB = $total / 1024 / 1024
          
                if ($fullSize -gt 0) {
                    Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText "Downloading $($File.Name)" -ValueSuffix "MB"
                }

                if ($total -eq $fullSize -and $count -eq 0 -and $finalBarCount -eq 0) {
                    Show-Progress -TotalValue $fullSizeMB -CurrentValue $totalMB -ProgressText "Downloading $($File.Name)" -ValueSuffix "MB" -Complete
                    $finalBarCount++
                    #Write-Host "$finalBarCount"
                }

            } while ($count -gt 0)
        }
  
        catch {
        
            $ExeptionMsg = $_.Exception.Message
            Write-Host "Download breaks with error : $ExeptionMsg"
        }
  
        finally {
            # cleanup
            if ($reader) { $reader.Close() }
            if ($writer) { $writer.Flush(); $writer.Close() }
        
            $ErrorActionPreference = $storeEAP
            [GC]::Collect()
        }    
    }
}

function Show-Menu()
{
    param (
        [string]$JSONversion = “0.0”,
        [string]$releaseDate = “0.0.0”
    )

    cls

    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $ComputeBios = Get-WmiObject win32_bios
    $BiosVersion = $computeBios.SMBIOSBIOSVersion
    $SerialNumber = $computeBios.SerialNumber

    $Computer = Get-WmiObject Win32_ComputerSystem
    $ComputerModel = $Computer.Model

    write-host "`nDate & Time: $timestamp" -ForegroundColor white

    write-host "`n  --> device details <--  " -ForegroundColor Green
    write-host "Model: $ComputerModel" -ForegroundColor white
    write-host "Bios: $BiosVersion" -ForegroundColor white
    write-host "Serial number: $SerialNumber" -ForegroundColor white

    write-host "`n  --> internet details <--  " -ForegroundColor Green
    $ping = test-connection -comp www.google.com -Quiet -Count 2

    if($ping){
        write-host "Internet connection: " -ForegroundColor White -NoNewline
        write-host " WORKS " -ForegroundColor Black -BackgroundColor Green

        $response = Invoke-WebRequest -Uri "https://ifconfig.co/json" -UseBasicParsing | Select-Object -Expand Content | ConvertFrom-Json
        write-host "External IP: $($response.ip)" -ForegroundColor white
        write-host "`n  --> location details <--  " -ForegroundColor Green
        write-host "City: $($response.city)" -ForegroundColor white
        write-host "Country: $($response.country)" -ForegroundColor white
    }else{
        write-host "Internet connection: " -ForegroundColor White -NoNewline
        write-host " DOESN'T WORK " -ForegroundColor Black -BackgroundColor Red
    }

    Write-Host -ForegroundColor Yellow “`n -> JSON version: $JSONversion”
    Write-Host -ForegroundColor Yellow “ -> release date: $releaseDate”
        
    Write-Host -ForegroundColor Green “`n===== Please select the OS to be installed =====`n”
}

######
##### spradzenie sieci dac tutaj/pozniej netu i dopiero jak bedzie OK, to pobierac JSON'a, sprawdzac HASH i podpis i dopiero po tym pokazywac menu!!!

[int]$tries = 2

do{
    cls

    Write-Host ".: OS reimaging tool :."
    Write-Host "`n -> prepared by tomasz.omelaniuk@hp.com`n"
    Write-Host "----------------------------------------------"
    Write-Host "remaining number of attempts: $($tries + 1)"
    Write-Host "----------------------------------------------`n"

    $input = Read-Host “Please enter the password”

    if($tries -eq 0){                  
        write-host "`nYou are not allowed to use this tool! Your PC will be rebooted in a while" -ForegroundColor White -BackgroundColor Red
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }else{
        $tries=$tries - 1
    }

}until ($input -eq ‘P@$$w0rd’)

write-host "`n -> Password OK...Let's start the show ;)" -ForegroundColor Green

do{
    $yesno = Read-Host “`nAre You sure You want to reinstall Your laptop? Choosing Y will erase Your hard drive (Y/N)”

    if($yesno -eq 'n’ -or $yesno -eq 'N'){                  
        write-host "`nYou have selected NO. Your PC will be rebooted in a while." -ForegroundColor White -BackgroundColor Red
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }

}until ($yesno -eq 'y’ -or $yesno -eq 'Y')

write-host "`n -> You have selected YES. Formating and preparing Your hard drive..." -ForegroundColor Green
diskpart.exe /s d:\diskpart_script.txt

write-host "`n"
pause

$url = "https://tohpsr.blob.core.windows.net/public/SR-TESTY/3Simages.json"
$jsonData = (New-Object System.Net.WebClient).DownloadString($url)
$dataABC5 = $jsonData | ConvertFrom-Json

#$dataABC5.OSimages
#$dataABC5.OSdetails

try{
    if(!([string]::IsNullOrEmpty($dataABC5.OSdetails.authCode))){
        $dataABC5.OSdetails.authCode
    }

    do{
        Show-Menu -JSONversion $dataABC5.OSdetails.JSONversion -releaseDate $dataABC5.OSdetails.releaseDate
        $x = 0
        foreach ($i in $dataABC5.OSimages)
        {
            Write-Host -ForegroundColor Green "Type: '$($x)' to install -> $($i.name) -> $($i.desc)"        
            $x++
        }
        Write-Host -ForegroundColor Green “`nQ: Press ‘Q’ to quit.`n”
        
        $input = Read-Host “Please make a selection”
        
        try{
            try{
                $getOS = [int]$input
                write-host "`nYour choice -> $($dataABC5.OSimages.Get($getOS).desc)`n"

                write-host "Your OS image URL -> $($dataABC5.OSimages.Get($getOS).url)"
                write-host "Your OS image HASH sha256 -> $($dataABC5.OSimages.Get($getOS).sha256)"
                write-host "Your OS digital signature URL -> $($dataABC5.OSimages.Get($getOS).SIGNurl)`n"

                #sprawdzanie dostepnosci URL z obrazem
                $OSdownloadurl = $dataABC5.OSimages.Get($getOS).url
                $OSdownloadPath = "w:\" + $OSdownloadurl.Substring($OSdownloadurl.LastIndexOf("/") + 1)
                $response = Invoke-WebRequest -Uri $OSdownloadurl -UseBasicParsing -Method Head
                if ($response.StatusCode -eq 200) {
                    #write-host -ForegroundColor Green " -> $OSdownloadurl is reachable."
                    write-host -ForegroundColor Green " -> URL with an OS image is reachable."
                    write-host "Downloading OS image from url -> $($OSdownloadurl)" -ForegroundColor White
                    Get-FileFromWeb -URL $OSdownloadurl -File $OSdownloadPath
                } else {
                    write-host -ForegroundColor Red " -> $url is not reachable."
                }

                write-host "`nChecking hash of downloaded OS image: " -ForegroundColor White -NoNewline
                $fileHash = (Get-FileHash $OSdownloadPath -a sha256).Hash
                
                if($fileHash -eq $dataABC5.OSimages.Get($getOS).sha256){                  
                    write-host " ALL IS GOOD `n" -ForegroundColor Black -BackgroundColor Green
                }else{
                    write-host " HASH DOESN'T MATCH ORIGINAL!!! `n" -ForegroundColor Black -BackgroundColor Red
                }

                #sprawdzanie dostepnosci URL z podpisem
                $SIGdownloadurl = $dataABC5.OSimages.Get($getOS).SIGNurl
                $SIGdownloadPath = "w:\" + $SIGdownloadurl.Substring($SIGdownloadurl.LastIndexOf("/") + 1)
                $response = Invoke-WebRequest -Uri $SIGdownloadurl -UseBasicParsing -Method Head
                if ($response.StatusCode -eq 200) {
                    write-host -ForegroundColor Green " -> $SIGdownloadurl is reachable."                    
                    write-host "Downloading digital signature of an OS image from url -> $($SIGdownloadurl)" -ForegroundColor White
                    Get-FileFromWeb -URL $SIGdownloadurl -File $SIGdownloadPath
                } else {
                    write-host -ForegroundColor Red " -> $SIGdownloadurl is not reachable."
                }

                write-host "`nChecking/verifying digital signature of an OS image: " -ForegroundColor White -NoNewline
                $digitalSignature = D:\OpenSSL-Win64\bin\openssl.exe dgst -sha256 -verify D:\OPENSSL_public.pem -signature $SIGdownloadPath $OSdownloadPath
                
                if($digitalSignature -eq "Verified OK"){                  
                    write-host " ALL IS GOOD `n" -ForegroundColor Black -BackgroundColor Green

                    write-host " -> loading OS image onto Your PC" -ForegroundColor White
                    dism /Apply-Image /ImageFile:$OSdownloadPath /Index:1 /ApplyDir:W:\
                    write-host " -> configuring OS booting" -ForegroundColor White
                    bcdboot W:\Windows
                }else{
                    write-host " OS IMAGE IS COMPROMISED!!! `n" -ForegroundColor Black -BackgroundColor Red
                }
                
                pause
             }catch{
                write-host -ForegroundColor Red "`nERROR: Your selection - $($input) - is not available on the list!!!`n"
                pause
            }

        }catch{
            write-host -ForegroundColor Red "`nERROR: Your selection - $($input) - wasn't a number!!!`n"
            pause
        }
    }until ($input -eq ‘q’)

    #sprawdzanie przede wszystkim SIECI!!!
    
    #sprawdzanie poprawnosci i dostepnosci pliku JSON
    #!!!! PODPISAC CYFROWO PLIK JSON plus zapisywac tez moze i sparwdzac HASH pliku? ale to musi byc w oddzielnym pliku bo pozniej podpis cyfrowy i jego weryfikacja nie bedzie przechodzic zreszta ciezko bedzie dodac hash do pliku dla ktorego hash obliczam, musi byc inny
    
    ### mozna dodac powiadomienie na komorke ze komp jest reinstalowany!!!! poprzez wyslanie zapytania post/get do netu!!! info - model kompa + SerialNumber
    
    
    #pobieranie obrazu na dysk C
    
    #sprawdzanie HASHa sha256 pobranego obrazu
    #sprawdzanie podpisu cyfrowego pliku certyfikatem publicznym ktory bylby w customowym agencie tj WinPE
    
    
    #weryfikacja
    #.\openssl base64 -d -in e:\pl-pl_windows_11_business_editions_version_24h2.wim.sig.txt -out e:\pl-pl_windows_11.sha256
    #.\openssl dgst -sha256 -verify e:\OPENSSL_public.pem -signature e:\pl-pl_windows_11.sha256 e:\pl-pl_windows_11_business_editions_version_24h2.wim
    # ALBO -> Verification Failure
    # ALBO -> Verified OK

    
    #jesli weryfikacja OK -> DISM i wrzucanie obrazu na dysk C
    #poprawienie EFI / bootowanie
    #pobranie driver packa dla danej platformy/lapka
    #wstrzykniecie sterownikow do obrazu
    #podsumowanie i restart po ENTERze


}catch{
    #Write-Output -foreground red "ERROR"
    #Write-Host -Foreground Red -Background Black
    $_
}

#$dataABC5.OSimages.Length
