$ErrorActionPreference = 'Stop'
$records = @(Get-Content -LiteralPath '.godot/shield-calibration-v2.jsonl' | ForEach-Object { $_ | ConvertFrom-Json })
if ($records.Count -ne 180) { throw 'Expected 180 calibration games' }
$original = @(Get-Content -LiteralPath 'docs/experiments/shield-baseline-diagnostic-2026-10-06.jsonl' | ForEach-Object { $_ | ConvertFrom-Json })
foreach ($game in ($records | Where-Object initial_enemy_hp -eq 140)) {
    $before = @($original | Where-Object { $_.strategy -eq 'B' -and -not $_.multi -and $_.hit -eq $game.hit -and $_.seed -eq $game.seed })
    if ($before.Count -ne 1) { throw 'Missing original B game' }
    foreach ($field in 'won','dead','truncated','hp','turns','enemy_hp','cycles','rounds') {
        if ((ConvertTo-Json -InputObject $game.$field -Depth 50 -Compress) -ne (ConvertTo-Json -InputObject $before[0].$field -Depth 50 -Compress)) { throw "Baseline replay mismatch seed=$($game.seed) field=$field" }
    }
    # 批次中的战斗编号不同，不属于小墨决策状态。
    $newIntents = @($game.intents | Select-Object * -ExcludeProperty battle_index,run_id)
    $oldIntents = @($before[0].intents | Select-Object * -ExcludeProperty battle_index,run_id)
    if ((ConvertTo-Json -InputObject $newIntents -Depth 50 -Compress) -ne (ConvertTo-Json -InputObject $oldIntents -Depth 50 -Compress)) { throw 'Companion decision replay mismatch' }
}
$summary = @(foreach ($group in ($records | Group-Object initial_enemy_hp,hit)) {
    $games = @($group.Group)
    $cycles = @($games | ForEach-Object { $_.cycles } | Where-Object complete)
    $incoming = ($cycles | Measure-Object incoming -Sum).Sum
    $strike = ($cycles | Measure-Object strike_shield -Sum).Sum
    $cycleShield = ($cycles | Measure-Object cycle_shield -Sum).Sum
    $sources = @($games.damage_sources)
    $hand = ($sources | Measure-Object hand -Sum).Sum
    $ultimate = ($sources | Measure-Object brilliance -Sum).Sum
    $companion = ($sources | Measure-Object companion -Sum).Sum
    $total = $hand+$ultimate+$companion
    foreach ($game in $games) { if ($game.damage_sources.hand + $game.damage_sources.brilliance + $game.damage_sources.companion -ne $game.initial_enemy_hp - $game.enemy_hp) { throw 'Damage conservation failed' } }
    $hp = @($games.hp | Sort-Object)
    [pscustomobject]@{
        EnemyHP=$games[0].initial_enemy_hp; Hit=$games[0].hit; Games=$games.Count
        Wins=@($games | Where-Object won).Count; Deaths=@($games | Where-Object dead).Count; Cutoffs=@($games | Where-Object truncated).Count
        HpMin=$hp[0]; HpMedian=($hp[9]+$hp[10])/2; HpMax=$hp[-1]
        CompleteCycles=$cycles.Count; MeanCompleteCycles=$cycles.Count/$games.Count
        FourOrFiveCycleGames=@($games | Where-Object { @($_.cycles | Where-Object complete).Count -in @(4,5) }).Count
        MeanPlayerTurns=(@($games | ForEach-Object { if ($_.won) { $_.turns+1 } else { $_.turns } }) | Measure-Object -Average).Average
        IncomingToStrikeShield=if ($strike -gt 0) { $incoming/$strike } else { $null }
        IncomingToCycleShield=if ($cycleShield -gt 0) { $incoming/$cycleShield } else { $null }
        HandDamage=$hand; BrillianceDamage=$ultimate; CompanionDamage=$companion
        HandShare=$hand/$total; BrillianceShare=$ultimate/$total; CompanionShare=$companion/$total
    }
})
[IO.File]::WriteAllText((Join-Path $PWD 'docs/experiments/shield-calibration-v2-summary-2026-10-06.json'), (ConvertTo-Json -InputObject $summary -Depth 8), [Text.UTF8Encoding]::new($false))
$summary | Format-Table EnemyHP,Hit,Wins,Deaths,HpMin,HpMedian,HpMax,MeanCompleteCycles,HandShare,BrillianceShare,CompanionShare -AutoSize
