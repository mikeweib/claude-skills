# C++ 内存安全 Bug 模式速查

> 对照 `SKILL.md` 核心检查清单的每个维度，提供 bad/good 代码对比。

## 1. Smart Pointer 选择

```cpp
// BAD: 不需要共享所有权时用 shared_ptr
std::shared_ptr<Config> loadConfig(const std::string& path) {
    return std::make_shared<Config>(path);
}
auto cfg = loadConfig("app.conf");  // 只有一个所有者

// GOOD: 默认用 unique_ptr，调用方需要共享时自行转换
std::unique_ptr<Config> loadConfig(const std::string& path) {
    return std::make_unique<Config>(path);
}
auto cfg = loadConfig("app.conf");
```

```cpp
// BAD: WebRTC 工程中用 std::shared_ptr
#include "rtc_base/ref_count.h"
class AudioTrack : public rtc::RefCountInterface { ... };
std::shared_ptr<AudioTrack> track = std::make_shared<AudioTrack>();

// GOOD: WebRTC 工程用 rtc::scoped_refptr
#include "rtc_base/ref_counted_object.h"
rtc::scoped_refptr<AudioTrack> track = rtc::make_ref_counted<AudioTrack>();
```

## 2. 所有权配对

```cpp
// BAD: new 和 delete 不在同一作用域，容易遗漏
void process() {
    int* data = new int[100];
    if (error) return;         // 泄漏！
    delete[] data;
}

// GOOD: 用 unique_ptr 自动管理
void process() {
    auto data = std::make_unique<int[]>(100);
    if (error) return;         // unique_ptr 自动释放
}
```

```cpp
// BAD: malloc / free 混用 new / delete
int* p = (int*)malloc(sizeof(int) * 10);
delete[] p;                    // UB! malloc 不能 delete

// GOOD: 配对一致，或用 vector
std::vector<int> p(10);
```

## 3. 数组边界

```cpp
// BAD: 无边界检查
void write(int idx, int value) {
    buf[idx] = value;          // idx 可能 >= BUF_SIZE
}

// GOOD: 检查边界
void write(int idx, int value) {
    if (idx < 0 || idx >= BUF_SIZE) throw std::out_of_range("idx");
    buf[idx] = value;
}
```

```cpp
// BAD: 空容器下访问 [0]
void print_first(const std::vector<int>& v) {
    std::cout << v[0];         // v.empty() 时 UB
}

// GOOD: 判空
void print_first(const std::vector<int>& v) {
    if (!v.empty()) std::cout << v[0];
}
```

## 4. 空指针

```cpp
// BAD: 解引用前不判空
size_t len(const char* str) {
    return strlen(str);        // str 可能是 nullptr → crash
}

// GOOD: 入口判空
size_t len(const char* str) {
    if (str == nullptr) return 0;
    return strlen(str);
}
```

## 5. 悬空指针

```cpp
// BAD: delete 后继续使用
delete ptr;
ptr->method();                 // use-after-free, UB

// GOOD: delete 后置 nullptr，或用智能指针
delete ptr;
ptr = nullptr;                 // 后续判空可捕获
// or: auto ptr = std::make_unique<T>(); ptr.reset();
```

```cpp
// BAD: 返回局部变量指针
int* get_value() {
    int local = 42;
    return &local;             // 悬空！
}

// GOOD: 按值返回
int get_value() {
    return 42;
}
```

## 6. 浅拷贝 / Rule of Five

```cpp
// BAD: 有 raw pointer 成员但没有拷贝控制
class Buffer {
    char* data_;               // owning raw pointer
    size_t size_;
public:
    Buffer(const char* s) : size_(strlen(s)), data_(new char[size_+1]) {
        strcpy(data_, s);
    }
    ~Buffer() { delete[] data_; }
    // 缺少 copy ctor, copy assign, move ctor, move assign
};

// GOOD: 实现 Rule of Five
class Buffer {
    char* data_;
    size_t size_;
public:
    Buffer(const char* s) : size_(strlen(s)), data_(new char[size_+1]) {
        strcpy(data_, s);
    }
    ~Buffer() { delete[] data_; }
    Buffer(const Buffer& o) : size_(o.size_), data_(new char[size_+1]) {
        strcpy(data_, o.data_);
    }
    Buffer& operator=(const Buffer& o) {
        if (this != &o) { delete[] data_; size_ = o.size_; data_ = new char[size_+1]; strcpy(data_, o.data_); }
        return *this;
    }
    Buffer(Buffer&& o) noexcept : size_(o.size_), data_(o.data_) {
        o.data_ = nullptr; o.size_ = 0;
    }
    Buffer& operator=(Buffer&& o) noexcept {
        if (this != &o) { delete[] data_; size_ = o.size_; data_ = o.data_; o.data_ = nullptr; o.size_ = 0; }
        return *this;
    }
};

// BETTER: 直接用 std::vector<char> 或 std::unique_ptr<char[]>，避免手写 Rule of Five
```

## 7. 异常安全

```cpp
// BAD: new 和 delete 之间可能抛异常
void risky(const std::string& s1, const std::string& s2) {
    auto* a = new char[s1.size() + 1];
    auto* b = new char[s2.size() + 1];  // 如果这里抛异常，a 泄漏
    // ...
    delete[] a;
    delete[] b;
}

// GOOD: 用智能指针，或先分配再构造
void safe(const std::string& s1, const std::string& s2) {
    auto a = std::make_unique<char[]>(s1.size() + 1);
    auto b = std::make_unique<char[]>(s2.size() + 1);  // 即使抛异常，a 已由 unique_ptr 管理
}
```

## 8. Move 语义

```cpp
// BAD: move 构造未将源对象 raw pointer 置 nullptr
class Widget {
    char* buf_;
public:
    Widget(Widget&& o) noexcept : buf_(o.buf_) {
        // 未置 nullptr! o 析构时会 delete buf_ → double-free
    }
    ~Widget() { delete[] buf_; }
};

// GOOD: 移动后清空源对象
class Widget {
    char* buf_;
public:
    Widget(Widget&& o) noexcept : buf_(o.buf_) {
        o.buf_ = nullptr;           // 关键：源指针置空
    }
    ~Widget() { delete[] buf_; }
};
```

## 9. 并发内存问题

```cpp
// BAD: 多线程无锁访问 shared_ptr 指向的数据
std::shared_ptr<Stats> g_stats = std::make_shared<Stats>();
void reader() { std::cout << g_stats->total_count; }  // data race!
void writer() { g_stats->total_count = 42; }           // data race!

// GOOD: 加锁保护数据
std::shared_ptr<Stats> g_stats = std::make_shared<Stats>();
std::mutex g_stats_mutex;
void reader() { std::lock_guard lk(g_stats_mutex); std::cout << g_stats->total_count; }
void writer() { std::lock_guard lk(g_stats_mutex); g_stats->total_count = 42; }
```

```cpp
// BAD: shared_ptr 循环引用导致泄漏
struct Node {
    std::shared_ptr<Node> parent;
    std::shared_ptr<Node> child;
};
auto p = std::make_shared<Node>();
auto c = std::make_shared<Node>();
p->child = c;  c->parent = p;  // 循环！永不释放

// GOOD: 一方用 weak_ptr
struct Node {
    std::weak_ptr<Node> parent;   // weak_ptr 不增加引用计数
    std::shared_ptr<Node> child;
};
```
