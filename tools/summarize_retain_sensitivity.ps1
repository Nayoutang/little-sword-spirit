$ErrorActionPreference = 'Stop'
$records = @(Get-Content -LiteralPath '.godot/retain-shield-sensitivity.jsonl' | ForEach-Object { $_ | ConvertFrom-Json })
if ($records.Count -ne 80) { throw 'Expected 80 sensitivity games' }
$old = @(Get-Content -LiteralPath 'docs/experiments/retain-shield-step-two-2026-10-06.jsonl' | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object group -eq retain_strike)
foreach ($game in ($records | Where-Object group -eq interval_two)) {
    $before = @($old | Where-Object seed -eq $game.seed)[0]
    foreach ($field in 'won','dead','truncated','hp','turns','enemy_hp','cycles','rounds','actions','damage_sources','shield_damage','shield_exposures','activation_turn','start_blocks') {
        if ((ConvertTo-Json -InputObject $game.$field -Depth 50 -Compress) -ne (ConvertTo-Json -InputObject $before.$field -Depth 50 -Compress)) { throw "Interval replay mismatch seed=$($game.seed) field=$field" }
    }
}
function Potential($Strike) {
    $value=[double]$Strike.shield
    if ($Strike.boon.type -eq 'multiply') { $value=[Math]::Round($value*$Strike.boon.value,0,[MidpointRounding]::AwayFromZero) }
    if ($Strike.boon.type -eq 'add') { $value+=$Strike.boon.value }
    return $value+$Strike.vulnerable
}
$checks=@(foreach ($game in $records) {
    $cycles=@($game.cycles | Where-Object { $_.complete -and $game.activation_turn -ge 0 -and $_.start_turn -ge $game.activation_turn })
    $run=0; $maxRun=0
    for ($i=1; $i -lt $cycles.Count; $i++) {
        if ($cycles[$i].start_turn -eq $cycles[$i-1].start_turn+2 -and $cycles[$i].start_shield -gt $cycles[$i-1].start_shield) { $run++ } else { $run=0 }
        $maxRun=[Math]::Max($maxRun,$run)
    }
    $strikes=@($game.actions | Where-Object id -eq 17)
    $potential=@($strikes | ForEach-Object { Potential $_ })
    [pscustomobject]@{Group=$game.group; Seed=$game.seed; EligibleCycles=$cycles.Count; ThreeIncreases=$maxRun -ge 3
        HighHits=@($strikes | Where-Object damage -ge 60).Count; PotentialHighHits=@($potential | Where-Object { $_ -ge 60 }).Count
        MaxPotential=($potential | Measure-Object -Maximum).Maximum; StartShields=@($cycles.start_shield)}
})
$groups=@(foreach ($name in 'interval_one','interval_two','continuous_baseline','continuous_two') {
    $games=@($records | Where-Object group -eq $name)
    $wins=@($games | Where-Object won)
    $hp=@($games.hp | Sort-Object)
    $rows=@($games | ForEach-Object { $_.rounds } | Where-Object { $null -ne $_.enemy_incoming })
    $incoming=0
    foreach ($row in $rows) {
        if ([int]$row.starting_block+[int]$row.block_gained_player+[int]$row.block_gained_companion -ne [int]$row.block_consumed+[int]$row.block_expired+[int]$row.block_carried) { throw 'Shield conservation failed' }
        foreach ($action in $row.enemy_actions) { if ($action.type -eq 'attack' -and $action.executed) { $incoming+=$action.damage } }
    }
    $gain=($rows | Measure-Object block_gained_player -Sum).Sum+($rows | Measure-Object block_gained_companion -Sum).Sum
    $cycleRows=@($games | ForEach-Object { $_.cycles } | Where-Object complete)
    $cycleDamage=($cycleRows | Measure-Object incoming -Sum).Sum
    $cycleGain=($cycleRows | Measure-Object cycle_shield -Sum).Sum
    $strikes=@($games | ForEach-Object { $_.actions } | Where-Object id -eq 17)
    $check=@($checks | Where-Object Group -eq $name)
    foreach ($game in $games) { if ($game.damage_sources.hand+$game.damage_sources.brilliance+$game.damage_sources.companion -ne 180-$game.enemy_hp) { throw 'Damage conservation failed' } }
    [pscustomobject]@{Group=$name; Wins=$wins.Count; Deaths=@($games | Where-Object dead).Count; Cutoffs=@($games | Where-Object truncated).Count
        HpMin=$hp[0]; HpMedian=($hp[9]+$hp[10])/2; HpMax=$hp[-1]
        MeanObservedTurns=(@($games | ForEach-Object { $_.actions[-1].turn }) | Measure-Object -Average).Average
        MeanWinningTurns=(@($wins | ForEach-Object { $_.actions[-1].turn }) | Measure-Object -Average).Average
        ResolvedEnemyTurns=$rows.Count; ExecutedIncoming=$incoming; NewShield=$gain; IncomingToNewShield=$incoming/$gain
        CompleteCycles=$cycleRows.Count; CompleteCycleIncomingToNewShield=$cycleDamage/$cycleGain
        MaxStartingShield=(@($games | ForEach-Object { $_.start_blocks.shield }) | Measure-Object -Maximum).Maximum
        ThreeIncreaseGames=@($check | Where-Object ThreeIncreases).Count; UnderFourCycleGames=@($check | Where-Object EligibleCycles -lt 4).Count
        StrikeHits=$strikes.Count; MeanStrikesPerBattle=$strikes.Count/20; MeanStrikeDamage=($strikes | Measure-Object damage -Average).Average
        MaxStrikeDamage=($strikes | Measure-Object damage -Maximum).Maximum; MaxPotential=($check | Measure-Object MaxPotential -Maximum).Maximum
        HighStrikeGames=@($check | Where-Object HighHits -gt 0).Count; HighStrikeHits=($check | Measure-Object HighHits -Sum).Sum
        PotentialHighHits=($check | Measure-Object PotentialHighHits -Sum).Sum
    }
})
$boons=@(foreach ($name in 'interval_one','interval_two','continuous_two') {
    foreach ($type in 'multiply','add','none') {
        $strikes=@($records | Where-Object group -eq $name | ForEach-Object { $_.actions } | Where-Object { $_.id -eq 17 -and $(if ($type -eq 'none') { -not $_.boon.type } else { $_.boon.type -eq $type }) })
        [pscustomobject]@{Group=$name; Boon=$type; Hits=$strikes.Count; MeanShield=($strikes | Measure-Object shield -Average).Average
            MeanDamage=($strikes | Measure-Object damage -Average).Average; MaxDamage=($strikes | Measure-Object damage -Maximum).Maximum}
    }
})
$frequencies=@($records | ForEach-Object {
    $game=$_
    foreach ($intent in $game.intents) { if ($intent.phase -eq 'execute') { [pscustomobject]@{Group=$game.group; Selected=$intent.selected} } }
} | Group-Object Group,Selected | ForEach-Object { [pscustomobject]@{Group=$_.Group[0].Group; Intent=$_.Group[0].Selected; Count=$_.Count} })
$result=[pscustomobject]@{Groups=$groups; Boons=$boons; GrowthChecks=$checks; IntentFrequencies=$frequencies; MatchedOriginalGames=20}
[IO.File]::WriteAllText((Join-Path $PWD 'docs/experiments/retain-shield-sensitivity-summary-2026-10-06.json'),(ConvertTo-Json -InputObject $result -Depth 12),[Text.UTF8Encoding]::new($false))
$groups | ConvertTo-Json -Depth 4
$boons | Format-Table -AutoSize
