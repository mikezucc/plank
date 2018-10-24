//
//  JavaIR.swift
//  Core
//
//  Created by Rahul Malik on 1/4/18.
//

import Foundation

struct JavaModifier: OptionSet {
    let rawValue: Int
    static let `public` = JavaModifier(rawValue: 1 << 0)
    static let abstract = JavaModifier(rawValue: 1 << 1)
    static let final = JavaModifier(rawValue: 1 << 2)
    static let `static` = JavaModifier(rawValue: 1 << 3)
    static let `private` = JavaModifier(rawValue: 1 << 4)

    func render() -> String {
        return [
            self.contains(.`public`) ? "public" : "",
            self.contains(.abstract) ? "abstract" : "",
            self.contains(.`static`) ? "static" : "",
            self.contains(.final) ? "final" : "",
            self.contains(.`private`) ? "private" : ""
        ].filter { $0 != "" }.joined(separator: " ")
    }
}

public struct JavaIR {

    public struct Method {
        let annotations: Set<String>
        let modifiers: JavaModifier
        let body: [String]
        let signature: String

        func render() -> [String] {
            // HACK: We should actually have an enum / optionset that we can check for abstract, static, ...
            let annotationLines = annotations.map { "@\($0)" }

            if modifiers.contains(.abstract) {
                return annotationLines + ["\(modifiers.render()) \(signature);"]
            }
            return annotationLines + [
                "\(modifiers.render()) \(signature) {",
                -->body,
                "}"
            ]
        }
    }

    public struct Property {
        let modifiers: JavaModifier
        let type: String
        let name: String
        func render() -> String {
            return "\(modifiers.render()) \(type) \(name);"
        }
    }

    static func method(annotations: Set<String> = [], _ modifiers: JavaModifier, _ signature: String, body: () -> [String]) -> JavaIR.Method {
        return JavaIR.Method(annotations: annotations, modifiers: modifiers, body: body(), signature: signature)
    }

    struct Enum {
        let name: String
        let values: EnumType

        func render() -> [String] {
            switch values {
            case let .integer(values):
                let names = values
                    .map { ($0.description.uppercased(), $0.defaultValue) }
                    .map { "int \($0.0) = \($0.1);" }
                let defAnnotationNames = values
                    .map { "\(name).\($0.description.uppercased())" }
                    .joined(separator: ", ")
                return [
                    "@Retention(RetentionPolicy.SOURCE)",
                    "@IntDef({\(defAnnotationNames)})",
                    "public @interface \(name) {",
                    -->names,
                    "}"
                ]
            case let .string(values, defaultValue: _):
                // TODO: Use default value in builder method to specify what our default value should be
                let names = values
                    .map { ($0.description.uppercased(), $0.defaultValue) }
                    .map { "String \($0.0) = \"\($0.1)\";" }
                let defAnnotationNames = values
                    .map { "\(name).\($0.description.uppercased())" }
                    .joined(separator: ", ")
                return [
                    "@Retention(RetentionPolicy.SOURCE)",
                    "@StringDef({\(defAnnotationNames)})",
                    "public @interface \(name) {",
                    -->names,
                    "}"
                ]
            }
        }
    }

    struct Class {
        let annotations: Set<String>
        let modifiers: JavaModifier
        let extends: String?
        let implements: [String]? // Should this be JavaIR.Interface?
        let name: String
        let methods: [JavaIR.Method]
        let enums: [Enum]
        let innerClasses: [JavaIR.Class]
        let properties: [JavaIR.Property]

        func render() -> [String] {
            let implementsList = implements?.joined(separator: ", ") ?? ""
            let implementsStmt = implementsList == "" ? "" : "implements \(implementsList)"
            return annotations.map { "@\($0)" } + [
                "\(modifiers.render()) class \(name) \(implementsStmt) {",
                -->enums.flatMap { $0.render() },
                -->properties.map { $0.render() },
                -->methods.flatMap { $0.render() },
                -->innerClasses.flatMap { $0.render() },
                "}"
            ]
        }
    }

    struct Interface {
        let modifiers: JavaModifier
        let extends: String?
        let name: String
        let methods: [JavaIR.Method]

        func render() -> [String] {
            let extendsStmt = extends.map { "extends \($0) " } ?? ""
            return [
                "\(modifiers.render()) interface \(name) \(extendsStmt){",
                -->methods.map { "\($0.signature);" },
                "}"
            ]
        }
    }

    enum Root: RootRenderer {
        case packages(names: Set<String>)
        case imports(names: Set<String>)
        case classDecl(aClass: JavaIR.Class)
        case interfaceDecl(aInterface: JavaIR.Interface)

        func humanReadableString() -> [String] {
            return [String(describing: self)]
        }

        func renderImplementation(generationParameters: GenerationParameters) -> [String] {
            var generatedSource = [String]()
            
            if let debugString = debugStatement(generationParameters: generationParameters, language: .java) {
                generatedSource += debugString
            }

            switch self {
            case let .packages(names):
                generatedSource += names.sorted().map { "package \($0);" }
            case let .imports(names):
                generatedSource += names.sorted().map { "import \($0);" }
            case let .classDecl(aClass: cls):
                generatedSource += cls.render()
            case let .interfaceDecl(aInterface: interface):
                generatedSource += interface.render()
            }

            return generatedSource
        }
    }
}
