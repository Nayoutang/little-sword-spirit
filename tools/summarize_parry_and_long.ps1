$ErrorActionPreference = 'Stop'
$long = @(Get-Content -LiteralPath '.godot/retain-shield-long.jsonl' | ForEach-Object { $_ | ConvertFrom-Json })
if ($long.Count -ne 20) { throw 'Expected 20 long fights' }
$curves=@(foreach ($game in $long) {
    $cycles=@($game.cycles | Where-Object { $_.complete -and $_.start_turn -ge $game.activation_turn })
    $shields=@($cycles.start_shield)
    $drops=0
    for ($i=1;$i -lt $shields.Count;$i++) { if ($shields[$i] -lt $shields[$i-1]) { $drops++ } }
    [pscustomobject]@{Seed=$game.seed; Turns=$game.actions[-1].turn; EligibleCycles=$cycles.Count; StartShields=$shields
        First=$shields[0]; Last=$shields[-1]; MaxPhaseStart=($shields | Measure-Object -Maximum).Maximum
        MaxAnyTurnStart=(@($game.start_blocks.shield) | Measure-Object -Maximum).Maximum; DownwardTransitions=$drops}
})
$hp=@($long.hp | Sort-Object)
$longSummary=[pscustomobject]@{Games=20; Wins=@($long|Where-Object won).Count; Deaths=@($long|Where-Object dead).Count; Cutoffs=@($long|Where-Object truncated).Count
    MeanTurns=(@($long|ForEach-Object{$_.actions[-1].turn})|Measure-Object -Average).Average
    MinTurns=(@($long|ForEach-Object{$_.actions[-1].turn})|Measure-Object -Minimum).Minimum
    MaxTurns=(@($long|ForEach-Object{$_.actions[-1].turn})|Measure-Object -Maximum).Maximum
    HpMin=$hp[0]; HpMedian=($hp[9]+$hp[10])/2; HpMax=$hp[-1]
    MaxAnyTurnStart=($curves|Measure-Object MaxAnyTurnStart -Maximum).Maximum; MaxPhaseStart=($curves|Measure-Object MaxPhaseStart -Maximum).Maximum
    GamesWithDrawdown=@($curves|Where-Object DownwardTransitions -gt 0).Count; Curves=$curves}
$records=@(Get-Content -LiteralPath '.godot/parry-step-three.jsonl' | ForEach-Object { $_|ConvertFrom-Json })
if ($records.Count -ne 160) { throw 'Expected 160 parry/control fights' }
$old=@(Get-Content -LiteralPath 'docs/experiments/retain-shield-sensitivity-2026-10-06.jsonl'|ForEach-Object{$_|ConvertFrom-Json})
foreach ($game in ($records|Where-Object{$_.group -in @('interval_single_control','continuous_single_control')})) {
    $name=if ($game.continuous) {'continuous_two'} else {'interval_two'}
    $before=@($old|Where-Object{$_.group -eq $name -and $_.seed -eq $game.seed})[0]
    foreach ($field in 'won','dead','truncated','hp','turns','enemy_hp','cycles','rounds','actions','damage_sources','shield_damage','activation_turn','start_blocks') {
        if ((ConvertTo-Json -InputObject $game.$field -Depth 50 -Compress) -ne (ConvertTo-Json -InputObject $before.$field -Depth 50 -Compress)) { throw "Control mismatch seed=$($game.seed) group=$name field=$field" }
    }
}
foreach ($game in (@($records)+@($long))) {
    if ($game.damage_sources.hand+$game.damage_sources.brilliance+$game.damage_sources.companion+[int]$game.damage_sources.parry -ne $game.initial_enemy_hp-$game.enemy_hp) { throw 'Damage conservation mismatch' }
    foreach ($row in $game.rounds) {
        if ($null -ne $row.enemy_incoming -and [int]$row.starting_block+[int]$row.block_gained_player+[int]$row.block_gained_companion -ne [int]$row.block_consumed+[int]$row.block_expired+[int]$row.block_carried) { throw 'Shield conservation mismatch' }
        $injected=[int]$row.parry_injected
        $outcomes=[int]$row.parry_combo_defense+[int]$row.parry_combo_skill+[int]$row.parry_combo_other+[int]$row.parry_combo_preserved+[int]$row.parry_combo_expired+[int]$row.parry_combo_battle_end
        if ($injected -ne $outcomes) { throw "Injected combo accounting mismatch seed=$($game.seed) turn=$($row.turn)" }
    }
    $awarded=($game.rounds|Measure-Object parry_awarded -Sum).Sum
    $injected=($game.rounds|Measure-Object parry_injected -Sum).Sum
    $notInjected=($game.rounds|Measure-Object parry_award_not_injected -Sum).Sum
    if ($awarded -ne $injected+$notInjected) { throw 'Award/injection mismatch' }
}
$groups=@(foreach ($group in ($records|Group-Object group)) {
    $games=@($group.Group); $wins=@($games|Where-Object won); $hp=@($games.hp|Sort-Object)
    $rows=@($games|ForEach-Object{$_.rounds}); $injectedRows=@($rows|Where-Object parry_injected -gt 0)
    $defenseRows=@($injectedRows|Where-Object parry_combo_defense -gt 0)
    [pscustomobject]@{Group=$group.Name; Wins=$wins.Count; Deaths=@($games|Where-Object dead).Count; Cutoffs=@($games|Where-Object truncated).Count
        HpMin=$hp[0]; HpMedian=($hp[9]+$hp[10])/2; HpMax=$hp[-1]
        MeanObservedTurns=(@($games|ForEach-Object{$_.actions[-1].turn})|Measure-Object -Average).Average
        MeanWinningTurns=(@($wins|ForEach-Object{$_.actions[-1].turn})|Measure-Object -Average).Average
        ParryPlays=@($games|ForEach-Object{$_.actions}|Where-Object id -eq 19).Count
        Reactions=($rows|Measure-Object parry_reactions -Sum).Sum
        ParryDamage=(@($games.damage_sources)|Measure-Object parry -Sum).Sum
        AwardedLayers=($rows|Measure-Object parry_awarded -Sum).Sum; InjectedLayers=($rows|Measure-Object parry_injected -Sum).Sum
        InjectionRounds=$injectedRows.Count; DefenseClearedRounds=$defenseRows.Count
        DefenseClearedRoundRate=if($injectedRows.Count){$defenseRows.Count/$injectedRows.Count}else{$null}
        DefenseClearedLayers=($rows|Measure-Object parry_combo_defense -Sum).Sum
        SkillSpentLayers=($rows|Measure-Object parry_combo_skill -Sum).Sum
        PreservedLayers=($rows|Measure-Object parry_combo_preserved -Sum).Sum
        ExpiredLayers=($rows|Measure-Object parry_combo_expired -Sum).Sum
        OtherLayers=($rows|Measure-Object parry_combo_other -Sum).Sum
        BattleEndLayers=($rows|Measure-Object parry_combo_battle_end -Sum).Sum
    }
})
$result=[pscustomobject]@{Long=$longSummary; ParryGroups=$groups; MatchedControls=40; ConservationGames=180}
[IO.File]::WriteAllText((Join-Path $PWD 'docs/experiments/parry-and-long-summary-2026-10-06.json'),(ConvertTo-Json -InputObject $result -Depth 12),[Text.UTF8Encoding]::new($false))
$longSummary|Select-Object * -ExcludeProperty Curves|ConvertTo-Json
$groups|Format-Table Group,Wins,Deaths,Cutoffs,HpMedian,MeanObservedTurns,Reactions,ParryDamage,InjectionRounds,DefenseClearedRoundRate -AutoSize
