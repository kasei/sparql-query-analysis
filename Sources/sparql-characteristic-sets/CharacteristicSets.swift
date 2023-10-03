//
//  CharacteristicSets.swift
//  SPARQLAnalysis
//
//  Created by Gregory Todd Williams on 5/5/20.
//

import Foundation
import Kineo
import SPARQLSyntax


func starsFromBGP(_ bgp: [TriplePattern]) -> [[TriplePattern]] {
    var stars = [String: [TriplePattern]]()
    for t in bgp {
        if case .variable(let v, binding: _) = t.subject {
            stars[v, default: []].append(t)
        }
    }
    
    let v = Array(stars.values)
    return v
}

public func characteristicSets(from algebra: Algebra) throws -> [CharacteristicSet] {
    var bgps = [[TriplePattern]]()
    try algebra.walk { (a) in
        if case .bgp(let tp) = a {
            let stars = starsFromBGP(tp)
            bgps.append(contentsOf: stars)
        }
    }
    
    let cs = bgps.map { (bgp) in
        return bgp.map { $0.predicate }.compactMap { (node) -> Term? in
            if case .bound(let term) = node {
                return term
            } else {
                return nil
            }
        }
    }
    let nonEmpty = cs.filter { !$0.isEmpty }
    return nonEmpty.map { CharacteristicSet(predicates: $0) }
}

public struct CharacteristicSet: Codable {
    var count: Int
var hasMultiple: Bool
    var predCounts: [Term: Int]
    
    init(predicates: [Term]) {
        self.count = 0
        let preds = Set(predicates)
        self.hasMultiple = preds.count != predicates.count
        self.predCounts = Dictionary(uniqueKeysWithValues: preds.map { ($0, 1) })
    }

    init(predicates: [Term], count: Int, predCounts: [Term: Int]) {
        self.count = count
        let preds = Set(predicates)
        self.hasMultiple = preds.count != predicates.count
        self.predCounts = predCounts
    }

    var predicates: Set<Term> {
        return Set(predCounts.keys)
    }
    
    func isSuperset(of subset: CharacteristicSet) -> Bool {
        return predicates.isSuperset(of: subset.predicates)
    }
}

extension CharacteristicSet: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "CharacteristicSet(\(count); \(predicates.sorted()))"
    }
}
