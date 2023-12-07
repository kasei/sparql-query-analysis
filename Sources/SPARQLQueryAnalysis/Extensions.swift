//
//  Extensions.swift
//  
//
//  Created by Gregory Todd Williams on 10/11/23.
//

import Foundation
import SPARQLSyntax

extension SPARQLSerializer {
    public enum HightlightState {
        case normal
        case highlighted
    }
    public typealias Highlighter = (String, HightlightState) -> String
    public typealias HighlighterMap = [Set<ClosedRange<Int>>: (String, Highlighter)]
    
    public func reformatHighlightingTokens(_ sparql: String, tokens: Set<SPARQLToken>) -> String {
        let sparql = prettyPrint ? reformat(sparql) : sparql

        // compute the set of tokens (by their token number) that should be highlighted
        var highlightedChars = [(ClosedRange<Int>, String, Highlighter)]()
        guard let data = sparql.data(using: .utf8) else {
            return sparql
        }
        let stream = InputStream(data: data)
        
        // compute the characters in the sparql string that should be highlighted
        stream.open()
        var charRanges = [(Int, ClosedRange<Int>)]()
        do {
            let lexer = try SPARQLLexer(source: stream)
            while let t = try lexer.getToken() {
                if tokens.contains(t.token) {
                    let range = Int(t.startCharacter)...Int(t.endCharacter)
                    if charRanges.isEmpty {
                        charRanges.append((t.tokenNumber, range))
                    } else {
                        let tuple = charRanges.last!
                        if (tuple.0+1) == t.tokenNumber {
                            // coalesce
                            let tuple = charRanges.removeLast()
                            let r = tuple.1
                            let rr = r.lowerBound...range.upperBound
                            charRanges.append((t.tokenNumber, rr))
                        } else {
                            charRanges.append((t.tokenNumber, range))
                        }
                    }
                }
            }
        } catch {}
        
        let highlighter = makeHighlighter(color: \.red)
        let ranges = charRanges.map { (tuple) in return (tuple.1, "Highlighted", highlighter) }
        highlightedChars.append(contentsOf: ranges)

        // reverse sort so that we insert color-codes back-to-front and the offsets don't shift underneath us
        // note this will not work if the ranges are overlapping
        highlightedChars.sort { $0.0.lowerBound > $1.0.lowerBound }

        // for each highlighted character range, replace the substring with one that has .red color codes inserted
        var highlighted = sparql
        
        var names = Set<String>()
        for (range, name, highlight) in highlightedChars {
            names.insert(highlight(name, .highlighted))
            // TODO: instead of highlighting by subrange replacement, break the string in to all sub-ranges (both highlighted and non-highlighted)
            // and call the highlighter for all the ranges and just concatenate them to preduce the result.
            let start = sparql.index(sparql.startIndex, offsetBy: range.lowerBound)
            let end = sparql.index(sparql.startIndex, offsetBy: range.upperBound)
            let stringRange = start..<end
            let s = String(highlighted[stringRange])
            let h = highlight(s, .highlighted)
            highlighted.replaceSubrange(stringRange, with: h)
        }
        return highlighted

    }
    
    public func reformatHighlightingRanges(_ sparql: String, highlighterMap: HighlighterMap) -> (String, Set<String>?) {
        let sparql = prettyPrint ? reformat(sparql) : sparql
        
        // compute the set of tokens (by their token number) that should be highlighted
        var highlightedChars = [(ClosedRange<Int>, String, Highlighter)]()
        for (ranges, highlighterTuple) in highlighterMap {
            var highlightedTokens = Set<Int>()
            for range in ranges {
                for i in range {
                    highlightedTokens.insert(i)
                }
            }
            
            guard let data = sparql.data(using: .utf8) else {
                return (sparql, nil)
            }
            let stream = InputStream(data: data)
            
            // compute the characters in the sparql string that should be highlighted
            stream.open()
            var charRanges = [(Int, ClosedRange<Int>)]()
            do {
                let lexer = try SPARQLLexer(source: stream)
                while let t = try lexer.getToken() {
                    if highlightedTokens.contains(t.tokenNumber) {
                        let range = Int(t.startCharacter)...Int(t.endCharacter)
                        if charRanges.isEmpty {
                            charRanges.append((t.tokenNumber, range))
                        } else {
                            let tuple = charRanges.last!
                            if (tuple.0+1) == t.tokenNumber {
                                // coalesce
                                let tuple = charRanges.removeLast()
                                let r = tuple.1
                                let rr = r.lowerBound...range.upperBound
                                charRanges.append((t.tokenNumber, rr))
                            } else {
                                charRanges.append((t.tokenNumber, range))
                            }
                        }
                    }
                }
            } catch {}
            let name = highlighterTuple.0
            highlightedChars.append(contentsOf: charRanges.map { ($0.1, name, highlighterTuple.1) })
        }
        
        // reverse sort so that we insert color-codes back-to-front and the offsets don't shift underneath us
        // note this will not work if the ranges are overlapping
        highlightedChars.sort { $0.0.lowerBound > $1.0.lowerBound }

        // for each highlighted character range, replace the substring with one that has .red color codes inserted
        var highlighted = sparql
        
        var names = Set<String>()
        for (range, name, highlight) in highlightedChars {
            names.insert(highlight(name, .highlighted))
            // TODO: instead of highlighting by subrange replacement, break the string in to all sub-ranges (both highlighted and non-highlighted)
            // and call the highlighter for all the ranges and just concatenate them to preduce the result.
            let start = sparql.index(sparql.startIndex, offsetBy: range.lowerBound)
            let end = sparql.index(sparql.startIndex, offsetBy: range.upperBound)
            let stringRange = start..<end
            let s = String(highlighted[stringRange])
            let h = highlight(s, .highlighted)
            highlighted.replaceSubrange(stringRange, with: h)
        }
        return (highlighted, names)
    }
}
