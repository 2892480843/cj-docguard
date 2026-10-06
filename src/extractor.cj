package docguard

import std.ast.*
import std.collection.*

// AST positions are one-based UTF-8 byte columns, not character indexes.
private class ApiExtractor {
    let bytes: Array<Byte>
    let path: String
    let lineStarts = ArrayList<Int64>([0])
    let result = J.obj().put("symbols", J.arr()).put("diagnostics", J.arr())
        .put("imports", J.arr()).put("package", J.str("")).put("status", J.str("OK"))
    var packageName = ""
    var partial = false

    init(source: String, path: String) {
        bytes = source.toArray()
        this.path = path
        for (i in 0..bytes.size) { if (bytes[i] == 10) { lineStarts.add(i + 1) } }
    }

    func offset(p: Position): Int64 {
        let line = Int64(p.line)
        let col = Int64(p.column)
        if (line < 1 || line > lineStarts.size || col < 1) { return -1 }
        let index = lineStarts[line - 1] + col - 1
        if (index > bytes.size) { return -1 }
        return index
    }

    func slice(start: Position, end: Position): String {
        let a = offset(start)
        let b = offset(end)
        if (a < 0 || b < a) { return "" }
        return String.fromUtf8(bytes[a..b])
    }

    func textOf(node: Node): String {
        let original = slice(node.beginPos, node.endPos)
        if (!original.isEmpty()) { return original.trimAscii() }
        return node.toTokens().toString().trimAscii()
    }

    func diagnostic(rule: String, severity: String, message: String, position: Position): Unit {
        result.get("diagnostics").add(J.obj().put("rule", J.str(rule))
            .put("severity", J.str(severity)).put("message", J.str(message))
            .put("source", J.str(path)).put("line", J.num(Int64(position.line)))
            .put("column", J.num(Int64(position.column))))
    }

    func docComment(position: Position): String {
        let start = offset(position)
        if (start < 0) { return "" }
        var end = start
        while (end > 0 && (bytes[end - 1] == 32 || bytes[end - 1] == 9 || bytes[end - 1] == 13)) { end-- }
        if (end == 0 || bytes[end - 1] != 10) { return "" }
        end--
        if (end > 0 && bytes[end - 1] == 13) { end-- }
        var begin = end
        while (begin > 0 && bytes[begin - 1] != 10) { begin-- }
        var last = String.fromUtf8(bytes[begin..end]).trimAscii()
        if (last.startsWith("///")) {
            var content = last[3..last.size].trimAscii()
            while (begin > 0) {
                var previousEnd = begin - 1
                if (previousEnd > 0 && bytes[previousEnd - 1] == 13) { previousEnd-- }
                var previousBegin = previousEnd
                while (previousBegin > 0 && bytes[previousBegin - 1] != 10) { previousBegin-- }
                let previous = String.fromUtf8(bytes[previousBegin..previousEnd]).trimAscii()
                if (!previous.startsWith("///")) { break }
                content = previous[3..previous.size].trimAscii() + "\n" + content
                begin = previousBegin
            }
            return content
        }
        if (last.endsWith("*/")) {
            var blockStart = begin
            while (blockStart > 0 && !String.fromUtf8(bytes[blockStart..end]).trimAscii().startsWith("/**")) {
                blockStart--
                while (blockStart > 0 && bytes[blockStart - 1] != 10) { blockStart-- }
            }
            let block = String.fromUtf8(bytes[blockStart..end]).trimAscii()
            if (block.startsWith("/**")) {
                let inner = block[3..block.size - 2]
                var content = ""
                for (raw in inner.split("\n")) {
                    var part = raw.trimAscii()
                    if (part.startsWith("*")) { part = part[1..part.size].trimAscii() }
                    if (!part.isEmpty()) {
                        if (!content.isEmpty()) { content += "\n" }
                        content += part
                    }
                }
                return content
            }
        }
        return ""
    }

    func symbol(name: String, kind: String, owner: String, declaration: String,
        parameters: J, returns: String, position: Position): Unit {
        let known = returns != "unknown"
        result.get("symbols").add(J.obj().put("name", J.str(name)).put("kind", J.str(kind))
            .put("package", J.str(packageName)).put("owner", J.str(owner))
            .put("declaration", J.str(declaration.trimAscii())).put("parameters", parameters)
            .put("returns", J.str(returns)).put("line", J.num(Int64(position.line)))
            .put("column", J.num(Int64(position.column))).put("source", J.str(path))
            .put("comment", J.str(docComment(position)))
            .put("status", J.str(if (known) { "SUPPORTED" } else { "TYPE_UNKNOWN" })))
        if (!known) {
            diagnostic("AST_TYPE_UNKNOWN", "warning", "缺少显式类型；未执行类型推断：" + name, position)
        }
    }

    func isPublic(d: Decl): Bool {
        for (modifier in d.modifiers) { if (modifier.keyword.value == "public") { return true } }
        return false
    }

    func params(parameters: ArrayList<FuncParam>): J {
        let values = J.arr()
        for (p in parameters) {
            values.add(J.obj().put("name", J.str(p.identifier.value))
                .put("type", J.str(textOf(p.paramType))))
        }
        return values
    }

    func header(d: Decl, end: Position): String {
        let value = slice(d.beginPos, end).trimAscii()
        if (!value.isEmpty()) { return value }
        return textOf(d)
    }

    func unsupported(d: Decl, rule: String, message: String): Unit {
        partial = true
        diagnostic(rule, "warning", message, d.beginPos)
    }

    func declarations(decls: ArrayList<Decl>, owner: String, visible: Bool): Unit {
        for (d in decls) { declaration(d, owner, visible) }
    }

    func declaration(d: Decl, owner: String, parentVisible: Bool): Unit {
        // Extensions and macro expansion cannot be resolved by a syntax-only parser.
        if (d is ExtendDecl) {
            unsupported(d, "AST_UNSUPPORTED_EXTEND", "未解析扩展成员与目标类型绑定")
            return
        }
        if (d is MacroDecl || d is MacroExpandDecl) {
            unsupported(d, "AST_UNSUPPORTED_MACRO", "未执行宏展开；生成接口未知")
            return
        }
        // A conditional parent cannot confer unconditional visibility on members.
        // Preflight retains the source-position warning even when parsing later fails.
        if (!d.annotations.isEmpty()) {
            partial = true
            return
        }
        let visible = parentVisible && isPublic(d)
        if (let Some(c) <- (d as ClassDecl)) {
            if (visible) {
                symbol(d.identifier.value, "class", owner, header(d, c.body.lBrace.pos), J.arr(), "", d.beginPos)
            }
            declarations(c.body.decls, qualifiedOwner(owner, d.identifier.value), visible)
            return
        }
        if (let Some(s) <- (d as StructDecl)) {
            if (visible) {
                symbol(d.identifier.value, "struct", owner, header(d, s.body.lBrace.pos), J.arr(), "", d.beginPos)
            }
            declarations(s.body.decls, qualifiedOwner(owner, d.identifier.value), visible)
            return
        }
        if (let Some(i) <- (d as InterfaceDecl)) {
            if (visible) {
                symbol(d.identifier.value, "interface", owner, header(d, i.body.lBrace.pos), J.arr(), "", d.beginPos)
            }
            declarations(i.body.decls, qualifiedOwner(owner, d.identifier.value), visible)
            return
        }
        if (let Some(e) <- (d as EnumDecl)) {
            let enumOwner = qualifiedOwner(owner, d.identifier.value)
            if (visible) {
                symbol(d.identifier.value, "enum", owner, header(d, e.lBrace.pos), J.arr(), "", d.beginPos)
                for (c in e.constructors) {
                    if (!c.annotations.isEmpty()) { partial = true; continue }
                    let arguments = J.arr()
                    var n: Int64 = 0
                    for (t in c.typeArguments) {
                        arguments.add(J.obj().put("name", J.str("arg${n}"))
                            .put("type", J.str(textOf(t))))
                        n++
                    }
                    let end = c.identifier.pos
                    let initial = offset(end)
                    var finish = initial + c.identifier.value.toArray().size
                    if (!c.typeArguments.isEmpty()) {
                        finish = offset(c.rParen.pos) + 1
                    }
                    let signature = if (initial >= 0 && finish >= initial) {
                        String.fromUtf8(bytes[initial..finish])
                    } else { c.toTokens().toString() }
                    symbol(c.identifier.value, "enum_constructor", enumOwner, signature,
                        arguments, enumOwner, c.identifier.pos)
                }
            }
            declarations(e.decls, enumOwner, visible)
            return
        }
        if (let Some(f) <- (d as FuncDecl)) {
            if (!visible) { return }
            let constructor = d.keyword.value == "init"
            var returns = if (constructor) { owner } else { "unknown" }
            if (!constructor) {
                try { returns = textOf(f.declType) } catch (_: ASTException) {}
            }
            var end = d.endPos
            try { if (f.block.lBrace.pos.line > 0) { end = f.block.lBrace.pos } } catch (_: ASTException) {}
            var name = d.identifier.value
            if (f.overloadOp.size > 0) { name = "operator " + f.overloadOp.toString().trimAscii() }
            symbol(name, if (constructor) { "constructor" } else { "function" }, owner,
                header(d, end), params(f.funcParams), returns, d.beginPos)
            return
        }
        if (let Some(c) <- (d as PrimaryCtorDecl)) {
            if (visible) {
                symbol(d.identifier.value, "constructor", owner, header(d, c.block.lBrace.pos),
                    params(c.funcParams), owner, d.beginPos)
            }
            return
        }
        if (let Some(p) <- (d as PropDecl)) {
            if (visible) {
                var end = d.endPos
                if (p.lBrace.pos.line > 0) { end = p.lBrace.pos }
                symbol(d.identifier.value, "property", owner, header(d, end), J.arr(), textOf(p.declType), d.beginPos)
            }
            return
        }
        if (let Some(v) <- (d as VarDecl)) {
            if (!visible) { return }
            var returns = "unknown"
            try { returns = textOf(v.declType) } catch (_: ASTException) {}
            var end = d.endPos
            if (v.assign.pos.line > 0) { end = v.assign.pos }
            let name = d.identifier.value
            if (name.isEmpty()) {
                unsupported(d, "AST_UNSUPPORTED_PATTERN", "未支持公共解构变量声明")
            } else {
                symbol(name, if (owner.isEmpty()) { "variable" } else { "field" }, owner,
                    header(d, end), J.arr(), returns, d.beginPos)
            }
            return
        }
        if (let Some(a) <- (d as TypeAliasDecl)) {
            if (visible) {
                symbol(d.identifier.value, "type_alias", owner, textOf(d), J.arr(), textOf(a.aliasType), d.beginPos)
            }
            return
        }
        // main is an executable entry point, not an explicitly public declaration.
        if (d is MainDecl) { return }
        unsupported(d, "AST_UNSUPPORTED_NODE", "未支持声明节点：" + d.keyword.value)
    }

    func preflight(tokens: Tokens): Unit {
        var afterAt = false
        for (token in tokens) {
            if (afterAt) {
                partial = true
                if (token.value == "When") {
                    diagnostic("AST_UNSUPPORTED_CONDITIONAL", "warning", "未判定条件编译分支；接口集合不完整", token.pos)
                } else {
                    diagnostic("AST_UNSUPPORTED_MACRO", "warning", "未执行宏或注解展开：" + token.value, token.pos)
                }
                afterAt = false
            }
            if (token.kind == TokenKind.AT ||
                (token.value == "@!" && token.kind != TokenKind.STRING_LITERAL)) { afterAt = true }
            if (token.kind == TokenKind.MACRO) {
                partial = true
                diagnostic("AST_UNSUPPORTED_MACRO", "warning", "未执行宏定义或宏包展开", token.pos)
            }
        }
    }

    func run(source: String): J {
        var stage = "parse"
        try {
            let tokens = cangjieLex(source)
            preflight(tokens)
            let program = parseProgram(tokens)
            stage = "extract"
            let packageTokens = program.packageHeader.toTokens()
            var inName = false
            for (token in packageTokens) {
                if (inName && token.value != "\n") { packageName += token.value }
                if (token.value == "package") { inName = true }
            }
            result.put("package", J.str(packageName))
            for (item in program.importLists) {
                result.get("imports").add(J.str(textOf(item)))
            }
            declarations(program.decls, "", true)
            result.put("status", J.str(if (partial) { "PARTIAL" } else { "OK" }))
        } catch (e: Exception) {
            if (stage == "parse") {
                result.put("symbols", J.arr()).put("status", J.str("PARSE_FAILED"))
                diagnostic("AST_PARSE_FAILED", "error", e.message, Position())
            } else {
                result.put("symbols", J.arr()).put("status", J.str("PARTIAL"))
                diagnostic("AST_EXTRACTION_FAILED", "error", e.message, Position())
            }
        }
        return result
    }
}

private func qualifiedOwner(owner: String, name: String): String {
    if (owner.isEmpty()) { name } else { owner + "." + name }
}

public func extractSource(source: String, path: String): J {
    ApiExtractor(source, path).run(source)
}
