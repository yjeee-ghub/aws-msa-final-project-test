# Rebuild this project's deleted runtime from the local overnight manifest.
# Run only after verified shutdown; final scenario validation is a separate task.
[CmdletBinding()]
param([switch]$SkipMonitoringHistory)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Set-Location $root
$env:AWS_PAGER='';$env:AWS_DEFAULT_REGION='ap-northeast-2'
$folder=(Get-Content '.tools/overnight/latest.txt' -Raw).Trim()
$manifest=Get-Content "$folder/manifest.json" -Raw | ConvertFrom-Json
function AwsJson([string[]]$Arguments) {
  $raw=& aws @Arguments --region ap-northeast-2 --output json --no-cli-pager
  if($LASTEXITCODE -ne 0){throw "AWS command failed: $($Arguments[0..1] -join ' ')"}
  return ($raw -join "`n") | ConvertFrom-Json
}
function Run([string]$Program,[string[]]$Arguments) {
  & $Program @Arguments
  if($LASTEXITCODE -ne 0){throw "Command failed: $Program $($Arguments[0])"}
}
function PlanApply([string]$Directory,[string]$Name,[string[]]$Extra=@()) {
  $plan=Join-Path $folder "$Name.tfplan"
  & terraform "-chdir=$Directory" plan -input=false -no-color "-out=$plan" @Extra *> "$folder/$Name-plan.log"
  if($LASTEXITCODE -ne 0){Get-Content "$folder/$Name-plan.log" -Tail 25;throw "Plan failed: $Name"}
  $review=(& terraform "-chdir=$Directory" show -json $plan) | ConvertFrom-Json
  if($LASTEXITCODE -ne 0){throw 'Cannot inspect plan'}
  if($review.resource_changes | Where-Object {$_.mode -eq 'managed' -and $_.change.actions -contains 'delete'}) {
    throw "Unexpected deletion/replacement in $Name. Stop and inspect $Name-plan.log."
  }
  Write-Host "Applying $Name; progress log: $folder/$Name-apply.log"
  & terraform "-chdir=$Directory" apply -input=false -no-color $plan *> "$folder/$Name-apply.log"
  if($LASTEXITCODE -ne 0){Get-Content "$folder/$Name-apply.log" -Tail 30;throw "Apply failed: $Name"}
}
function SaveManifest { $manifest | ConvertTo-Json -Depth 14 | Set-Content "$folder/manifest.json" }
function SaveFlag([string]$Path,[string]$Key,[bool]$Enabled) {
  $text=Get-Content $Path -Raw
  $line="$Key = $($Enabled.ToString().ToLowerInvariant())"
  if($text -notmatch "(?m)^$Key\s*="){throw "Missing local flag: $Key"}
  $text=[regex]::Replace($text,"(?m)^$Key\s*=.*$",$line)
  [IO.File]::WriteAllText((Join-Path $root $Path),$text.Replace("`r`n","`n"))
}
function PutSecret($Stored,[string]$Namespace,[string]$Name) {
  $raw=[Net.NetworkCredential]::new('', $Stored).Password | ConvertFrom-Json
  @{apiVersion='v1';kind='Secret';metadata=@{name=$Name;namespace=$Namespace};type='Opaque';data=$raw.data} |
    ConvertTo-Json -Depth 12 -Compress | kubectl apply --server-side --field-manager=project-restore --force-conflicts -f -
  if($LASTEXITCODE -ne 0){throw "Cannot restore secret $Name"}
  $raw=$null
}
if((AwsJson @('sts','get-caller-identity')).Account -ne '193644343848'){throw 'Wrong AWS account'}
if($manifest.status -notin @('infra-removed','shutdown-verified','resuming','running')){throw 'Shutdown did not finish; inspect manifest first'}
if($manifest.status -eq 'running'){throw 'Already rebuilt. Use validation commands instead of starting another rebuild.'}
$snapshot=(AwsJson @('rds','describe-db-snapshots','--db-snapshot-identifier',$manifest.dbSnapshot)).DBSnapshots[0]
if($snapshot.Status -ne 'available'){throw 'DB snapshot is not available'}
if($snapshot.DBInstanceIdentifier -ne 'final-ordermsa-db'){throw 'Wrong DB snapshot source'}
$saved=Import-Clixml "$folder/protected-backup.clixml"
$app=[Net.NetworkCredential]::new('', $saved['soldesk/my-app-secrets']).Password | ConvertFrom-Json
foreach($pair in @(@('JWT_SECRET','TF_VAR_jwt_secret'),@('JWT_REFRESH_SECRET','TF_VAR_jwt_refresh_secret'),@('INTERNAL_SERVICE_TOKEN','TF_VAR_internal_service_token'))) {
  [Environment]::SetEnvironmentVariable($pair[1],[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($app.data.($pair[0]))),'Process')
}
$app=$null
try {
  # Keep snapshot_identifier in ignored local tfvars after restoration to avoid a later replacement.
  $vars=Get-Content 'terraform/terraform.tfvars' -Raw
  $line='db_snapshot_identifier = "'+$manifest.dbSnapshot+'"'
  if($vars -match '(?m)^db_snapshot_identifier\s*=.*$'){$vars=[regex]::Replace($vars,'(?m)^db_snapshot_identifier\s*=.*$',$line)}else{$vars+="`n$line`n"}
  $ip=(Invoke-RestMethod 'https://checkip.amazonaws.com').Trim()
  $parsed=$null
  if(-not [Net.IPAddress]::TryParse($ip,[ref]$parsed) -or $parsed.AddressFamily -ne 'InterNetwork'){throw 'Cannot verify public IPv4'}
  $vars=[regex]::Replace($vars,'(?m)^eks_public_access_cidrs\s*=.*$',('eks_public_access_cidrs = ["'+$ip+'/32"]'))
  [IO.File]::WriteAllText((Join-Path $root 'terraform/terraform.tfvars'),$vars.Replace("`r`n","`n"))
  $kubeVars=Get-Content 'terraform-k8s/terraform.tfvars' -Raw
  $claimLine=if($SkipMonitoringHistory){'grafana_existing_claim = null'}else{'grafana_existing_claim = "monitoring-grafana"'}
  if($kubeVars -match '(?m)^grafana_existing_claim\s*=.*$'){$kubeVars=[regex]::Replace($kubeVars,'(?m)^grafana_existing_claim\s*=.*$',$claimLine)}else{$kubeVars+="`n$claimLine`n"}
  [IO.File]::WriteAllText((Join-Path $root 'terraform-k8s/terraform.tfvars'),$kubeVars.Replace("`r`n","`n"))
  $manifest.status='resuming';SaveManifest
  Run terraform @('-chdir=terraform','init','-input=false')
  Run terraform @('-chdir=terraform','validate')
  PlanApply terraform restart-infra @('-var=enable_website_dns=false','-var=enable_management_dns=false')
  Run aws @('eks','update-kubeconfig','--name','Final-eks','--region','ap-northeast-2')
  Run kubectl @('wait','node','--all','--for=condition=Ready','--timeout=600s')
  Run terraform @('-chdir=terraform-k8s','init','-input=false')
  Run terraform @('-chdir=terraform-k8s','validate')
  if(-not $SkipMonitoringHistory) {
    # Namespace and StorageClass must exist before pre-binding restored EBS PVCs.
    PlanApply terraform-k8s restart-storage @('-target=kubernetes_namespace_v1.monitoring','-target=kubernetes_storage_class_v1.gp3','-var=enable_app_sync=false','-var=enable_management_ingress=false')
    if(-not $manifest.PSObject.Properties['restoredMonitoringVolumes']) {
      $manifest | Add-Member -NotePropertyName restoredMonitoringVolumes -NotePropertyValue @()
    }
    $index=0
    foreach($item in $manifest.monitoringSnapshots) {
      $index++
      $pvName="overnight-$($manifest.dbSnapshot.Replace('final-overnight-',''))-$index"
      $existing=kubectl get pv $pvName --ignore-not-found -o name
      if($LASTEXITCODE -ne 0){throw 'PV lookup failed'}
      if($existing){continue}
      $record=$manifest.restoredMonitoringVolumes | Where-Object {$_.claim -eq $item.claim}
      if(-not $record) {
        Run aws @('ec2','wait','snapshot-completed','--region','ap-northeast-2','--snapshot-ids',$item.snapshot)
        $az=if($item.claim.StartsWith('alertmanager-')){'ap-northeast-2a'}else{'ap-northeast-2c'}
        $volume=AwsJson @('ec2','create-volume','--snapshot-id',$item.snapshot,'--availability-zone',$az,'--volume-type','gp3','--tag-specifications',"ResourceType=volume,Tags=[{Key=Project,Value=Final},{Key=ebs.csi.aws.com/cluster,Value=true},{Key=Purpose,Value=MonitoringRestore}]")
        $record=@{claim=$item.claim;volume=$volume.VolumeId;az=$az;pv=$pvName}
        $manifest.restoredMonitoringVolumes=@($manifest.restoredMonitoringVolumes)+@($record);SaveManifest
      }
      Run aws @('ec2','wait','volume-available','--region','ap-northeast-2','--volume-ids',$record.volume)
      $affinity=@{required=@{nodeSelectorTerms=@(@{matchExpressions=@(@{key='topology.kubernetes.io/zone';operator='In';values=@($record.az)})})}}
      $pv=@{apiVersion='v1';kind='PersistentVolume';metadata=@{name=$pvName};spec=@{capacity=@{storage="$($item.sizeGiB)Gi"};accessModes=@('ReadWriteOnce');volumeMode='Filesystem';persistentVolumeReclaimPolicy='Delete';storageClassName='final-gp3';claimRef=@{namespace='monitoring';name=$item.claim};csi=@{driver='ebs.csi.aws.com';volumeHandle=$record.volume;fsType='ext4'};nodeAffinity=$affinity}}
      $pvc=@{apiVersion='v1';kind='PersistentVolumeClaim';metadata=@{name=$item.claim;namespace='monitoring';labels=@{'app.kubernetes.io/managed-by'='Helm'};annotations=@{'meta.helm.sh/release-name'='monitoring';'meta.helm.sh/release-namespace'='monitoring'}};spec=@{accessModes=@('ReadWriteOnce');storageClassName='final-gp3';volumeName=$pvName;resources=@{requests=@{storage="$($item.sizeGiB)Gi"}}}}
      foreach($obj in @($pv,$pvc)){$obj | ConvertTo-Json -Depth 20 -Compress | kubectl apply -f -;if($LASTEXITCODE -ne 0){throw 'Restored volume binding failed'}}
    }
  }
  PlanApply terraform-k8s restart-tools @('-var=enable_app_sync=false','-var=enable_management_ingress=false')
  PutSecret $saved['soldesk/final-admin-config'] soldesk final-admin-config
  if(-not $SkipMonitoringHistory){
    # Grafana DB was restored, so restore the original matching login secret as well.
    PutSecret $saved['monitoring/monitoring-grafana'] monitoring monitoring-grafana
    Run kubectl @('rollout','restart','deployment/monitoring-grafana','-n','monitoring')
    Run kubectl @('rollout','status','deployment/monitoring-grafana','-n','monitoring','--timeout=300s')
  }
  Run kubectl @('wait','externalsecret/database-credentials','-n','soldesk','--for=condition=Ready','--timeout=300s')
  SaveFlag 'terraform-k8s/terraform.tfvars' enable_app_sync $true
  SaveFlag 'terraform-k8s/terraform.tfvars' enable_management_ingress $true
  PlanApply terraform-k8s restart-app @('-var=enable_app_sync=true','-var=enable_management_ingress=true')
  Run kubectl @('wait','application/final-apps','-n','argocd','--for=jsonpath={.status.health.status}=Healthy','--timeout=600s')
  for($attempt=0;$attempt -lt 60;$attempt++) {
    $lbs=(AwsJson @('elbv2','describe-load-balancers')).LoadBalancers | Where-Object {$_.LoadBalancerName -eq 'final-shared-alb'}
    if($lbs -and $lbs.State.Code -eq 'active'){break}
    if($attempt -eq 59){throw 'Shared ALB did not become active'}
    Start-Sleep -Seconds 10
  }
  PlanApply terraform restart-dns @('-var=enable_website_dns=true','-var=enable_management_dns=true')
  SaveFlag 'terraform/terraform.tfvars' enable_website_dns $true
  SaveFlag 'terraform/terraform.tfvars' enable_management_dns $true
  Run kubectl @('get','deployments','-n','soldesk')
  Run kubectl @('get','externalsecret','-n','soldesk')
  $response=Invoke-WebRequest 'https://server.aws-yjeee.com' -Method Get -TimeoutSec 30
  if($response.StatusCode -ne 200){throw 'Public website validation failed'}
  $manifest.status='running';SaveManifest
  Write-Host 'Rebuild finished: https://server.aws-yjeee.com / https://argocd.aws-yjeee.com / https://grafana.aws-yjeee.com'
  Write-Host 'Argo initial password is newly generated; retrieve it using the study note. No Git push or release approval bypass occurred.'
} finally {
  foreach($key in @('TF_VAR_jwt_secret','TF_VAR_jwt_refresh_secret','TF_VAR_internal_service_token')){[Environment]::SetEnvironmentVariable($key,$null,'Process')}
  $saved=$null
}
