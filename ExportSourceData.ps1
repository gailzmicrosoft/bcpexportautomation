#======================================================================================================================#
#                                                                                                                      #
#  Migratemaster Version 1.0, July 2020                                                                                #
#                                                                                                                      #
#  This utility was developed on a best effort basis by Azure Synapse CSE Team and Data SQL Ninja team,                #
#  to aid SQL Server to Azure Synapse Migration Practitioners.                                                         #
#  It is not an officially supported Microsoft application or tool.                                                    #
#                                                                                                                      #
#  The utility and any script outputs are provided on "AS IS" basis and                                                #
#  there are no warranties, express or implied, including, but not limited to implied warranties of merchantability    #
#  or fitness for a particular purpose.                                                                                #
#                                                                                                                      #                    
#  The utility is therefore not guaranteed to generate perfect code or output. The output needs carefully reviewed.    #
#                                                                                                                      #
#                                       USE AT YOUR OWN RISK.                                                          #
#                                                                                                                      #
#======================================================================================================================#
#
# =================================================================================================================================================
# Description:
#       USE this to BCP data out of SQL Server, APS, Azure Snapse DB 
#       Parameters driven configuration file is the input of this powershell scripts 
# =================================================================================================================================================
# =================================================================================================================================================
# 
# Authors: Andy Isley & Gaiye "Gail" Zhou
# Updated April 2020: Merged All Scripts into one file 
# Added BCP executable path to the configuration file. Organized table data into individual folders. Tested with local SQL Server 
# Tested with APS, ADW, and SQL Server 

Function GetPassword([SecureString] $securePassword) {
	$securePassword = Read-Host "Password" -AsSecureString
	$P = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
	return $P
}


function CreateReturn($Status, $errors, $RowsReturned) {
	$ReturnValues = @{ }
	
	$ReturnValues.add('Status', $Status)
	$ReturnValues.add('errors', $errors)
	$ReturnValues.add('RowsReturned', $RowsReturned)
	
	Return $ReturnValues
}

	  

Function ExportBCPData(
	$BcpLocation = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn",
	$Server = "aaaa",
	$Database = "PDWDemo",
	$Schema = "dbo",
	$Table = "CUSTOMER",
	$UseIntegratedSecurity = "0",
	$UserName = "username",
	$Password = "P@ss555w0rd",
	$RowDelimiter = "~~~",
	$ColumnDelimiter = "&^&^",
	$BatchSize = 10000,
	$UseCharDataType = "1",
	$DestLocation = "C:\temp\",
	$AutoCreateFileName = "0",
	$FileName = '',
	$FileExtention = ".csv",
	$UseQuery = "1",
	$Query = "select * from sys.table") { 

	$error.Clear()	

	$RowsReturned = 0	
	$Success = '0'
	$errors = ''
	Try {
		Set-Location $BcpLocation

		#Set the Argument for the BCP command
		$serverinfo = @{ }
	    
		#Set up the Table to BCP    
		If ($UseQuery -eq '0') {
			$serverinfo.add('Table', $Schema + "." + $Table)
			$Arguments = "$($serverinfo['Table'])" + ' ' + 'out'
		}
		Else {
			$serverinfo.add('Table', $Query)
			$Arguments = """$($serverinfo['Table'])""" + ' ' + 'queryout'
		}    
	    
		#Set the output file for BCP
		If ($AutoCreateFileName -eq '1') {
			$serverinfo.add('FileName', $DestLocation + $FileName + '_' + $(get-date -f yyyy_MMdd_HHmmss) + $FileExtention)
		} 
		Else {
			$serverinfo.add('FileName', $DestLocation + $FileName + $FileExtention)
		}

	    
		# Set the File name in the Arguments list
		$Arguments = $Arguments + ' ' + """$($serverinfo['FileName'])"""
	     
		$serverinfo.add('Server', $Server)
		$serverinfo.add('Database', $Database)
	    
		# Set the Server name in the Arguments list   
		$Arguments = $Arguments + ' -S ' , "$($serverinfo['Server'])"
	    
		# Set the Database name in the Arguments list   
		$Arguments = $Arguments + ' -d ' , "$($serverinfo['Database'])"
		$displayArgs = $Arguments
		
		# Set the Trusted or Username/Password in the Arguments list
		IF ($UseIntegratedSecurity -eq '1') {
			$Arguments = $Arguments + ' -T ' 
			$displayArgs = $Arguments 
		}
		Else {
			# Begin to make a diaplay line that hides the real user name and password
			$Arguments = $Arguments + ' -U ' , $UserName, ' -P ', $Password 
			$displayArgs = $Arguments + " -U YourUsername  -P YourPassword" 
		} 
	    
		# Set the data type in the Arguments list
		If ($UseCharDataType -eq '1') {
			# This option uses char as the storage type 
			$Arguments = $Arguments + ' -c ' 
			$displayArgs = $displayArgs + ' -c ' 
		}
		else {
			# This option uses nchar as the storage type 
			$Arguments = $Arguments + ' -w '
			$displayArgs = $displayArgs + ' -w '
		}
	    
		If ($RowDelimiter -ne '') {
			$Arguments = $Arguments + " -r `"$RowDelimiter`"" 
			$displayArgs = $displayArgs + " -r `"$RowDelimiter`"" 
		}
	    
		If ($ColumnDelimeter -ne '') {
			$Arguments = $Arguments + " -t `"$ColumnDelimiter`"" 
			$displayArgs = $displayArgs + " -t `"$ColumnDelimiter`"" 
		}

		#set the batchsize
		if ($BatchSize) {
			$Arguments = $Arguments + ' -b ' , $BatchSize
			$displayArgs = $displayArgs + ' -b ' , $BatchSize
		}
		$Arguments = $Arguments -replace "'", "''"
		$displayArgs = $displayArgs -replace "'", "''"

		#$Arguments = "cmd /c 'bcp $Arguments'"  
		$Arguments = "cmd /c 'bcp $Arguments -q '"  
		$displayArgs = "cmd /c 'bcp $displayArgs -q '"      
		

		#Display the command that does not have the real user name and password 
		#Write-Host "Command: $displayArgs"  -ForegroundColor Green
		
		try { 
			[String]$Results = Invoke-Expression -Command $Arguments
		}
		Catch [system.exception] { 
			" Unable to perform the BCP operations. Please check if the the location of BCP.exe file" 
		}
         	
		if ($error.Count -eq 0) {	
			If ($Results.StartsWith(" Starting copy...")) {
				$pattern = " \d{1,10} rows copied."
				if ($Results -match $pattern) {
					$str = $matches[0]
					$Rows = $str.split(' ')
					$RowsReturned = $Rows[1]
					$Success = '1'
					return CreateReturn -Status $Success -RowsReturned $RowsReturned -errors ''
				}				
			}		
			Else {
				$Success = '-1'
				$errors = $Results
				
				return CreateReturn -Status $Success -RowsReturned -1 -errors $errors
				
			}
		}
		else {
			$Success = '-1'
			$errors = $error[0]
			
			return CreateReturn -Status $Success -RowsReturned -1 -errors $errors
		}
		
		
	}
	
	Catch [system.exception] {
		$Success = '-1'
		$errors = $_.Exception.ToString()
		return CreateReturn -Status $Success -RowsReturned -1 -errors $errors
	}
	Finally {
		#return $ReturnValues	
	}	
}


########################################################################################
#
# Main Program Starts here
#
########################################################################################

$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent


$BCPDriverFilePath = Read-Host -prompt "Enter the Export Source Data Config File Path or press 'Enter' to accept the default [$($ScriptPath)]"
if ([string]::IsNullOrEmpty($BCPDriverFilePath)) {
	$BCPDriverFilePath = $ScriptPath
}


$defaultCfgFile = "sql_bcp.json"

$cfgFile = Read-Host -prompt "Enter the Config File Name or press 'Enter' to accept the default [$($defaultCfgFile)]"
if([string]::IsNullOrEmpty($cfgFile)) {
    $cfgFile = $defaultCfgFile
}
$CfgFileFullPath = join-path $ScriptPath  $cfgFile
if (!(test-path $CfgFileFullPath )) {
    Write-Host "Could not find Config File: $CfgFileFullPath " -ForegroundColor Red
    break 
}

$JsonConfig = Get-Content -Path $CfgFileFullPath | ConvertFrom-Json 

$Server = $JsonConfig.ServerName
$ServerType = $JsonConfig.ServerType
$UseIntegrated =  $JsonConfig.IntegratedSecurity
$BcpLocation = $JsonConfig.BcpLocation


$defaultBCPDriverFile = "ExportSourceDataConfig.csv"
$BCPDriverFile = Read-Host -prompt "Enter the BCP Export Driver File Name or press 'Enter' to accept the default [$($defaultBCPDriverFile)]"
if ([string]::IsNullOrEmpty($BCPDriverFile)) {
	$BCPDriverFile = $defaultBCPDriverFile
}
$BCPDriverFileFullPath = join-path $BCPDriverFilePath $BCPDriverFile

if (!(test-path $BCPDriverFileFullPath )) {
	Write-Host "Could not find BCP Driver File: $BCPDriverFileFullPath " -ForegroundColor Red
	break 
}

# Import CSV File 
$csvFile = Import-Csv $BCPDriverFileFullPath

if ($UseIntegrated.ToUpper() -ne "YES") {
	Write-Host "Need Login Information..." -ForegroundColor Yellow
	$UseIntegratedSecurity = "0" 
	$UserName = Read-Host -prompt "Enter the User Name to connect to the SQL Server"
  
	if ([string]::IsNullOrEmpty($UserName)) {
		Write-Host "A user name must be entered" -ForegroundColor Red
		break
	}
	$Password = GetPassword
	if ([string]::IsNullOrEmpty($Password)) {
		Write-Host "A password must be entered." -ForegroundColor Red
		break
	}
}
else {
	$UseIntegratedSecurity = "1" 
}

# Read CSV File & Execute BCP 
ForEach ($BCPcmd in $csvFile) {
	$Active = $BCPcmd.Active
	If ($Active -eq "1") {
		If ($ServerType.ToUpper() -eq "APS") {
			$Server = $Server + ",17001"
		}
		$Database = $BCPcmd.DatabaseName
		$Schema = $BCPcmd.SchemaName 
		$Table = $BCPcmd.TableName
		$UseQuery = $BCPcmd.UseQuery
		$Query = $BCPcmd.Query
		$RowDelimiter = $BCPcmd.RowDelimiter
		$ColumnDelimiter = $BCPcmd.ColumnDelimiter
		$BatchSize = $BCPcmd.BatchSize
		$UseCharDataType = $BCPcmd.UseCharDataType
		$AutoCreateFileName = $BCPcmd.AutoCreateFileName
		$DestLocation = $BCPcmd.DestLocation + $Schema + "_" + $Table + "\" # Each table data is exported to its own folder 
     
		$FileName = $BCPcmd.FileName
		$FileExtention = $BCPcmd.FileExtention 

      
		if (!(test-path $DestLocation)) {
			Write-Host "Output File Directory $DestLocation did not exist. Created now." -ForegroundColor Magenta
			New-item "$DestLocation" -ItemType Dir | Out-Null
		}
		else {
			# Remove old contents so that no appending will happen.  
			Write-Host "Previous (old) "$FileName$FileExtention" will be removed from " $DestLocation -ForegroundColor Yellow
			$filesToRemove = "*" + $FileExtention
			Remove-Item -Path $DestLocation -Force -Include $filesToRemove 
  
		}
      
		$expData = ExportBCPData -BcpLocation $BcpLocation -Server $Server -Database $Database -Schema $Schema -Table $Table -UseIntegratedSecurity $UseIntegratedSecurity -UserName $UserName -Password $Password -RowDelimiter $RowDelimiter -ColumnDelimiter $ColumnDelimiter -BatchSize $BatchSize -UseCharDataType $UseCharDataType -DestLocation $DestLocation -AutoCreateFileName $AutoCreateFileName  -FileName $FileName -FileExtention $FileExtention UseQuery $UseQuery -Query $Query 
      
		if ($expData.Get_Item("Status") -eq '-1') {
			# will break out on first error 
			Write-Host "Status: "  $expData.Get_Item("Status")  "Error: "  $expData.Get_Item("errors")  "Rows: "  $expData.Get_Item("RowsReturned")
			break
		}
      
	}

}


$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
Set-Location -Path $ScriptPath

