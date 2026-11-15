# EUDI reference wallet, Plenipo test build

This fork of [eudi-app-ios-wallet-ui](https://github.com/eu-digital-identity-wallet/eudi-app-ios-wallet-ui)
adds what is needed to approve a [Plenipo](https://plenipo.net) mandate: a mandate for an AI agent,
carried as OpenID4VP transaction data of type `plenipo_mandate`, which the person reads and approves
in the wallet and which a bank then verifies. It is a test build for the Plenipo sandbox, not a product,
and it is not endorsed by the European Commission. Licence: EUPL-1.2, as upstream.

## What changes

- `plenipo_mandate` is declared as a supported transaction data type next to the QES types
  (`WalletKitConfig.supportedTransactionDataTypes`); the wallet kit hands it over as raw JSON, mapped in
  `PlenipoMandateDomain`.
- The consent screen shows every field of the mandate that limits the agent: purpose, actions,
  counterparties (or "any"), limits per operation and in total, validity, delegation, the legal person
  when there is one, and the mandate id. The bank checks the hash of exactly these bytes. A mandate with
  a member this build does not know is not shown in part: the request is declined, as upstream does for
  transaction data it cannot display.
- The wallet kit authenticates relying parties only against the EU list of access certificate providers,
  which the Plenipo sandbox is not on, so `readerTrustPolicy` is `.warning`: an unlisted relying party is
  shown as not verified instead of being refused. Do not use this build with real credentials.
- The labels of the mandate rows are in English only.
- Still upstream: the bundle identifier and app name. They change with the first TestFlight build, under
  the Plenipo Apple Developer team.

## Build

GitHub Actions (`.github/workflows/plenipo-build.yml`, macOS 26 with Xcode 26) runs the mapping tests and
builds the dev scheme for the simulator; the zipped `.app` is a run artifact
(`xcrun simctl install booted <app>`). Locally: open `EudiReferenceWallet.xcodeproj` in Xcode 26
and run the "EUDI Wallet Dev" scheme.

## Try it

The same path worked with the Android fork on 15 November 2026 (plenipo-net/plenipo#44).

1. Download `plenipo-eudi-wallet-simulator.zip` from the latest `plenipo-v*` release, unzip it, open the
   Simulator (Xcode › Open Developer Tool › Simulator) with an iPhone on iOS 26 and drag the `.app` onto
   it, or run `xcrun simctl install booted <path to the .app>`.
2. Set the PIN, then Add document › under **issuer.eudiw.dev** › "PID Combined" › the country form ›
   Maria Rossi, 1984-03-12, IT (the sandbox accounts are Maria Rossi and Luca Bianchi, 1979-11-02).
3. Ask for a mandate: in Claude or another MCP client with the Plenipo sandbox MCP server, or from
   https://sandbox.plenipo.net. Open `https://platform.sandbox.plenipo.net/requests/<id>` in Safari on
   the simulator and tap "Open in a wallet on this device".
4. Choose **"PID (SD-JWT VC)"**, read the mandate and approve it **within 10 minutes** of the request.
   The relying party is shown as not verified (see above): that is expected with this build.
5. The agent's payments are then allowed or refused by the bank within the mandate.

Open points are tracked in https://github.com/plenipo-net/plenipo/issues/35.
