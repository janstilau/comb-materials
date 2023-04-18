import Foundation
import Combine

public protocol JokeServiceDataPublisher {
    // 这个协议起名不好, 这样就导致了, 一个实现类只能实现一个接口
    func publisher() -> AnyPublisher<Data, URLError>
}
