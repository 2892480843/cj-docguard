package docguard_demo

/// 两个整数相加；溢出遵循仓颉整数检查。
public func add(a: Int64, b: Int64): Int64 { a + b }
/// 两个整数相减。
public func subtract(a: Int64, b: Int64): Int64 { a - b }
/// 两个整数相乘。
public func multiply(a: Int64, b: Int64): Int64 { a * b }
/// 求绝对值；最小整数没有可表示的正值，明确拒绝。
public func absValue(value: Int64): Int64 {
    if (value == Int64.Min) { throw IllegalArgumentException("minimum integer has no positive absolute value") }
    if (value < 0) { -value } else { value }
}
/// 返回两个整数中的较大值。
public func maxValue(a: Int64, b: Int64): Int64 { if (a > b) { a } else { b } }
/// 返回两个整数中的较小值。
public func minValue(a: Int64, b: Int64): Int64 { if (a < b) { a } else { b } }
/// 判断整数是否为偶数。
public func isEven(value: Int64): Bool { value % 2 == 0 }
/// 判断整数是否大于零。
public func isPositive(value: Int64): Bool { value > 0 }
/// 生成中文问候，保留输入姓名。
public func greet(name: String): String { "你好，" + name }
/// 按原有顺序重复文本；次数限制为零到一千。
public func repeatText(value: String, count: Int64): String {
    if (count < 0 || count > 1000) { throw IllegalArgumentException("count must be 0..1000") }
    var out = ""
    for (_ in 0..count) { out += value }
    out
}
/// 对整数数组求和；不改变原数组。
public func sumArray(values: Array<Int64>): Int64 {
    var total: Int64 = 0
    for (value in values) { total += value }
    total
}
/// 阶乘只支持零到二十，避免超出 Int64。
public func factorial(value: Int64): Int64 {
    if (value < 0 || value > 20) { throw IllegalArgumentException("factorial input must be 0..20") }
    var total: Int64 = 1
    for (i in 1..value + 1) { total *= i }
    total
}
/// 将值限制在闭区间内；拒绝颠倒的区间。
public func clamp(value: Int64, low: Int64, high: Int64): Int64 {
    if (low > high) { throw IllegalArgumentException("low cannot exceed high") }
    maxValue(low, minValue(value, high))
}
/// 除数为零或最小整数除以负一时返回 None。
public func divideSafe(a: Int64, b: Int64): ?Int64 {
    if (b == 0 || (a == Int64.Min && b == -1)) { None } else { Some(a / b) }
}
/// 泛型函数原样返回参数，显式保留类型 T。
public func identity<T>(value: T): T { value }
/// 按同一函数连续变换两次。
public func applyTwice(transform: (Int64) -> Int64, value: Int64): Int64 {
    transform(transform(value))
}
/// 默认计数步长。
public let defaultStep: Int64 = 1
/// 自建样例使用的问候前缀。
public var globalGreeting: String = "你好"
/// 整数计数的类型别名。
public type Count = Int64

/// 可变计数器，示范公共字段、构造器、方法和属性。
public class Counter {
    /// 当前计数值。
    public var value: Int64
    /// 使用显式初值创建计数器。
    public init(seed: Int64) { value = seed }
    /// 递增后返回当前值；step 为有默认值的命名参数。
    public func increment(step!: Int64 = 1): Int64 { value += step; value }
    /// 将当前值重设为零。
    public func reset(): Unit { value = 0 }
    /// 读取当前计数。
    public func read(): Int64 { value }
    /// 只读属性视图。
    public prop current: Int64 { get() { value } }
}

/// 两个不可变整数构成的数据结构。
public struct Pair {
    /// 第一项。
    public let first: Int64
    /// 第二项。
    public let second: Int64
    /// 创建一对整数。
    public init(a: Int64, b: Int64) { first = a; second = b }
    /// 两项之和。
    public func sum(): Int64 { first + second }
    /// 第一项减去第二项。
    public func difference(): Int64 { first - second }
}

/// 泛型容器，只保存一个值。
public class Box<T> {
    /// 容器中的值。
    public let value: T
    /// 创建泛型容器。
    public init(value: T) { this.value = value }
    /// 读取保存的值。
    public func get(): T { value }
}

/// 颜色枚举，自建示例使用三个无载荷构造项。
public enum Shade {
    Red | Green | Blue
    /// 将颜色映射为固定编号。
    public func code(): Int64 {
        match (this) { case Red => 1; case Green => 2; case Blue => 3 }
    }
}

/// 可提供姓名文本的接口。
public interface Named {
    /// 返回姓名文本。
    public func name(): String
}

/// Named 的显式实现。
public class Label <: Named {
    /// 保存的姓名。
    public let value: String
    /// 创建姓名标签。
    public init(value: String) { this.value = value }
    /// 返回保存的姓名。
    public func name(): String { value }
}
