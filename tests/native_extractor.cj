package docguard
import std.collection.*

func exExpect(ok:Bool,message:String):Unit {
    if (!ok) { throw Exception("extractor test failed: " + message) }
}
func exFind(result:J,name:String):J { exFind(result,name,"") }
func exFind(result:J,name:String,owner:String):J {
    for (symbol in result.get("symbols").items) {
        if (symbol.get("name").s()==name && symbol.get("owner").s()==owner) { return symbol }
    }
    return J.nil()
}
func exRule(result:J,rule:String):Bool {
    for (d in result.get("diagnostics").items) { if (d.get("rule").s()==rule) { return true } }
    return false
}

main():Unit {
    let source = "package sample.api\nimport std.collection.*\n/// 中文接口说明\npublic func 收集<T>(values: Array<T>): T where T <: Any { values[0] }\npublic func pick(value: Int64): Int64 { value }\npublic func pick(value: String): String { value }\npublic func inferred() { 1 }\npublic let limit: Int64 = 10\npublic var title: String = \"x\"\npublic type Count = Int64\npublic class Box<T> {\n public let value: T\n public init(value: T) { this.value = value }\n public func read(): T { value }\n public func map<U>(other: U): U { other }\n public prop current: T { get() { value } }\n private func secret(): Unit {}\n}\npublic struct Pair {\n public let first: Int64\n public let second: Int64\n public init(a: Int64, b: Int64) { first=a; second=b }\n public func sum(): Int64 { first+second }\n public prop total: Int64 { get() { first+second } }\n}\npublic interface Reader {\n public func read(): String\n public func size(): Int64\n public prop label: String\n}\npublic enum State {\n Ready | Running(Int64) | Failed(String)\n public func name(): String { \"state\" }\n public prop code: Int64 { get() { 0 } }\n}\nclass Hidden {\n public func exposed(): Int64 { 1 }\n}\npublic func tuple(a: (Int64, String)): (Int64, String) { a }\npublic func callback(f: (Int64) -> String): String { f(1) }\npublic func optional(a: ?Int64): ?Int64 { a }\npublic func named(count!: Int64 = 1): Int64 { count }\npublic func alpha(): Unit {}\npublic func beta(): Unit {}\npublic func gamma(): Unit {}\npublic func delta(): Unit {}\nfunc internalOnly(): Unit {}\n"
    let result = extractSource(source,"api.cj")
    exExpect(result.get("status").s()=="OK", "supported source parses")
    exExpect(result.get("package").s()=="sample.api", "package preserved")
    exExpect(result.get("imports").items.size==1, "import captured")
    let expected = ["收集", "pick", "pick", "inferred", "limit", "title", "Count", "Box", "value", "init", "read", "map", "current", "Pair", "first", "second", "init", "sum", "total", "Reader", "read", "size", "label", "State", "Ready", "Running", "Failed", "name", "code", "tuple", "callback", "optional", "named", "alpha", "beta", "gamma", "delta"]
    let owners = ["", "", "", "", "", "", "", "", "Box", "Box", "Box", "Box", "Box", "", "Pair", "Pair", "Pair", "Pair", "Pair", "", "Reader", "Reader", "Reader", "", "State", "State", "State", "State", "State", "", "", "", "", "", "", "", ""]
    exExpect(result.get("symbols").items.size==expected.size, "37 manually enumerated symbols")
    for (i in 0..expected.size) {
        let actual=result.get("symbols").items[i]
        exExpect(actual.get("name").s()==expected[i], "symbol #${i} name ${expected[i]}")
        exExpect(actual.get("owner").s()==owners[i], "symbol #${i} owner")
        exExpect(actual.get("source").s()=="api.cj", "source path")
        exExpect(actual.get("package").s()=="sample.api", "symbol package")
    }
    let chinese=exFind(result,"收集")
    exExpect(chinese.get("line").i()==4 && chinese.get("column").i()==1,"original UTF-8 source position")
    exExpect(chinese.get("comment").s()=="中文接口说明", "Chinese preceding doc comment")
    exExpect(chinese.get("declaration").s()=="public func 收集<T>(values: Array<T>): T where T <: Any", "raw generic signature")
    exExpect(chinese.get("parameters").items[0].get("type").s()=="Array<T>", "explicit generic parameter type")
    exExpect(chinese.get("returns").s()=="T", "explicit return type")
    exExpect(result.get("symbols").items[1].get("declaration").s()!=result.get("symbols").items[2].get("declaration").s(),"overload identity differs")
    exExpect(exFind(result,"inferred").get("returns").s()=="unknown", "do not infer return")
    exExpect(exFind(result,"inferred").get("status").s()=="TYPE_UNKNOWN", "inferred type disclosed")
    exExpect(exFind(result,"exposed","Hidden").kind=="null", "private parent hides public member")
    exExpect(exFind(result,"secret","Box").kind=="null", "private member hidden")
    exExpect(exFind(result,"Running","State").get("parameters").items[0].get("type").s()=="Int64", "enum payload")
    let bad=extractSource("public func broken(: Int64 {", "broken.cj")
    exExpect(bad.get("status").s()=="PARSE_FAILED" && bad.get("symbols").items.isEmpty(),"invalid syntax fails closed")
    exExpect(exRule(bad,"AST_PARSE_FAILED"), "syntax diagnostic")
    let extension=extractSource("extend String { public func extra(): Int64 { 1 } }", "extend.cj")
    exExpect(extension.get("status").s()=="PARTIAL" && exRule(extension,"AST_UNSUPPORTED_EXTEND"),"extend disclosed")
    let conditional=extractSource("@When[os == \"Linux\"]\npublic func linuxOnly(): Unit {}", "when.cj")
    exExpect(exRule(conditional,"AST_UNSUPPORTED_CONDITIONAL"),"conditional compilation disclosed")
    exExpect(conditional.get("symbols").items.isEmpty(), "conditional API is not claimed supported")
    let macroResult=extractSource("@Custom public func generated(): Unit {}", "macro.cj")
    exExpect(exRule(macroResult,"AST_UNSUPPORTED_MACRO"), "unexpanded macro disclosed")
    let textOnly=extractSource("/// @When extend macro are documentation\npublic func text(): String { \"@When extend\" }", "literal.cj")
    exExpect(textOnly.get("status").s()=="OK", "comments and strings do not create unsupported warnings")
    let exactLiterals=extractSource("public func literal(): String { \"macro\"; \"@\"; \"extend\" }", "exact-literal.cj")
    exExpect(exactLiterals.get("status").s()=="OK", "literal token values are not keywords")
    let unicode=extractSource("/** 中文多行\n * 文档内容\n */\npublic class 容器 { public func 方法(参数: String): String { 参数 } }", "unicode.cj")
    exExpect(exFind(unicode,"容器").get("comment").s().contains("文档内容"),"multiline Chinese comment")
    exExpect(exFind(unicode,"方法","容器").get("column").i()==23,"UTF-8 byte column retained")
    let operatorSource=extractSource("public class Number { public operator func +(rhs: Number): Number { this } }", "operator.cj")
    exExpect(exFind(operatorSource,"operator +","Number").get("returns").s()=="Number", "operator signature")
    let primary=extractSource("public class Primary { public Primary(value: Int64) {} }", "primary.cj")
    exExpect(exFind(primary,"Primary","Primary").get("kind").s()=="constructor", "primary constructor")
    let pattern=extractSource("public let (x,y)=(1,2)", "pattern.cj")
    exExpect(pattern.get("status").s()=="PARTIAL" && exRule(pattern,"AST_UNSUPPORTED_PATTERN"), "destructuring explicitly unsupported")
    let unknownVar=extractSource("public let count = 1", "unknown.cj")
    exExpect(exFind(unknownVar,"count").get("returns").s()=="unknown", "variable inference not claimed")
    let nested=extractSource("@When[os == \"Linux\"]\npublic class Conditional { public func member(): Unit {} }", "nested.cj")
    exExpect(nested.get("symbols").items.isEmpty(), "conditional parent hides all members")
    println("native extractor: 37 symbol cases and boundary tests passed")
}
