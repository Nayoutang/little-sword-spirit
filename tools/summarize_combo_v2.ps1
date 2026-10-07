param([string]$InputPath = '.godot/combo-v2-diagnostic.jsonl', [int]$ExpectedPerGroup = 20)
$ErrorActionPreference = 'Stop'
$records = @(Get-Content -LiteralPath $InputPath | ForEach-Object { $_ | ConvertFrom-Json })
if ($records.Count -ne 6 * $ExpectedPerGroup) { throw 'Incomplete six-group diagnostic' }
foreach ($game in $records) {
    $firstFive = ($game.damage_records | Where-Object turn -le 5 | Measure-Object damage -Sum).Sum
    if ($firstFive -ne $game.first_five_damage) { throw 'First-five damage accounting mismatch' }
    if ($null -ne $game.cloud_activation_turn) {
        $endTurn = $game.cloud_activation_turn + $game.post_start_rounds
        $postDamage = ($game.damage_records | Where-Object { $_.post_start -and $_.turn -lt $endTurn } | Measure-Object damage -Sum).Sum
        if ($postDamage -ne $game.post_start_damage -or $game.cloud_activation_turn -ne $game.checkpoint.turn) { throw 'Checkpoint-window accounting mismatch' }
    }
    if (($game.rounds | Measure-Object cloud_triggers -Sum).Sum -ne @($game.trigger_records).Count) { throw 'Trigger accounting mismatch' }
    foreach ($trigger in $game.trigger_records) {
        $after = $null
        for ($i = 0; $i -lt $game.observed_hands.Count - 1; $i++) {
            $beforeState = $game.observed_hands[$i]
            $afterState = $game.observed_hands[$i + 1]
            if ($beforeState.turn -eq $trigger.turn - 1 -and $afterState.turn -eq $beforeState.turn -and -not $beforeState.triggered -and $afterState.triggered) {
                $after = $afterState
                break
            }
        }
        if ($null -eq $after) { throw 'Missing post-trigger visible state' }
        foreach ($drawn in $trigger.drawn) {
            $playable = $drawn.affordable -and $drawn.id -ne 7 -and -not ($drawn.id -eq 8 -and $after.tuned) -and -not ($drawn.id -eq 15 -and $after.cloud)
            $drawn | Add-Member -NotePropertyName playable -NotePropertyValue $playable -Force
        }
    }
}
function Percentile([double[]]$Values, [double]$P) {
    if (-not $Values.Count) { return $null }
    $sorted = @($Values | Sort-Object)
    $sorted[[Math]::Floor(($sorted.Count - 1) * $P)]
}
$groups = @($records | Group-Object winds,version | ForEach-Object {
    $games = @($_.Group)
    if ($games.Count -ne $ExpectedPerGroup -or @($games.seed | Sort-Object -Unique).Count -ne $ExpectedPerGroup) { throw 'Invalid seed coverage' }
    $started = @($games | Where-Object { $null -ne $_.cloud_activation_turn })
    $health = @($games | ForEach-Object { [double]$_.remaining_hp })
    $lengths = @($games | ForEach-Object { [double]$_.rounds.Count })
    $rounds = @($games | ForEach-Object { $_.rounds })
    $triggers = @($games | ForEach-Object { $_.trigger_records })
    $draws = @($triggers | ForEach-Object { $_.drawn })
    $sequences = @($games | ForEach-Object {
        $game = $_
        $attacks = @($game.damage_records | Where-Object { ($game.version -eq 'no_cloud' -or $_.post_start) -and $_.id -in 0,3,5,6,13,14,16 })
        $attacks | Group-Object turn | Where-Object Count -ge 3 | ForEach-Object {
            [pscustomobject]@{ Pattern = ($_.Group.id -join ','); Seed = $game.seed }
        }
    })
    $patterns = @($sequences | Group-Object Pattern | Sort-Object Count -Descending)
    $dominant = if ($patterns.Count) { $patterns[0] } else { $null }
    $fraction = if ($sequences.Count) { $dominant.Count / $sequences.Count } else { 0 }
    $dominantSeeds = if ($null -ne $dominant) { @($dominant.Group.Seed | Sort-Object -Unique).Count } else { 0 }
    [pscustomobject]@{
        Winds = $games[0].winds; Version = $games[0].version; Games = $games.Count
        Wins = @($games | Where-Object won).Count; Deaths = @($games | Where-Object { -not $_.won -and -not $_.truncated }).Count
        Truncated = @($games | Where-Object truncated).Count
        Started = $started.Count; ActivationTurns = @($started | ForEach-Object { $_.cloud_activation_turn })
        MeanRounds = ($lengths | Measure-Object -Average).Average; MedianRounds = Percentile $lengths 0.5
        HpMin = ($health | Measure-Object -Minimum).Minimum; HpP25 = Percentile $health 0.25
        HpP50 = Percentile $health 0.5; HpP75 = Percentile $health 0.75
        MeanFirstFiveDamage = ($games | Measure-Object first_five_damage -Average).Average
        MeanPostStartDamage = if ($started.Count) { ($started | Measure-Object post_start_damage -Average).Average } else { $null }
        EarlyWins = @($games | Where-Object { $_.won -and $_.rounds.Count -le 5 }).Count
        PostWindowSaturated = @($started | Where-Object { $_.post_start_damage -eq ($_.checkpoint.enemy_hp | Measure-Object -Sum).Sum }).Count
        JointRounds = @($rounds | Where-Object { $_.flowing_light -gt 0 -and $_.brilliance -gt 0 }).Count
        ActiveRounds = @($rounds | Where-Object cloud_active).Count
        CloudTriggers = ($rounds | Measure-Object cloud_triggers -Sum).Sum
        ZeroEnergyTriggers = @($triggers | Where-Object energy_before_refund -eq 0).Count
        AffordableDraws = @($draws | Where-Object affordable).Count
        LegallyPlayableDraws = @($draws | Where-Object playable).Count
        Draws = $draws.Count
        PlanningMeanMs = ($games | Measure-Object planning_ms -Average).Average
        PatternRounds = $sequences.Count; DominantPattern = if ($null -ne $dominant) { $dominant.Name } else { $null }
        DominantFraction = $fraction; DominantSeeds = $dominantSeeds
        FixedPatternSignal = $sequences.Count -ge 10 -and $dominantSeeds -ge 5 -and $fraction -ge 0.75
    }
})
$pairs = @()
foreach ($wind in 1,2) {
    foreach ($refund in @($records | Where-Object { $_.winds -eq $wind -and $_.version -eq 'refund' })) {
        $draw = @($records | Where-Object { $_.winds -eq $wind -and $_.version -eq 'draw_only' -and $_.seed -eq $refund.seed })
        if ($draw.Count -ne 1) { throw 'Missing paired run' }
        if (($refund.checkpoint | ConvertTo-Json -Depth 30 -Compress) -ne ($draw[0].checkpoint | ConvertTo-Json -Depth 30 -Compress)) { throw "Unequal checkpoint wind=$wind seed=$($refund.seed)" }
        if ($null -ne $refund.cloud_activation_turn) {
            $pairs += [pscustomobject]@{
                Winds = $wind; Seed = $refund.seed; StartTurn = $refund.cloud_activation_turn
                DamageDelta = $refund.post_start_damage - $draw[0].post_start_damage
                HpDelta = $refund.remaining_hp - $draw[0].remaining_hp
                RoundDelta = $refund.rounds.Count - $draw[0].rounds.Count
            }
        }
    }
}
$pairedSummary = @($pairs | Group-Object Winds | ForEach-Object {
    $p = @($_.Group)
    [pscustomobject]@{ Winds = $p[0].Winds; Pairs = $p.Count
        MeanDamageDelta = ($p | Measure-Object DamageDelta -Average).Average
        MedianDamageDelta = Percentile @($p.DamageDelta) 0.5
        Positive = @($p | Where-Object DamageDelta -gt 0).Count
        Zero = @($p | Where-Object DamageDelta -eq 0).Count
        Negative = @($p | Where-Object DamageDelta -lt 0).Count
        MeanRoundDelta = ($p | Measure-Object RoundDelta -Average).Average
        MeanHpDelta = ($p | Measure-Object HpDelta -Average).Average }
})
$strata = @($pairs | Group-Object Winds,StartTurn | ForEach-Object {
    [pscustomobject]@{ Winds = $_.Group[0].Winds; StartTurn = $_.Group[0].StartTurn; Pairs = $_.Count
        MeanDamageDelta = ($_.Group | Measure-Object DamageDelta -Average).Average }
})
$damageSignals = @(foreach ($wind in 1,2) {
    $refund = $groups | Where-Object { $_.Winds -eq $wind -and $_.Version -eq 'refund' }
    $reference = $groups | Where-Object { $_.Winds -eq $wind -and $_.Version -eq 'no_cloud' }
    [pscustomobject]@{ Winds = $wind; FirstFiveRatio = if ($reference.MeanFirstFiveDamage -gt 0) { $refund.MeanFirstFiveDamage / $reference.MeanFirstFiveDamage } else { $null }
        DoubleDamageSignal = $reference.MeanFirstFiveDamage -gt 0 -and $refund.MeanFirstFiveDamage -ge 2 * $reference.MeanFirstFiveDamage }
})
[pscustomobject]@{ Games = $records.Count; CheckpointsMatched = 2 * $ExpectedPerGroup; Groups = $groups
    Paired = $pairedSummary; StartTurnStrata = $strata; DamageSignals = $damageSignals; Pairs = $pairs } | ConvertTo-Json -Depth 8
