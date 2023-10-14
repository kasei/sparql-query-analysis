//
//  File.swift
//  
//
//  Created by Gregory Todd Williams on 10/11/23.
//

import SPARQLSyntax

extension Algebra {
    var isOrdered: Bool {
        switch self {
        case .unionIdentity, .joinIdentity, .table, .quad, .triple, .bgp, .innerJoin, .leftOuterJoin, .union:
            return false
        case .namedGraph, .minus, .service, .path, .aggregate, .window:
            return false
        case .filter(let c, _), .project(let c, _), .extend(let c, _, _), .distinct(let c), .reduced(let c), .slice(let c, _, _):
            return c.isOrdered
        case .subquery(let q):
            return q.algebra.isOrdered
        case .order:
            return true
        }
    }
}

extension Query {
    var isOrderedWithoutSlice: Bool {
        if !algebra.isOrdered { return false }
        switch self.algebra {
        case .slice, .project(.slice, _):
            return false
        default:
            return true
        }
    }
}

public struct SubquerySortAnalyzer: Analyzer {
    public let name = "SubqueryWithSort"
    public var description = "Finds subqueries that have useless sorting applied."
    
    func analyze(sparql: String, query: SPARQLSyntax.Query, algebra: SPARQLSyntax.Algebra, reporter: Reporter) throws -> Int {
        var count = 0
        try algebra.walk { (algebra) in
            switch algebra {
            case .subquery(let q) where q.isOrderedWithoutSlice:
                var sort: Algebra? = nil
                try q.algebra.walk { if case .order = $0 { sort = $0 } }
                
                var identifier : Reporter.Identifier = .none
                if let sort {
                    identifier = .algebra({
                        if $0 == sort {
                            return ("Issue", 0)
                        }
                        return nil
                    })
                }
                
                try reporter.reportIssue(sparql: sparql, query: query, algebra: algebra, analyzer: self, code: "1", message: "found subquery with useless sorting", identifier: identifier)
//                let ser = SPARQLSerializer()
//                print(ser.reformat(sparql))
                count += 1
            default:
                break
            }
        }
        return count
    }

}
