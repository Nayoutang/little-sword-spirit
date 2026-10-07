param(
    [string]$Baseline = 'docs/experiments/combo-startup-diagnostic-2026-10-06.jsonl',
    [string]$Comparison = '.godot/combo-startup-diagnostic-h3.jsonl'
)
$ErrorActionPreference = 'Stop'
$old = @(Get-Content -LiteralPath $Baseline | ForEach-Object { $_ | ConvertFrom-Json })
$new = @(Get-Content -LiteralPath $Comparison | ForEach-Object { $_ | ConvertFrom-Json })
if ($old.Count -ne 120 -or $new.Count -ne 120) { throw 'Expected two complete 120-game batches' }
$paired = @{}
foreach ($game in $old) { $paired["$($game.winds)/$($game.version)/$($game.seed)"] = $game }
$summary = @($new | Group-Object winds,version | ForEach-Object {
    $games = @($_.Group)
    if ($games.Count -ne 20 -or @($games.seed | Sort-Object -Unique).Count -ne 20) { throw 'Invalid group coverage' }
    $previous = @($games | ForEach-Object { $paired["$($_.winds)/$($_.version)/$($_.seed)"] })
    $seen = @($games | Where-Object { $null -ne $_.cloud_first_seen_turn }).Count
    $activated = @($games | Where-Object { $null -ne $_.cloud_activation_turn }).Count
    $deltas = @($games | ForEach-Object {
        $before = $paired["$($_.winds)/$($_.version)/$($_.seed)"]
        [pscustomobject]@{
            RoundDelta = $_.rounds.Count - $before.rounds.Count
            HpDelta = $_.remaining_hp - $before.remaining_hp
            StartedNow = $null -ne $_.cloud_activation_turn -and $null -eq $before.cloud_activation_turn
            StoppedNow = $null -eq $_.cloud_activation_turn -and $null -ne $before.cloud_activation_turn
        }
    })
    $rounds = @($games | ForEach-Object { $_.rounds })
    $active = @($rounds | Where-Object cloud_active)
    [pscustomobject]@{
        Winds = $games[0].winds
        Version = $games[0].version
        Games = $games.Count
        OldActivated = @($previous | Where-Object { $null -ne $_.cloud_activation_turn }).Count
        NewActivated = $activated
        NewSeen = $seen
        NewConditionalActivation = if ($seen) { $activated / $seen } else { $null }
        NewlyStarted = @($deltas | Where-Object StartedNow).Count
        NewlyStopped = @($deltas | Where-Object StoppedNow).Count
        OldEligible = ($previous | Measure-Object eligible_rounds_denominator -Sum).Sum
        NewEligible = ($games | Measure-Object eligible_rounds_denominator -Sum).Sum
        OldRounds = @($previous | ForEach-Object { $_.rounds }).Count
        NewRounds = $rounds.Count
        MeanPairedRoundDelta = ($deltas | Measure-Object RoundDelta -Average).Average
        MeanPairedHpDelta = ($deltas | Measure-Object HpDelta -Average).Average
        NewJointAllRounds = @($rounds | Where-Object { $_.flowing_light -gt 0 -and $_.brilliance -gt 0 }).Count
        NewTriggers = ($rounds | Measure-Object cloud_triggers -Sum).Sum
        ActiveRoundTriggerRate = if ($active.Count) { @($active | Where-Object { $_.cloud_triggers -gt 0 }).Count / $active.Count } else { $null }
        NewCardsPerRound = if ($rounds.Count) { ($rounds | Measure-Object cards -Sum).Sum / $rounds.Count } else { $null }
        NewPlanningMeanMs = ($games | Measure-Object planning_ms -Average).Average
        Wins = @($games | Where-Object won).Count
        Truncated = @($games | Where-Object truncated).Count
    }
})
$summary | ConvertTo-Json -Depth 5
