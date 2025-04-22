$grcServers = @(
	# "s-azp21.grc.local.unreachable",
	"s-azp21.grc.local",
	"s-azfile.grc.local",
	"s-azsql.grc.local",
	"s-azapp.grc.local"
)

$interval = 10
$pingCount = 1
$file = "~\grc_ping.txt"
# overwrite file to ensure a clean file to start
# out-file -filepath $file
# Write-Host "Writing to '$file'"
while (1) {
    $results = @()
    # get-date | tee-object -FilePath $file -Append
    get-date
    foreach ($grcServer in $grcServers) {
        # ping -n $pingCount $grcServer | tee-object $file -Append
        # ping -n $pingCount $grcServer
        Test-Connection -Count $pingCount $grcServer
        # test-netconnection $grcServer | tee-object $file -Append
        # $result = [PSCustomObject]@{
        #     Server    = $grcServer
        #     Reachable = Test-Connection -Quiet $grcServer
        # }
        # $results += $result
    }
    # Write-Output $results | Format-Table 
    Start-Sleep $interval
}
