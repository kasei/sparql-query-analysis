//
//  Reporter.swift
//  
//
//  Created by Gregory Todd Williams on 10/11/23.
//

import Foundation
import SPARQLSyntax
import Rainbow

public typealias AlgebraIdentifier = (Algebra) -> (String, Int)?

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

func highlightedAlgebra(_ sparql : String, _ printAlgebra: Bool, _ predicate : @escaping AlgebraIdentifier) throws -> String? {
    var parser = SPARQLParser(string: sparql)!
    let q = try parser.parseQuery()
    let a = q.algebra
    
    var names = [Int: String]()
    var highlight = [Int: Set<ClosedRange<Int>>]()
    var algebraToTokens = [Algebra: Set<ClosedRange<Int>>]()
    let walkConfig = WalkConfig(type: WalkType(descendIntoAlgebras: true, descendIntoSubqueries: true, descendIntoExpressions: false), algebraHandler: { (algebra) in
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
    })
    try a.walk(config: walkConfig)

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

public enum ReportIdentifier {
    case algebra(AlgebraIdentifier)
    case tokenSet(Set<SPARQLToken>)
    case none
}

public protocol Reporter {
    var printIssues: Bool { get }
    var printSummary: Bool { get }
    func reportIssue(sparql: String, query: Query, algebra: Algebra, analyzer: Analyzer, code: String, message: String, identifier: ReportIdentifier) throws
}

class ConsoleReporter: Reporter {
    var printIssues: Bool
    var printSummary: Bool
    var summary: [String: Int]
    
    init(printIssues: Bool = true, printSummary: Bool = true) {
        self.printIssues = printIssues
        self.printSummary = printSummary
        self.summary = [:]
    }
    
    func reportIssue(sparql: String, query: Query, algebra: Algebra, analyzer: Analyzer, code: String, message: String, identifier: ReportIdentifier) throws {
        summary[analyzer.name, default: 0] += 1
        guard printIssues else { return }
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
    
    func reportSummary(queryCount: Int) {
        guard printSummary else { return }
        let total = summary.values.reduce(0, +)
        print("\(queryCount) total queries analyzed.")
        print("\(total) total issues found", terminator: "")
        print((total > 0) ? ":" : ".")
        for entry in summary.sorted(by: { $0.1 > $1.1 }) {
            let message = String(format: "%6d %@", entry.value, entry.key)
            print("- \(message)")
        }
    }
}

