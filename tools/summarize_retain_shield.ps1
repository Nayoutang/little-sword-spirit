$ErrorActionPreference = 'Stop'
$records = @(Get-Content -LiteralPath '.godot/retain-shield-step-two.jsonl' | ForEach-Object { $_ | ConvertFrom-Json })
if ($records.Count -ne 60) { throw 'Expected 60 games' }
$baseline = @(Get-Content -LiteralPath 'docs/experiments/shield-strike-step-one-2026-10-06.jsonl' | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object shield_copies -eq 0)
foreach ($game in ($records | Where-Object group -eq baseline)) {
    $old = @($baseline | Where-Object seed -eq $game.seed)[0]
    foreach ($field in 'won','dead','truncated','hp','turns','enemy_hp','rounds','damage_sources') {
        if ((ConvertTo-Json -InputObject $game.$field -Depth 50 -Compress) -ne (ConvertTo-Json -InputObject $old.$field -Depth 50 -Compress)) { throw "Baseline mismatch seed=$($game.seed) field=$field" }
    }
}
$rows = @($records | ForEach-Object { $_.rounds } | Where-Object { $null -ne $_.enemy_incoming })
foreach ($row in $rows) {
    if ([int]$row.starting_block+[int]$row.block_gained_player+[int]$row.block_gained_companion -ne [int]$row.block_consumed+[int]$row.block_expired+[int]$row.block_carried) { throw 'Shield conservation mismatch' }
}
$checks = @(foreach ($game in $records) {
    $cycles = @($game.cycles | Where-Object { $_.complete -and $game.activation_turn -ge 0 -and $_.start_turn -ge $game.activation_turn })
    $run = 0; $maxRun = 0
    for ($i=1; $i -lt $cycles.Count; $i++) {
        if ($cycles[$i].start_turn -eq $cycles[$i-1].start_turn+2 -and $cycles[$i].start_shield -gt $cycles[$i-1].start_shield) { $run++ } else { $run=0 }
        $maxRun=[Math]::Max($maxRun,$run)
    }
    $strikes = @($game.actions | Where-Object id -eq 17)
    $potentialHigh = 0
    foreach ($strike in $strikes) {
        $base = [double]$strike.shield
        if ($strike.boon.type -eq 'multiply') { $base=[Math]::Round($base*$strike.boon.value,0,[MidpointRounding]::AwayFromZero) }
        if ($strike.boon.type -eq 'add') { $base += $strike.boon.value }
        if ($base + $strike.vulnerable -ge 60) { $potentialHigh++ }
    }
    if ($game.damage_sources.hand+$game.damage_sources.brilliance+$game.damage_sources.companion -ne 180-$game.enemy_hp) { throw 'Damage conservation failed' }
    [pscustomobject]@{Group=$game.group; Seed=$game.seed; ActivatedTurn=$game.activation_turn; EligibleCycles=$cycles.Count
        ThreeIncreases=$maxRun -ge 3; MaxConsecutiveIncreases=$maxRun; HighStrikeHits=@($strikes | Where-Object damage -ge 60).Count
        PotentialHighHits=$potentialHigh; StartShields=@($cycles.start_shield); CycleTurns=@($cycles.start_turn)}
})
$groups = @(foreach ($name in 'baseline','retain_only','retain_strike') {
    $games=@($records | Where-Object group -eq $name)
    $groupChecks=@($checks | Where-Object Group -eq $name)
    $hp=@($games.hp | Sort-Object)
    $rounds=@($games | ForEach-Object { $_.rounds } | Where-Object { $null -ne $_.enemy_incoming })
    $player=($rounds | Measure-Object block_gained_player -Sum).Sum
    $companion=($rounds | Measure-Object block_gained_companion -Sum).Sum
    $incoming=0
    foreach ($row in $rounds) { foreach ($action in $row.enemy_actions) { if ($action.type -eq 'attack' -and $action.executed) { $incoming+=$action.damage } } }
    $wins=@($games | Where-Object won)
    [pscustomobject]@{Group=$name; Wins=$wins.Count; Deaths=@($games | Where-Object dead).Count; Cutoffs=@($games | Where-Object truncated).Count
        HpMin=$hp[0]; HpMedian=($hp[9]+$hp[10])/2; HpMax=$hp[-1]; MeanHp=($games | Measure-Object hp -Average).Average
        MeanObservedTurns=(@($games | ForEach-Object { $_.actions[-1].turn }) | Measure-Object -Average).Average
        MeanWinningTurns=(@($wins | ForEach-Object { $_.actions[-1].turn }) | Measure-Object -Average).Average
        ActivationCount=@($games | Where-Object activation_turn -ge 0).Count
        ActivationTurnMedian=if ($name -ne 'baseline') { $t=@($games.activation_turn | Sort-Object); ($t[9]+$t[10])/2 } else { $null }
        ThreeIncreaseGames=@($groupChecks | Where-Object ThreeIncreases).Count; UnderFourCycleGames=@($groupChecks | Where-Object EligibleCycles -lt 4).Count
        HighStrikeGames=@($groupChecks | Where-Object HighStrikeHits -gt 0).Count; HighStrikeHits=($groupChecks | Measure-Object HighStrikeHits -Sum).Sum
        PotentialHighHits=($groupChecks | Measure-Object PotentialHighHits -Sum).Sum
        MaxStartingShield=(@($games | ForEach-Object { $_.start_blocks.shield }) | Measure-Object -Maximum).Maximum
        PlayerNewShield=$player; CompanionNewShield=$companion; CompanionShare=$companion/($player+$companion)
        ResolvedEnemyTurns=$rounds.Count; ExecutedIncoming=$incoming; IncomingToNewShield=$incoming/($player+$companion)
        ShieldDamage=($games | Measure-Object shield_damage -Sum).Sum
    }
})
$allStrikes=@($records | ForEach-Object { $_.actions } | Where-Object id -eq 17)
$boons=@(foreach ($type in 'multiply','add','none') {
    $strikes=@($allStrikes | Where-Object { if ($type -eq 'none') { -not $_.boon.type } else { $_.boon.type -eq $type } })
    [pscustomobject]@{Boon=$type; Hits=$strikes.Count; MeanShield=($strikes | Measure-Object shield -Average).Average
        MeanDamage=($strikes | Measure-Object damage -Average).Average; TotalDamage=($strikes | Measure-Object damage -Sum).Sum
        MaxDamage=($strikes | Measure-Object damage -Maximum).Maximum; HighHits=@($strikes | Where-Object damage -ge 60).Count}
})
$frequencies=@($records | ForEach-Object {
    $game=$_
    foreach ($intent in $game.intents) { if ($intent.phase -eq 'execute') { [pscustomobject]@{Group=$game.group; Selected=$intent.selected} } }
} | Group-Object Group,Selected | ForEach-Object { [pscustomobject]@{Group=$_.Group[0].Group; Intent=$_.Group[0].Selected; Count=$_.Count} })
$result=[pscustomobject]@{Groups=$groups; StrikeBoons=$boons; GrowthChecks=$checks; IntentFrequencies=$frequencies; ShieldConservationTurns=$rows.Count}
[IO.File]::WriteAllText((Join-Path $PWD 'docs/experiments/retain-shield-step-two-summary-2026-10-06.json'),(ConvertTo-Json -InputObject $result -Depth 12),[Text.UTF8Encoding]::new($false))
$groups | Format-Table -AutoSize
$boons | Format-Table -AutoSize
$frequencies | Format-Table -AutoSize
