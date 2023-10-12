//
//  File.swift
//
//
//  Created by Gregory Todd Williams on 10/11/23.
//

import SPARQLSyntax

public struct UnboundFilterVariableAnalyzer: Analyzer {
    public let name = "UnboundFilterVariable"
    public var description = "Finds filter expressions which use variables not in-scope."
    
    func analyze(sparql: String, query: SPARQLSyntax.Query, algebra: SPARQLSyntax.Algebra, reporter: Reporter) throws -> Int {
        guard var p = SPARQLParser(string: sparql) else { fatalError("Failed to construct SPARQL parser") }
        let a = try p.parseAlgebra()
        var count = 0
        try a.walk { (algebra) in
            switch algebra {
            case let .filter(child, expr):
                let evars = expr.variables
                let inscope = child.inscope
                let unbound = evars.subtracting(inscope)
                if !unbound.isEmpty {
                    let identifier : Reporter.Identifier = .tokenSet(Set(unbound.map{ ._var($0) }))
                    let message: String
                    if unbound.count == 1 {
                        let v = unbound.first!
                        message = "Variable will be unbound in FILTER evaluation: \(v)"
                    } else {
                        message = "Variables will be unbound in FILTER evaluation: " + unbound.joined(separator: ", ")
                    }
                    
                    try reporter.reportIssue(sparql: sparql, query: query, algebra: algebra, analyzer: self, code: "1", message: message, identifier: identifier)
                    count += 1
                }
            default:
                break
            }
        }
        return count
    }

}
