$ErrorActionPreference = 'Stop'
function Read-Records([string]$Path) { @(Get-Content -LiteralPath $Path | ForEach-Object { $_ | ConvertFrom-Json }) }
function Normalize-Value($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) { return [double]$Value }
    if ($Value -is [Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) { $result[$key] = Normalize-Value $Value[$key] }
        return $result
    }
    if ($Value -is [pscustomobject]) {
        $result = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) { $result[$property.Name] = Normalize-Value $property.Value }
        return $result
    }
    if ($Value -is [array]) {
        $result = New-Object object[] $Value.Count
        for ($i = 0; $i -lt $Value.Count; $i++) { $result[$i] = Normalize-Value $Value[$i] }
        return ,$result
    }
    return $Value
}
function Canonical($Value) { ConvertTo-Json -InputObject (Normalize-Value $Value) -Depth 50 -Compress }
$archive = Read-Records 'docs/experiments/combo-v2-diagnostic-2026-10-06.jsonl'
$new = Read-Records '.godot/combo-action-regression-sequential.jsonl'
$old = Read-Records '.godot/combo-action-regression-legacy.jsonl'
if ($archive.Count -ne 120 -or $new.Count -ne 120 -or $old.Count -ne 120) { throw 'Expected three complete 120-game records' }
$oldByKey = @{}; $archiveByKey = @{}
foreach ($game in $old) { $oldByKey["$($game.winds)/$($game.seed)/$($game.version)"] = $game }
foreach ($game in $archive) { $archiveByKey["$($game.winds)/$($game.seed)/$($game.version)"] = $game }
$decisions = 0
foreach ($game in $new) {
    $key = "$($game.winds)/$($game.seed)/$($game.version)"
    $before = $oldByKey[$key]; $original = $archiveByKey[$key]
    if ($null -eq $before -or $null -eq $original -or $game.truncated -or $before.truncated) { throw "Missing or failed game $key" }
    foreach ($field in 'won','remaining_hp','first_five_damage','post_start_damage','cloud_activation_turn','joint_skills_numerator','eligible_rounds_denominator','actions','intervals','damage_records','intents','observed_hands','checkpoint') {
        if ((Canonical $game.$field) -ne (Canonical $original.$field) -or (Canonical $before.$field) -ne (Canonical $original.$field)) { throw "Archive mismatch $key field=$field" }
    }
    if ((Canonical $game.rng_trace) -ne (Canonical $before.rng_trace) -or (Canonical $game.final_rng) -ne (Canonical $before.final_rng)) { throw "RNG mismatch $key" }
    if ((Canonical $game.executed_actions) -ne (Canonical $before.executed_actions)) { throw "Replay action mismatch $key" }
    if ($game.rounds.Count -ne $original.rounds.Count) { throw "Round count mismatch $key" }
    for ($i = 0; $i -lt $original.rounds.Count; $i++) {
        $projected = [ordered]@{}
        foreach ($property in $original.rounds[$i].PSObject.Properties) { $projected[$property.Name] = $game.rounds[$i].($property.Name) }
        if ((Canonical $projected) -ne (Canonical $original.rounds[$i])) { throw "Round content mismatch $key round=$i" }
    }
    $decisions += $game.rng_trace.Count
}
$rounds = @($new | ForEach-Object { $_.rounds } | Where-Object { $null -ne $_.enemy_incoming })
foreach ($round in $rounds) {
    $gained = [int]$round.block_gained_player + [int]$round.block_gained_companion
    if ($gained -ne $round.block_consumed + $round.block_expired) { throw 'Shield conservation mismatch' }
}
$pressure = @(foreach ($hasAttack in $true,$false) {
    $group = @($rounds | Where-Object { (@($_.enemy_actions | Where-Object { $_.type -eq 'attack' -and $_.executed }).Count -gt 0) -eq $hasAttack })
    $player = ($group | Measure-Object block_gained_player -Sum).Sum
    $companion = ($group | Measure-Object block_gained_companion -Sum).Sum
    $consumed = ($group | Measure-Object block_consumed -Sum).Sum
    $expired = ($group | Measure-Object block_expired -Sum).Sum
    [pscustomobject]@{ HasAttack = $hasAttack; Rounds = $group.Count; PlayerBlock = $player; CompanionBlock = $companion
        Incoming = ($group | Measure-Object enemy_incoming -Sum).Sum; Consumed = $consumed; Expired = $expired
        ConsumedRatio = if ($player + $companion -gt 0) { $consumed / ($player + $companion) } else { $null }
        ExpiredRatio = if ($player + $companion -gt 0) { $expired / ($player + $companion) } else { $null } }
})
[pscustomobject]@{ ArchivedGames = 120; NewReplays = 120; LegacyReplays = 120; MatchedDecisionStates = $decisions
    MatchedRngTraces = $decisions; MatchedFinalRngStates = 120; ResolvedEnemyTurns = $rounds.Count; Pressure = $pressure } | ConvertTo-Json -Depth 5
