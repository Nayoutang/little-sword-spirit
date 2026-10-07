$ErrorActionPreference = 'Stop'
$records = @(Get-Content -LiteralPath '.godot/shield-strike-step-one.jsonl' | ForEach-Object { $_ | ConvertFrom-Json })
if ($records.Count -ne 40) { throw 'Expected 40 games' }
$baseline = @(Get-Content -LiteralPath 'docs/experiments/shield-calibration-v2-2026-10-06.jsonl' | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.initial_enemy_hp -eq 180 -and $_.hit -eq 30 })
foreach ($game in ($records | Where-Object shield_copies -eq 0)) {
    $old = @($baseline | Where-Object seed -eq $game.seed)[0]
    foreach ($field in 'won','dead','truncated','hp','turns','enemy_hp','cycles','rounds','damage_sources') {
        if ((ConvertTo-Json -InputObject $game.$field -Depth 50 -Compress) -ne (ConvertTo-Json -InputObject $old.$field -Depth 50 -Compress)) { throw "Baseline mismatch seed=$($game.seed) field=$field" }
    }
}
$groups = @(foreach ($copies in 0,2) {
    $games = @($records | Where-Object shield_copies -eq $copies)
    $wins = @($games | Where-Object won)
    $hp = @($games.hp | Sort-Object)
    $exposures = @($games | ForEach-Object { $_.shield_exposures })
    $strikes = @($games | ForEach-Object { $_.actions } | Where-Object id -eq 17)
    $firstFive = @($games | ForEach-Object { (@($_.actions | Where-Object turn -le 5) | Measure-Object damage -Sum).Sum })
    foreach ($game in $games) {
        if ($game.damage_sources.hand + $game.damage_sources.brilliance + $game.damage_sources.companion -ne 180 - $game.enemy_hp) { throw 'Damage conservation failed' }
        if (@($game.actions | Where-Object id -eq 17).Count -ne @($game.shield_exposures | Where-Object outcome -eq played).Count) { throw 'Exposure/action mismatch' }
    }
    [pscustomobject]@{
        Copies=$copies; Games=$games.Count; Wins=$wins.Count; Deaths=@($games | Where-Object dead).Count; Cutoffs=@($games | Where-Object truncated).Count
        HpMin=$hp[0]; HpMedian=($hp[9]+$hp[10])/2; HpMax=$hp[-1]; MeanHp=($games | Measure-Object hp -Average).Average
        MeanObservedPlayerTurns=(@($games | ForEach-Object { $_.actions[-1].turn }) | Measure-Object -Average).Average
        MeanWinningPlayerTurns=(@($wins | ForEach-Object { $_.actions[-1].turn }) | Measure-Object -Average).Average
        MeanFirstFiveDamage=($firstFive | Measure-Object -Average).Average
        HandDamage=($games.damage_sources | Measure-Object hand -Sum).Sum; BrillianceDamage=($games.damage_sources | Measure-Object brilliance -Sum).Sum
        CompanionDamage=($games.damage_sources | Measure-Object companion -Sum).Sum; ShieldDamage=($games | Measure-Object shield_damage -Sum).Sum
        StrikePlays=$strikes.Count; MultiplyStrikes=@($strikes | Where-Object { $_.boon.type -eq 'multiply' }).Count; AddStrikes=@($strikes | Where-Object { $_.boon.type -eq 'add' }).Count
        Exposures=$exposures.Count; Played=@($exposures | Where-Object outcome -eq played).Count; Discarded=@($exposures | Where-Object outcome -eq discarded).Count
        BattleEndHeld=@($exposures | Where-Object outcome -eq battle_end).Count
    }
})
$exposures = @($records | Where-Object shield_copies -eq 2 | ForEach-Object { $_.shield_exposures })
$holding = @(foreach ($range in 'zero','low','above_low') {
    $selected = @($exposures | Where-Object { if ($range -eq 'zero') { $_.max_shield -eq 0 } elseif ($range -eq 'low') { $_.max_shield -ge 1 -and $_.max_shield -le 5 } else { $_.max_shield -gt 5 } })
    $unused = @($selected | Where-Object outcome -ne played)
    [pscustomobject]@{Range=$range; Exposures=$selected.Count; Played=@($selected | Where-Object outcome -eq played).Count
        Unused=$unused.Count; UnusedRate=if ($selected.Count) { $unused.Count/$selected.Count } else { $null }
        UnusedAffordableAtLastDecision=@($unused | Where-Object last_affordable).Count
        UnusedNeverAffordable=@($unused | Where-Object { -not $_.ever_affordable }).Count
        Discarded=@($unused | Where-Object outcome -eq discarded).Count; BattleEnd=@($unused | Where-Object outcome -eq battle_end).Count }
})
$differences = @(foreach ($seedValue in 400001..400020) {
    $old = @($records | Where-Object { $_.seed -eq $seedValue -and $_.shield_copies -eq 0 })[0]
    $new = @($records | Where-Object { $_.seed -eq $seedValue -and $_.shield_copies -eq 2 })[0]
    $oldDamage = (@($old.actions | Where-Object turn -le 5) | Measure-Object damage -Sum).Sum
    $newDamage = (@($new.actions | Where-Object turn -le 5) | Measure-Object damage -Sum).Sum
    [pscustomobject]@{Seed=$seedValue; HpDifference=$new.hp-$old.hp; FirstFiveDamageDifference=$newDamage-$oldDamage; BothWon=$new.won -and $old.won}
})
$result = [pscustomobject]@{Groups=$groups; Holding=$holding; Pairs=$differences; MeanPairedFirstFiveDamageDifference=($differences | Measure-Object FirstFiveDamageDifference -Average).Average}
[IO.File]::WriteAllText((Join-Path $PWD 'docs/experiments/shield-strike-step-one-summary-2026-10-06.json'), (ConvertTo-Json -InputObject $result -Depth 12), [Text.UTF8Encoding]::new($false))
$result | ConvertTo-Json -Depth 5
