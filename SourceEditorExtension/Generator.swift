//
//  Created by Smirnov Maxim on 29/11/2018.
//  Copyright © 2018 Smirnov Maxim. All rights reserved.
//

import Foundation

enum GenerationError: Swift.Error {
    case notSwiftLanguage
    case noSelection
    case invalidSelection
    case parseError
}

let accessModifiers = ["open", "public", "internal", "private", "fileprivate"]

struct Variable {

    let name: String
    let type: String
    let isMutable: Bool

    var containsDefaultValue: Bool {
        return type.contains("=")
    }
    var isComputed: Bool {
        return type.contains(" {")
    }
}

extension Variable {
    var needToSkipInInitGeneration: Bool {
        if !isMutable, containsDefaultValue {
            return true
        }

        if isComputed {
            return true
        }

        return false
    }
}

func generate(selection: [String], indentation: String, leadingIndent: String) throws -> [String] {
    var variables: [Variable] = []

    for line in selection {
        let scanner = Scanner(string: line)

        var weak = scanner.scanString("weak", into: nil)
        for modifier in accessModifiers {
            if scanner.scanString(modifier, into: nil) {
                break
            }
        }
        for modifier in accessModifiers {
            if scanner.scanString(modifier, into: nil) {
                guard let _ = scanner.scanUpTo(")"), let _ = scanner.scanString(")") else {
                    throw GenerationError.parseError
                }
            }
        }
        weak = weak || scanner.scanString("weak", into: nil)

        let isMutable = line.contains("var")
        guard scanner.scanString("let", into: nil) ||
            scanner.scanString("var", into: nil) ||
            scanner.scanString("dynamic var", into: nil) else {
                continue
        }
        guard let variableName = scanner.scanUpTo(":"),
            scanner.scanString(":", into: nil),
            let variableType = scanner.scanUpTo("\n") else {
                throw GenerationError.parseError
        }
        variables.append(Variable(name: variableName, type: variableType, isMutable: isMutable))
    }

    variables = variables.filter { !$0.needToSkipInInitGeneration }
    guard !variables.isEmpty else {
        return ["public init() { }"]
    }

    let generatedInit = generateInit(variables.map(argument))
    let expressions = variables.map { expression(variable: $0, indentation: indentation) }
    let lines = (generatedInit + expressions + ["}"]).map { "\(leadingIndent)\($0)" }

    return lines
}

private func expression(variable: Variable, indentation: String) -> String {

    if variable.name.first == "_" {
        var name = variable.name
        name.removeFirst()
        return "\(indentation)\(variable.name) = \(name)"
    }

    return "\(indentation)self.\(variable.name) = \(variable.name)"
}

private func argument(variable: Variable) -> String {

    var name = variable.name
    if variable.name.first == "_" {
        name.removeFirst()
    }

    return "\(name): \(addEscapingAttributeIfNeeded(to: variable.type))"
}

private func generateInit(_ arguments: [String]) -> [String] {

    guard arguments.joined(separator: ", ").count > 80 else {
        return ["public init(" + arguments.joined(separator: ", ") + ") {"]
    }

    var indent: String = ""
    "public init(".forEach { _ in
        indent.append(" ")
    }

    var result: [String] = []

    for (i, argument) in arguments.enumerated() {

        if i == 0 {
            var line = "public init(" + argument
            if arguments.count != 1 {
                line.append(",")
            } else {
                line.append(") {")
            }
            result.append(line)
            continue
        }

        if i == (arguments.count - 1) {
            result.append(indent + argument + ") {")
            continue
        }

        result.append(indent + argument + ",")
    }

    return result
}

private func addEscapingAttributeIfNeeded(to typeString: String) -> String {
    let predicate = NSPredicate(format: "SELF MATCHES %@", "\\(.*\\)->.*")
    if predicate.evaluate(with: typeString.replacingOccurrences(of: " ", with: "")),
        !isOptional(typeString: typeString) {
        return "@escaping " + typeString
    } else {
        return typeString
    }
}

private func isOptional(typeString: String) -> Bool {
    guard typeString.hasSuffix("!") || typeString.hasSuffix("?") else {
        return false
    }
    var balance = 0
    var indexOfClosingBraceMatchingFirstOpenBrace: Int?

    for (index, character) in typeString.enumerated() {
        if character == "(" {
            balance += 1
        } else if character == ")" {
            balance -= 1
        }
        if balance == 0 {
            indexOfClosingBraceMatchingFirstOpenBrace = index
            break
        }
    }

    return indexOfClosingBraceMatchingFirstOpenBrace == typeString.count - 2
}
