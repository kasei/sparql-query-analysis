//
//  File.swift
//  
//
//  Created by Gregory Todd Williams on 10/11/23.
//

import Foundation
import SPARQLSyntax
import Rainbow

typealias AlgebraIdentifier = (Algebra) -> (String, Int)?

func makeHighlighter(color: KeyPath<String, String>) -> SPARQLSerializer.Highlighter {
    return { (s, state) in
        if case .highlighted = state {
            return s[keyPath: color]
        } else {
            return s
        }
    }
}

func color(for value: Int) -> KeyPath<String, String> {
    let colors : [KeyPath<String, String>] = [\.red, \.yellow, \.green, \.blue, \.magenta]
    return colors[value % colors.count]
}

func highlightedAlgebra(_ sparql : String, _ printAlgebra: Bool, _ predicate : AlgebraIdentifier) throws -> String? {
    var parser = SPARQLParser(string: sparql)!
    let q = try parser.parseQuery()
    let a = q.algebra
    
    var names = [Int: String]()
    var highlight = [Int: Set<ClosedRange<Int>>]()
    var algebraToTokens = [Algebra: Set<ClosedRange<Int>>]()
    try a.walkWithSubqueries { (algebra) in
        let ranges = parser.getTokenRange(for: algebra)
        
        // HIGHLIGHT AGGREGATIONS IN THE OUTPUT
        if let tuple = predicate(algebra) {
            let name = tuple.0
            let i = tuple.1
            names[i] = name
            for r in ranges {
                highlight[i, default: []].insert(r)
            }
        }
        
        if ranges.isEmpty {
//            print("*** No range for algebra: \(algebra.serialize())")
//            print("--- \n\(sparql)\n--- \n")
        } else {
            algebraToTokens[algebra] = ranges
        }
    }

    if !highlight.isEmpty {
        let ser = SPARQLSerializer(prettyPrint: true)
        let highlighterMap = Dictionary(uniqueKeysWithValues: highlight.map {
            let name = names[$0.key] ?? "\($0.key)"
            let highlighter = makeHighlighter(color: color(for: $0.key))
            return ($0.value, (name, highlighter))
        })

        var result = ""
        let (h, _) = ser.reformatHighlightingRanges(sparql, highlighterMap: highlighterMap)
//        if let names = names {
//            for name in names.sorted() {
//                result += "- \(name)\n"
//            }
//        }
//        result += "\n"
        result += h
        if printAlgebra {
            result += a.serialize()
        }
        return result
    }
    return nil
}

struct Reporter {
    enum Identifier {
        case algebra(AlgebraIdentifier)
        case tokenSet(Set<SPARQLToken>)
        case none
    }
    
    func reportIssue(sparql: String, query: Query, algebra: Algebra, analyzer: Analyzer, code: String, message: String, identifier: Identifier) throws {
        let issue = "ISSUE".red
        print("\(issue): \(analyzer.name): \(message)")
        switch identifier {
        case .algebra(let i):
            let printAlgebra = false
            if let serialized = try highlightedAlgebra(sparql, printAlgebra, i) {
                print(serialized)
            }
        case .tokenSet(let tokens):
            let s = SPARQLSerializer(prettyPrint: true)
            print(s.reformatHighlightingTokens(sparql, tokens: tokens))
        case .none:
            break
        }
    }
}
