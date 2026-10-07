$ErrorActionPreference = 'Stop'
$records = @(Get-Content -LiteralPath '.godot/shield-baseline-diagnostic.jsonl' | ForEach-Object { $_ | ConvertFrom-Json })
if ($records.Count -ne 240) { throw 'Expected 240 records' }
$summary = @(foreach ($group in ($records | Group-Object hit,multi,strategy)) {
    $games = @($group.Group)
    $cycles = @($games | ForEach-Object { $_.cycles } | Where-Object complete)
    $incoming = ($cycles | Measure-Object incoming -Sum).Sum
    $strike = ($cycles | Measure-Object strike_shield -Sum).Sum
    $total = ($cycles | Measure-Object cycle_shield -Sum).Sum
    $wins = @($games | Where-Object won)
    $hp = @($games.hp | Sort-Object)
    [pscustomobject]@{
        Hit=$games[0].hit; Multi=$games[0].multi; Strategy=$games[0].strategy; Games=$games.Count
        Wins=$wins.Count; Deaths=@($games | Where-Object dead).Count; Cutoffs=@($games | Where-Object truncated).Count
        MeanEndedTurns=($games | Measure-Object turns -Average).Average
        MeanWinningPlayerTurns=if ($wins.Count) { (@($wins | ForEach-Object { $_.turns + 1 }) | Measure-Object -Average).Average } else { $null }
        HpMin=$hp[0]; HpMedian=($hp[9]+$hp[10])/2; HpMax=$hp[-1]
        CompleteCycles=$cycles.Count; Incoming=$incoming; StrikeShield=$strike; CycleShield=$total
        IncomingToStrikeShield=if ($strike -gt 0) { $incoming/$strike } else { $null }
        IncomingToCycleShield=if ($total -gt 0) { $incoming/$total } else { $null }
        CycleLifeLost=($cycles | Measure-Object life_lost -Sum).Sum
    }
})
$json = ConvertTo-Json -InputObject $summary -Depth 8
[IO.File]::WriteAllText((Join-Path $PWD 'docs/experiments/shield-baseline-summary-2026-10-06.json'), $json, [Text.UTF8Encoding]::new($false))
$summary | Format-Table Hit,Multi,Strategy,Wins,Deaths,Cutoffs,HpMedian,CompleteCycles,IncomingToStrikeShield,IncomingToCycleShield -AutoSize
