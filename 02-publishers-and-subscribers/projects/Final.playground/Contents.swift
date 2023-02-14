import Foundation
import Combine
import _Concurrency

var subscriptions = Set<AnyCancellable>()

example(of: "Publisher") {
    // 1
    let myNotification = Notification.Name("MyNotification")
    
    // 2
    let publisher = NotificationCenter.default
        .publisher(for: myNotification, object: nil)
    
    // 3
    let center = NotificationCenter.default
    
    // 4
    let observer = center.addObserver(
        forName: myNotification,
        object: nil,
        queue: nil) { notification in
            // 这是用原始的方法, 进行通知的处理.
            print("Notification received!")
        }
    
    // 5
    center.post(name: myNotification, object: nil)
    
    // 6
    center.removeObserver(observer)
}

example(of: "Subscriber") {
    let myNotification = Notification.Name("MyNotification")
    let center = NotificationCenter.default
    
    // 在内部, 进行了对于 NotificationCenter 的监听包装, 在有 Subscriber 来临的时候, 内部添加对于通知的监听, 监听回调就是将数据发送给后续的节点. 
    let publisher = center.publisher(for: myNotification, object: nil)
    
    // 1
    let subscription = publisher
        .sink { _ in
            // 这是用 Publisher 的方法, 进行通知的处理. 
            print("Notification received from a publisher!")
        }
    
    // 2
    center.post(name: myNotification, object: nil)
    // 3
    subscription.cancel()
}

example(of: "Just") {
    // 1
    let just = Just("Hello world!")
    
    // 2
    // Just 是在有监听之后, 立马进行信号的发送. 
    _ = just
        .sink(
            receiveCompletion: {
                print("Received completion", $0)
            },
            receiveValue: {
                print("Received value", $0)
            })
    
    _ = just
        .sink(
            receiveCompletion: {
                print("Received completion (another)", $0)
            },
            receiveValue: {
                print("Received value (another)", $0)
            })

    // 并不需要进行 cancel, 这是因为 Just 在收到下游注册之后, 立马就把自己的数据发送出去, 并且发送 Completion 事件.
}

example(of: "assign(to:on:)") {
    // 1
    class SomeObject {
        var value: String = "" {
            didSet {
                print(value)
            }
        }
    }
    
    // 2
    let object = SomeObject()
    
    // 3
    let publisher = ["Hello", "world!"].publisher
    
    // 不同的就是 Subscriber 的区别. 在 value 到达之后, 是调用了 object.value = value 的赋值操作. 
    // 类似于 setvalueForKey, 不过在 Swfit 里面, 使用 keypath 有着更加编译器安全的效果.
    _ = publisher
        .assign(to: \.value, on: object)
}

example(of: "assign(to:)") {
    // 1
    class SomeObject {
        // @Published 的属性, 在修改之后, 还会进行信号的发送. 
        @Published var value = 0
    }
    
    let object = SomeObject()
    
    // 2
    object.$value
        .sink {
            print($0)
        }
    
    // 3
    // 这个 assign to 是不同的效果.
    // 在里面, 会有对于 publisher 内部存储的 subject 相关方法的调用. 
    (0..<10).publisher
        .assign(to: &object.$value)
}

example(of: "Custom Subscriber") {
    // 1
    let publisher = (1...6).publisher
    
    // 2
    // 自定义一个 Subscriber
    final class IntSubscriber: Subscriber {
        // 3
        typealias Input = Int
        typealias Failure = Never
        
        //  receive(subscription 应该做两件事, 1. 上游 Subscription 内存管理, 2. 上游 Subscription demand 请求.
        func receive(subscription: Subscription) {
            // 在接收到 Subscription 的时候, 向 Subscription 请求 demand 的量
            subscription.request(.max(3))
        }
        
        // receive(_ input: Int) 应该做两件事, 1. 进行 input 的业务处理, operator 传递 transform 后的数据到后面的节点.
        // 2. 返回自身的 demand 要求, 进行上游的压力管理. 
        func receive(_ input: Int) -> Subscribers.Demand {
            // 在接受到数据之后, 返回最新需要的 Demand 的量. 
            print("Received value", input)
            return .none
        }
        
        //
        func receive(completion: Subscribers.Completion<Never>) {
            // 对于终点来说, 其实是不需要接收到结束事件的时候, 进行其他的状态维护的. 
            print("Received completion", completion)
        }

        // Cancel 应该 1. 内存管理. 2 调用存储的 Subscription, 进行 cancle 的调用. 
    }
    
    let subscriber = IntSubscriber()
    
    publisher.subscribe(subscriber)
}

/*
对于 Future 的使用, Future 就当做 Promise 来进行理解就可以了. 
 example(of: "Future") {
 func futureIncrement(
 integer: Int,
 afterDelay delay: TimeInterval) -> Future<Int, Never> {
 
 // Future 是多线路的. 
 Future<Int, Never> { promise in
    print("Original")
    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
    promise(.success(integer + 1))
    }
 }
 }
 
 // 1
 let future = futureIncrement(integer: 1, afterDelay: 3)
 
 // 2
 future
 .sink(receiveCompletion: { print($0) },
 receiveValue: { print($0) })
 .store(in: &subscriptions)
 
 future
 .sink(receiveCompletion: { print("Second", $0) },
 receiveValue: { print("Second", $0) })
 .store(in: &subscriptions)
 }
 */

/*
Subject
  1. 可以进行 Share 语义的实现. 
  1. 可以由业务逻辑进行信号发送的触发. 
*/
example(of: "PassthroughSubject") { 
    // 1
    enum MyError: Error {
        case test
    }
    
    // 2
    final class StringSubscriber: Subscriber {
        typealias Input = String
        typealias Failure = MyError
        
        func receive(subscription: Subscription) {
            subscription.request(.max(2))
        }
        
        func receive(_ input: String) -> Subscribers.Demand {
            print("Received value", input)
            // 3
            return input == "World" ? .max(1) : .none
        }
        
        func receive(completion: Subscribers.Completion<MyError>) {
            print("Received completion", completion)
        }
    }
    
    // 4
    let subscriber = StringSubscriber()
    
    // 5
    let subject = PassthroughSubject<String, MyError>()
    
    // 6
    subject.subscribe(subscriber)
    
    // 7
    let subscription = subject
        .sink(
            receiveCompletion: { completion in
                print("Received completion (sink)", completion)
            },
            receiveValue: { value in
                print("Received value (sink)", value)
            }
        )
    
    subject.send("Hello")
    subject.send("World")
    
    // 8
    subscription.cancel()
    
    // 9
    subject.send("Still there?")
    
    subject.send(completion: .failure(MyError.test))
    subject.send(completion: .finished)
    subject.send("How about another one?")
}

example(of: "CurrentValueSubject") {
    // 1
    var subscriptions = Set<AnyCancellable>()
    
    // 2
    let subject = CurrentValueSubject<Int, Never>(0)
    
    // 3
    subject
        .print()
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions) // 4
    
    subject.send(1)
    subject.send(2)
    
    print(subject.value)
    
    subject.value = 3
    print(subject.value)
    
    subject
        .print()
        .sink(receiveValue: { print("Second subscription:", $0) })
        .store(in: &subscriptions)
    
    subject.send(completion: .finished)
}

example(of: "Dynamically adjusting Demand") {
    final class IntSubscriber: Subscriber {
        typealias Input = Int
        typealias Failure = Never
        
        func receive(subscription: Subscription) {
            subscription.request(.max(2))
        }
        
        // 自定义 Subscriber 进行流量控制. 
        func receive(_ input: Int) -> Subscribers.Demand {
            print("Received value", input)
            switch input {
            case 1:
                return .max(2) // 1
            case 3:
                return .max(1) // 2
            default:
                return .none // 3
            }
        }
        
        func receive(completion: Subscribers.Completion<Never>) {
            print("Received completion", completion)
        }
    }
    
    let subscriber = IntSubscriber()
    
    let subject = PassthroughSubject<Int, Never>()
    
    subject.subscribe(subscriber)
    
    subject.send(1)
    subject.send(2)
    subject.send(3)
    subject.send(4)
    subject.send(5)
    subject.send(6)
}

example(of: "Type erasure") {
    // 1
    let subject = PassthroughSubject<Int, Never>()
    
    // 2
    // AnyPublisher 内部会有一个成员变量, 完整的保留类型信息, 但这是内部实现. 
    let publisher = subject.eraseToAnyPublisher()
    
    // 3
    publisher
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions)
    
    // 4
    subject.send(0)
    //publisher.send(1)
}

example(of: "async/await") {
    // 1
    let subject = CurrentValueSubject<Int, Never>(0)
    
    // 2
    Task {
        for await element in subject.values {
            print("Element: \(element)")
        }
        print("Completed.")
    }
    
    // 3
    subject.send(1)
    subject.send(2)
    subject.send(3)
    
    subject.send(completion: .finished)
}
