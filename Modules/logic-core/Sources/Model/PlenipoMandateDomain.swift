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
import Foundation
import struct OpenID4VP.SupportedTransactionDataType

/// The transaction data type of a Plenipo mandate (https://plenipo.net).
public let plenipoMandateTransactionDataType = "plenipo_mandate"

public extension SupportedTransactionDataType {
  /// Declared next to the QES types; the wallet kit hands its payload over as raw JSON.
  static var plenipoMandate: Self { try! .init(type: .init(value: plenipoMandateTransactionDataType)) }
}

/// What an AI agent may do on the person's behalf. The bank checks the hash of the exact bytes, so every
/// field that limits the agent is shown; a mandate with a member this build does not know is not mapped,
/// and the request is declined rather than shown in part.
public struct PlenipoMandateDomain: Sendable, Equatable {
  public let mandateId: String
  public let purpose: String?
  public let actions: [String]
  /// Empty when any counterparty is allowed.
  public let counterparties: [String]
  public let limits: PlenipoLimitsDomain?
  /// Seconds since the epoch.
  public let notBefore: Int64
  public let expiresAt: Int64
  /// Nil when the agent may not delegate.
  public let maxDelegationDepth: Int?
  public let legalPrincipal: PlenipoLegalPrincipalDomain?
  public let transactionDataHashAlgorithms: [String]

  public init(
    mandateId: String,
    purpose: String?,
    actions: [String],
    counterparties: [String],
    limits: PlenipoLimitsDomain?,
    notBefore: Int64,
    expiresAt: Int64,
    maxDelegationDepth: Int?,
    legalPrincipal: PlenipoLegalPrincipalDomain?,
    transactionDataHashAlgorithms: [String]
  ) {
    self.mandateId = mandateId
    self.purpose = purpose
    self.actions = actions
    self.counterparties = counterparties
    self.limits = limits
    self.notBefore = notBefore
    self.expiresAt = expiresAt
    self.maxDelegationDepth = maxDelegationDepth
    self.legalPrincipal = legalPrincipal
    self.transactionDataHashAlgorithms = transactionDataHashAlgorithms
  }
}

/// Amounts in ISO 4217 minor units.
public struct PlenipoLimitsDomain: Sendable, Equatable {
  public let currency: String
  public let perOperation: Int64?
  public let total: Int64?
}

public struct PlenipoLegalPrincipalDomain: Sendable, Equatable {
  public let euid: String
  public let role: String?
}

private let mandateMembers: Set<String> = [
  "v", "id", "agent", "actions", "counterparties", "limits", "nbf", "exp", "delegation", "purpose", "status", "principal"
]
private let transactionMembers: Set<String> = ["type", "credential_ids", "transaction_data_hashes_alg", "mandate"]

public extension PlenipoMandateDomain {

  /// Nil when `jsonData` is not a `plenipo_mandate` this build can show in full.
  init?(jsonData: Data?) {
    guard
      let jsonData,
      let tx = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any],
      tx["type"] as? String == plenipoMandateTransactionDataType,
      Set(tx.keys).isSubset(of: transactionMembers),
      let mandate = tx["mandate"] as? [String: Any],
      Set(mandate.keys).isSubset(of: mandateMembers),
      Self.integer(mandate["v"]) == 1,
      let id = mandate["id"] as? String,
      let actions = Self.strings(mandate["actions"]), !actions.isEmpty,
      let nbf = Self.integer(mandate["nbf"]),
      let exp = Self.integer(mandate["exp"]), exp > nbf
    else { return nil }

    if mandate["purpose"] != nil && !(mandate["purpose"] is String) { return nil }
    var counterparties: [String] = []
    if let raw = mandate["counterparties"] {
      guard let list = Self.strings(raw), !list.isEmpty else { return nil }
      counterparties = list
    }
    var limits: PlenipoLimitsDomain?
    if let raw = mandate["limits"] {
      guard
        let l = raw as? [String: Any],
        Set(l.keys).isSubset(of: ["currency", "per_operation", "total"]),
        let currency = l["currency"] as? String,
        currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil
      else { return nil }
      var perOperation: Int64?
      if let value = l["per_operation"] {
        guard let amount = Self.integer(value), amount >= 0 else { return nil }
        perOperation = amount
      }
      var total: Int64?
      if let value = l["total"] {
        guard let amount = Self.integer(value), amount >= 0 else { return nil }
        total = amount
      }
      limits = PlenipoLimitsDomain(currency: currency, perOperation: perOperation, total: total)
    }
    var depth: Int?
    if let raw = mandate["delegation"] {
      guard let d = raw as? [String: Any], Set(d.keys) == ["max_depth"], let value = Self.integer(d["max_depth"]), value >= 0 else {
        return nil
      }
      depth = Int(value)
    }
    var principal: PlenipoLegalPrincipalDomain?
    if let raw = mandate["principal"] {
      guard
        let p = raw as? [String: Any],
        Set(p.keys).isSubset(of: ["type", "euid", "role"]),
        p["type"] as? String == "legal_person",
        let euid = p["euid"] as? String
      else { return nil }
      if p["role"] != nil && !(p["role"] is String) { return nil }
      principal = PlenipoLegalPrincipalDomain(euid: euid, role: p["role"] as? String)
    }
    var hashAlgorithms: [String] = []
    if let raw = tx["transaction_data_hashes_alg"] {
      guard let list = Self.strings(raw) else { return nil }
      hashAlgorithms = list
    }
    self.init(
      mandateId: id,
      purpose: mandate["purpose"] as? String,
      actions: actions,
      counterparties: counterparties,
      limits: limits,
      notBefore: nbf,
      expiresAt: exp,
      maxDelegationDepth: depth,
      legalPrincipal: principal,
      transactionDataHashAlgorithms: hashAlgorithms
    )
  }

  /// An integral JSON number; booleans and fractions are refused.
  private static func integer(_ value: Any?) -> Int64? {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
    let integral = number.int64Value
    return number.doubleValue == Double(integral) && number.stringValue.range(of: ".") == nil ? integral : nil
  }

  private static func strings(_ value: Any?) -> [String]? {
    guard let array = value as? [Any] else { return nil }
    let strings = array.compactMap { $0 as? String }
    return strings.count == array.count ? strings : nil
  }
}
