/*
 * Copyright (c) 2026 Plenipo contributors
 *
 * Licensed under the EUPL, Version 1.2 or - as soon they will be approved by the European
 * Commission - subsequent versions of the EUPL (the "Licence"); You may not use this work
 * except in compliance with the Licence.
 *
 * You may obtain a copy of the Licence at:
 * https://joinup.ec.europa.eu/software/page/eupl
 *
 * Unless required by applicable law or agreed to in writing, software distributed under
 * the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF
 * ANY KIND, either express or implied. See the Licence for the specific language
 * governing permissions and limitations under the Licence.
 */
import XCTest
@testable import logic_core

final class TestPlenipoMandateDomain: XCTestCase {

  private func data(_ mandate: String, extra: String = "") -> Data {
    Data(#"{"type":"plenipo_mandate","credential_ids":["pid"],"transaction_data_hashes_alg":["sha-256"]\#(extra),"mandate":\#(mandate)}"#.utf8)
  }

  private let base = #""v":1,"id":"x","agent":{"jwk":{}},"actions":["a"],"nbf":1,"exp":2"#

  func testMapsEveryField() {
    let mandate = #"""
    {"v":1,"id":"6f1c","agent":{"jwk":{"kty":"EC"}},"actions":["payments.transfer","accounts.read"],
     "counterparties":["lumen-energia.example"],"limits":{"currency":"EUR","per_operation":15000,"total":40000},
     "nbf":1763000000,"exp":1765592000,"delegation":{"max_depth":1},"purpose":"Pay the electricity bill",
     "status":{"status_list":{"uri":"https://p.example/s","idx":3}},
     "principal":{"type":"legal_person","euid":"IT.CCIAA.RM123","role":"director"}}
    """#
    XCTAssertEqual(
      PlenipoMandateDomain(jsonData: data(mandate)),
      PlenipoMandateDomain(
        mandateId: "6f1c",
        purpose: "Pay the electricity bill",
        actions: ["payments.transfer", "accounts.read"],
        counterparties: ["lumen-energia.example"],
        limits: .init(currency: "EUR", perOperation: 15000, total: 40000),
        notBefore: 1763000000,
        expiresAt: 1765592000,
        maxDelegationDepth: 1,
        legalPrincipal: .init(euid: "IT.CCIAA.RM123", role: "director"),
        transactionDataHashAlgorithms: ["sha-256"]
      )
    )
  }

  func testMinimalMandateAllowsAnyCounterpartyAndNoDelegation() {
    let mapped = PlenipoMandateDomain(jsonData: data("{\(base)}"))
    XCTAssertEqual(mapped?.counterparties, [])
    XCTAssertNil(mapped?.limits)
    XCTAssertNil(mapped?.maxDelegationDepth)
  }

  func testDeclinesWhatItCannotShowInFull() {
    let refused = [
      data("{\(base),\"scope_extra\":true}"),
      data("{\(base)}", extra: #","note":"x""#),
      data(#"{\#(base),"limits":{"currency":"EUR","daily":5}}"#),
      data(#"{\#(base),"limits":{"currency":"EUR","total":"5"}}"#),
      data(#"{\#(base),"limits":{"currency":"EUR","total":-5}}"#),
      data(#"{\#(base),"limits":{"currency":"EUR","total":true}}"#),
      data(#"{\#(base),"counterparties":[]}"#),
      data(#"{"v":2,"id":"x","agent":{},"actions":["a"],"nbf":1,"exp":2}"#),
      data(#"{"v":1,"id":"x","agent":{},"actions":[],"nbf":1,"exp":2}"#),
      data(#"{"v":1,"id":"x","agent":{},"actions":["a"],"nbf":5,"exp":2}"#),
      data(#"{"v":1,"id":"x","agent":{},"actions":["a"],"nbf":1.5,"exp":2}"#),
      Data(#"{"type":"qes_approval"}"#.utf8),
    ]
    for json in refused {
      XCTAssertNil(PlenipoMandateDomain(jsonData: json), String(decoding: json, as: UTF8.self))
    }
  }
}
