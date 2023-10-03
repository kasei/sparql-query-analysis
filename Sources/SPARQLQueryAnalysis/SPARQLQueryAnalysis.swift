import Foundation
import SPARQLSyntax

public enum CLIError : Error {
    case error(String)
}

func string(fromFileOrString qfile: String) throws -> (String, String?) {
    let url = URL(fileURLWithPath: qfile)
    let string: String
    var base: String? = nil
    if case .some(true) = try? url.checkResourceIsReachable() {
        string = try String(contentsOf: url)
        base = url.absoluteString
    } else {
        string = qfile
    }
    return (string, base)
}

public struct QueryAnalysis {
    public init() {}
    
    @discardableResult
    public func forEachQuery<T>(_ handler: (Int, String, Set<String>, [String:String]) throws -> T) throws -> [T] {
        let argscount = CommandLine.arguments.count
        let args = CommandLine.arguments
        guard let pname = args.first else { fatalError("Missing command name") }
        if argscount == 1 {
            print("Takes a SPARQL query as input and prints as output all property paths")
            print("used in the query's graph patterns.")
            print("")
            print("Usage: \(pname) [FLAGS] 'SELECT * WHERE ...'")
            print("")
            print("Flags:")
            print("  -c    Read queries from standard input (one per line)")
            print("  -d    URL-decode the query before parsing")
            print("  -r    Rewrite the IRIs used in the path to canonical values")
            print("")
            exit(1)
        }

        var stdin = false
        var unescape = false
        let argsArray = args.dropFirst()
        var extargs = [String:String]()
        var extflags = Set<String>()
        var i = argsArray.startIndex
        while i != argsArray.endIndex {
            let f = argsArray[i]
            i = argsArray.index(after: i)
            guard f.hasPrefix("-") else { break }
            if f == "--" { break }

            switch f {
            case "-c":
                stdin = true
            case "-d":
                unescape = true
            default:
                if f.hasPrefix("--") {
                    extargs[f] = argsArray[i]
                    i = argsArray.index(after: i)
                } else {
                    extflags.insert(f)
                }
            }
        }

        let unescapeQuery : (String) throws -> String = unescape ? { (escaped) in
        //    let sparql = String(escaped.map { $0 == "+" ? " " : $0 })
            let sparql = escaped.replacingOccurrences(of: "+", with: " ")
            if let s = sparql.removingPercentEncoding {
                return s
            } else {
                let e = CLIError.error("Failed to URL percent decode SPARQL query")
                throw e
            }
        } : { $0 }

        if stdin {
            var lineno = 0
            var results = [T]()
            while let line = readLine() {
                lineno += 1
                try autoreleasepool {
                    let sparql = try unescapeQuery(line)
                    if !sparql.isEmpty && !sparql.hasPrefix("#") {
                        let r = try handler(lineno, sparql, extflags, extargs)
                        results.append(r)
                    }
                }
            }
            return results
        } else {
            guard let arg = args.last else { fatalError("Missing query") }
            let (query, _) = try string(fromFileOrString: arg)
            let sparql = try unescapeQuery(query)
            let r = try handler(1, sparql, extflags, extargs)
            return [r]
        }
    }
}

