# Aureus

Aureus is a native macOS net worth tracker built with SwiftUI, SwiftData, and Apple Charts.

## Run

Open `Package.swift` in Xcode 16.4 or newer, select the `Aureus` executable, and run.

From Terminal:

```sh
swift run Aureus
```

## Included

- Local SwiftData persistence for holdings, prices, net worth snapshots, settings, transactions, and watchlist items.
- Dashboard, Holdings, Add/Edit Asset, Asset Detail, Performance, and Settings screens.
- Yahoo Finance quote refresh through the public chart endpoint, with cached prices and graceful failure states.
- Portfolio calculations for value, cost basis, unrealized P/L, daily change, and allocation.
- Apple Charts for net worth, allocation, P/L, and per-asset history.
- Daily snapshot creation on app open plus manual snapshots.
- CSV import/export and JSON local backup/restore.
- Dark and light mode compatible SwiftUI styling.
- Keyboard shortcuts: `Command-N` to add an asset, `Command-R` to refresh prices.

## Privacy

All personal data is stored locally on the Mac. The only network request is the optional ticker price refresh to Yahoo Finance.
