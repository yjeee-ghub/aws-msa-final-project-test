# One protected-main deployment check inside the VPC; no host socket or AWS key.
[CmdletBinding()]
param([string]$Repository='yjeee-ghub/aws-msa-final-project-test',[string]$Namespace='deploy-check-runners',[string]$RunnerVersion='2.338.0')
$ErrorActionPreference='Stop'
if ($Namespace -ne 'deploy-check-runners') { throw 'Use the isolated deployment-check namespace.' }
$taskCli=Get-Command gh -ErrorAction SilentlyContinue
$taskGh=if ($taskCli) { $taskCli.Source } else { Join-Path $PSScriptRoot '../../.tools/github-cli/bin/gh.exe' }
$taskRegistration=& $taskGh api --method POST "repos/$Repository/actions/runners/registration-token" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $taskRegistration.token) { throw 'Runner registration failed.' }
$taskName='deploy-check-'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
@{apiVersion='v1';kind='Namespace';metadata=@{name=$Namespace}} | ConvertTo-Json -Depth 8 -Compress | kubectl apply -f -
if ($LASTEXITCODE -ne 0) { throw 'Namespace failed.' }
$taskSecret=@{apiVersion='v1';kind='Secret';metadata=@{name=$taskName;namespace=$Namespace};type='Opaque';data=@{token=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($taskRegistration.token))}}
$taskSecret | ConvertTo-Json -Depth 8 -Compress | kubectl apply -f -
if ($LASTEXITCODE -ne 0) { throw 'Registration Secret failed.' }
$taskRegistration=$null;$taskSecret=$null
$taskCommand=@'
set -euo pipefail
cd /home/runner
./config.sh --url "https://github.com/$RUNNER_REPOSITORY" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --labels deploy-check --unattended --ephemeral --disableupdate --work _work
unset RUNNER_TOKEN
exec ./run.sh
'@
$taskPod=@{apiVersion='v1';kind='Pod';metadata=@{name=$taskName;namespace=$Namespace;labels=@{app='deploy-check-runner'}};spec=@{
    restartPolicy='Never';automountServiceAccountToken=$false
    securityContext=@{runAsNonRoot=$true;runAsUser=1001;fsGroup=1001;seccompProfile=@{type='RuntimeDefault'}}
    containers=@(@{name='runner';image="ghcr.io/actions/actions-runner:$RunnerVersion";imagePullPolicy='IfNotPresent';command=@('/bin/bash','-c');args=@($taskCommand)
        securityContext=@{allowPrivilegeEscalation=$false;capabilities=@{drop=@('ALL')}}
        resources=@{requests=@{cpu='100m';memory='256Mi'};limits=@{cpu='1';memory='1Gi'}}
        env=@(@{name='RUNNER_REPOSITORY';value=$Repository},@{name='RUNNER_NAME';value=$taskName},@{name='RUNNER_TOKEN';valueFrom=@{secretKeyRef=@{name=$taskName;key='token'}}},@{name='AGENT_TOOLSDIRECTORY';value='/home/runner/_work/_tool'},@{name='RUNNER_TOOL_CACHE';value='/home/runner/_work/_tool'})
    })
}}
$taskPod | ConvertTo-Json -Depth 18 -Compress | kubectl apply -f -
if ($LASTEXITCODE -ne 0) { throw 'Runner Pod failed.' }
Write-Output "Ephemeral runner: $Namespace/$taskName. One job only; delete completed Pod and matching registration Secret afterwards."
