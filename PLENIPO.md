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

1. Install the app on the iOS simulator or, once TestFlight is set up, on an iPhone, and add a PID from the EU test issuer in SD-JWT VC
   format (`urn:eudi:pid:1`). The sandbox accounts are Maria Rossi (1984-03-12) and Luca Bianchi
   (1979-11-02): enter one of them as test identity data.
2. In Claude or another MCP client, connect the Plenipo sandbox MCP server and ask the agent to request
   a mandate; or open https://sandbox.plenipo.net and start a request from the platform.
3. Open the request link (`openid4vp://` or `eudi-openid4vp://authorize?...`) on the device, or scan the
   QR code on the request page, read the mandate and approve it.
4. The agent's payments are then allowed or refused by the bank within the mandate.

Open points are tracked in https://github.com/plenipo-net/plenipo/issues/35.
