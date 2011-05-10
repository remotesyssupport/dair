########### Euca2ools powershell wrapper ##############

if($env:EUCA_HOME){
$EUCA_HOME = $env:EUCA_HOME #Get-item -path env:EUCA_HOME
}else{
write-warning "EUCA_HOME variable is not set"
$EUCA_HOME = "C:\Users\Administrator\Documents\Euca2ools\euca2ools-windows"
}

write-output "EUCA_HOME is set to $EUCA_HOME"

$EUCA_RC="$EUCA_HOME\\eucarc"

[string]$ec2url=""
[string]$access_key=""
[string]$secret_key=""
[string]$walrusurl=""
[string]$ec2privatekey=""
[string]$ec2cert=""
[string]$eucalyptuscert=""
[string]$ec2userid=""
if(![System.IO.Directory]::Exists("$EUCA_HOME")){
throw "The directory '$EUCA_HOME' doesn't exist"
}
if(![System.IO.File]::Exists($EUCA_RC)){
throw "File '$EUCA_RC' doesn't exist"
}

#parse eucarc file and set environment variable properly
$rcfile = get-content "$EUCA_RC"
foreach ($line in $rcfile)
{
if($line.contains("EC2_URL="))
{
$ec2url = $line.Substring($line.IndexOf("EC2_URL=")+8);
}elseif($line.contains("EC2_ACCESS_KEY="))
{
$access_key = $line.Substring($line.IndexOf("EC2_ACCESS_KEY=")+15);
$access_key = $access_key.Replace("'","")
}elseif($line.contains("EC2_SECRET_KEY="))
{
$secret_key = $line.substring($line.IndexOf("EC2_SECRET_KEY=")+15);
$secret_key = $secret_key.Replace("'","")
}elseif($line.contains("S3_URL="))
{
$walrusurl=$line.substring($line.IndexOf("S3_URL=")+7);
}elseif($line.contains("EC2_CERT="))
{
$ec2cert=$line.substring($line.IndexOf("EC2_CERT=")+9);
$ec2cert=$ec2cert.replace("`${EUCA_KEY_DIR}/","$EUCA_HOME\");
}elseif($line.contains("EC2_PRIVATE_KEY=")){
$ec2privatekey=$line.substring($line.IndexOf("EC2_PRIVATE_KEY=")+16);
$ec2privatekey=$ec2privatekey.replace("`${EUCA_KEY_DIR}/","$EUCA_HOME\");
}elseif($line.contains("EUCALYPTUS_CERT="))
{
$eucalyptuscert=$line.substring($line.IndexOf("EUCALYPTUS_CERT=")+16);
$eucalyptuscert=$eucalyptuscert.replace("`${EUCA_KEY_DIR}/","$EUCA_HOME\");
}elseif($line.contains("EC2_USER_ID=")){
$ec2userid=$line.substring($line.IndexOf("EC2_USER_ID=")+12);
$ec2userid=$ec2userid.Replace("'","")
}
}
if($ec2url -eq ""){
write-output "URL: $ec2url"
throw "EC2_URL variable is not set"
}
if($access_key -eq ""){
throw "EC2_ACCESS_KEY variable is not set"
}
if($secret_key -eq ""){
throw "EC2_SECRET_KEY variable is not set"
}
if($walrusurl -eq ""){
throw "WALRUS_URL variable is not set"
}

Set-Item -path env:EC2_URL -value "$ec2url"
Set-Item -path env:EC2_ACCESS_KEY -value "$access_key"
Set-Item -path env:EC2_SECRET_KEY -value "$secret_key"
Set-Item -path env:WALRUS_URL -value "$walrusurl"

if($ec2cert -ne ""){
Set-Item -path env:EC2_CERT -value "$ec2cert";
}
if($ec2privatekey -ne ""){
Set-Item -path env:EC2_PRIVATE_KEY -value "$ec2privatekey";
}
if($eucalyptuscert -ne ""){
Set-Item -path env:EUCALYPTUS_CERT -value "$eucalyptuscert";
}
if($ec2userid -ne ""){
Set-Item -path env:EC2_USER_ID -value "$ec2userid";
}

#write-output "$env:EC2_URL"
#write-output "$env:EC2_ACCESS_KEY"
#write-output "$env:EC2_SECRET_KEY"
#write-output "$env:WALRUS_URL"

function euca-add-group{
python "$EUCA_HOME\bin\euca-add-group" $args
}

function euca-add-keypair{
python "$EUCA_HOME\bin\euca-add-keypair" $args
}

function euca-allocate-address{
python "$EUCA_HOME\bin\euca-allocate-address" $args
}

function euca-associate-address{
python "$EUCA_HOME\bin\euca-associate-address" $args
}

function euca-attach-volume{
python "$EUCA_HOME\bin\euca-attach-volume" $args
}

function euca-authorize{
write-output "$args"
python "$EUCA_HOME\bin\euca-authorize" $args
}

function euca-bundle-image{
python "$EUCA_HOME\bin\euca-bundle-image" $args
}

function euca-bundle-instance{
python "$EUCA_HOME\bin\euca-bundle-instance" $args
}

function euca-bundle-upload{
python "$EUCA_HOME\bin\euca-bundle-upload" $args
}

function euca-bundle-vol{
python "$EUCA_HOME\bin\euca-bundle-vol" $args
}

function euca-cancel-bundle-task{
python "$EUCA_HOME\bin\euca-cancel-bundle-task" $args
}

function euca-check-bucket{
python "$EUCA_HOME\bin\euca-check-bucket" $args
}

function euca-confirm-product-instance{
python "$EUCA_HOME\bin\euca-confirm-product-instance" $args
}

function euca-create-snapshot{
python "$EUCA_HOME\bin\euca-create-snapshot" $args
}

function euca-create-volume{
python "$EUCA_HOME\bin\euca-create-volume" $args
}

function euca-delete-bundle{
python "$EUCA_HOME\bin\euca-delete-bundle" $args
}

function euca-delete-group{
python "$EUCA_HOME\bin\euca-delete-group" $args
}

function euca-delete-keypair{
python "$EUCA_HOME\bin\euca-delete-keypair" $args
}

function euca-delete-snapshot{
python "$EUCA_HOME\bin\euca-delete-snapshot" $args
}

function euca-delete-volume{
python "$EUCA_HOME\bin\euca-delete-volume" $args
}

function euca-deregister{
python "$EUCA_HOME\bin\euca-deregister" $args
}

function euca-describe-addresses{
python "$EUCA_HOME\bin\euca-describe-addresses" $args
}

function euca-describe-availability-zones{
python "$EUCA_HOME\bin\euca-describe-availability-zones" $args
}

function euca-describe-bundle-tasks{
python "$EUCA_HOME\bin\euca-describe-bundle-tasks" $args
}

function euca-describe-groups{
python "$EUCA_HOME\bin\euca-describe-groups" $args
}

function euca-describe-image-attribute{
python "$EUCA_HOME\bin\euca-describe-image-attribute" $args
}

function euca-describe-images{
#write-output "PARAM: $args"
python "$EUCA_HOME\bin\euca-describe-images" $args
}

function euca-describe-instances{
python "$EUCA_HOME\bin\euca-describe-instances" $args
}

function euca-describe-keypairs{
python "$EUCA_HOME\bin\euca-describe-keypairs" $args
}

function euca-describe-regions{
python "$EUCA_HOME\bin\euca-describe-regions" $args
}

function euca-describe-snapshots{
python "$EUCA_HOME\bin\euca-describe-snapshots" $args
}

function euca-describe-volumes{
python "$EUCA_HOME\bin\euca-describe-volumes" $args
}

function euca-detach-volume{
python "$EUCA_HOME\bin\euca-detach-volume" $args
}

function euca-disassociate-address{
python "$EUCA_HOME\bin\euca-disassociate-address" $args
}

function euca-download-bundle{
python "$EUCA_HOME\bin\euca-download-bundle" $args
}

function euca-get-console-output{
python "$EUCA_HOME\bin\euca-get-console-output" $args
}

function euca-get-password{
python "$EUCA_HOME\bin\euca-get-password" $args
}

function euca-get-password-data{
python "$EUCA_HOME\bin\euca-get-password-data" $args
}

function euca-modify-image-attribute{
python "$EUCA_HOME\bin\euca-modify-image-attribute" $args
}

function euca-reboot-instances{
python "$EUCA_HOME\bin\euca-reboot-instances" $args
}

function euca-register{
python "$EUCA_HOME\bin\euca-register" $args
}

function euca-release-address{
python "$EUCA_HOME\bin\euca-release-address" $args
}

function euca-reset-image-attribute{
python "$EUCA_HOME\bin\euca-reset-image-attribute" $args
}

function euca-revoke{
python "$EUCA_HOME\bin\euca-revoke" $args
}

function euca-run-instances{
python "$EUCA_HOME\bin\euca-run-instances" $args
}

function euca-terminate-instances{
python "$EUCA_HOME\bin\euca-terminate-instances" $args
}

function euca-unbundle{
python "$EUCA_HOME\bin\euca-unbundle" $args
}

function euca-upload-bundle{
python "$EUCA_HOME\bin\euca-upload-bundle" $args
}

function euca-version{
python "$EUCA_HOME\bin\euca-version" $args
}
