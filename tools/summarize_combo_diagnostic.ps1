param([string]$InputPath = '.godot/combo-startup-diagnostic.jsonl')
$ErrorActionPreference = 'Stop'
$records = @(Get-Content -LiteralPath $InputPath | ForEach-Object { $_ | ConvertFrom-Json })
function Get-Percentile([double[]]$Values, [double]$Probability) {
    if ($Values.Count -eq 0) { return $null }
    $ordered = @($Values | Sort-Object)
    return $ordered[[Math]::Min($ordered.Count - 1, [Math]::Floor(($ordered.Count - 1) * $Probability))]
}
$summary = @($records | Group-Object winds,version | ForEach-Object {
    $games = @($_.Group)
    $seen = @($games | Where-Object { $null -ne $_.cloud_first_seen_turn })
    $started = @($games | Where-Object { $null -ne $_.cloud_activation_turn })
    $allRounds = @($games | ForEach-Object { $_.rounds })
    $joint = @($allRounds | Where-Object { $_.flowing_light -gt 0 -and $_.brilliance -gt 0 }).Count
    $eligible = @($games | ForEach-Object { [double]$_.eligible_rounds_denominator })
    $planning = @($games | ForEach-Object { [double]$_.planning_ms })
    [pscustomobject]@{
        Winds = $games[0].winds
        Version = $games[0].version
        Games = $games.Count
        Seen = $seen.Count
        Activated = $started.Count
        ConditionalActivation = if ($seen.Count) { $started.Count / $seen.Count } else { $null }
        ActivationTurns = @($started | ForEach-Object { $_.cloud_activation_turn })
        EligibleTotal = ($eligible | Measure-Object -Sum).Sum
        EligiblePerGameP50 = Get-Percentile $eligible 0.5
        EligiblePerGameP90 = Get-Percentile $eligible 0.9
        AllRounds = $allRounds.Count
        JointSkills = $joint
        AllRoundJointRate = if ($allRounds.Count) { $joint / $allRounds.Count } else { $null }
        PlanningMeanMs = ($planning | Measure-Object -Average).Average
        PlanningP50Ms = Get-Percentile $planning 0.5
        PlanningP90Ms = Get-Percentile $planning 0.9
        PlanningMaxMs = ($planning | Measure-Object -Maximum).Maximum
        MaxCallMs = ($games | Measure-Object max_call_ms -Maximum).Maximum
        Wins = @($games | Where-Object won).Count
        Truncated = @($games | Where-Object truncated).Count
    }
})
$summary | ConvertTo-Json -Depth 5
