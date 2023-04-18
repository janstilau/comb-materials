import UIKit
import Combine
import SwiftUI

public final class JokesViewModel: ObservableObject {
    public enum DecisionState {
        case disliked, undecided, liked
    }
    
    private static let decoder = JSONDecoder()
    
    @Published public var joke = Joke.starter
    
    // ViewState 相关的东西.
    @Published public var fetching = false
    @Published public var backgroundColor = Color("Gray")
    @Published public var decisionState = DecisionState.undecided
    
    private let jokesService: JokeServiceDataPublisher
    
    // 只能通过 Init 方法来进行注册, 如果没有赋值, 那么会有默认的 Servcie 实例. 
    public init(jokesService: JokeServiceDataPublisher = JokesService()) {
        self.jokesService = jokesService
        
        $joke
            .map { _ in false }
            .assign(to: &$fetching)
    }
    
    // ViewAction 触发的 Model Action.
    public func fetchJoke() {
        // 1
        // ModelAction 里面, 主动进行信号的发送, 进行 UI 的变化.
        fetching = true
        
        // 真正的网络请求, 从原本的 Block, 变为了链式调用.
        // 对于 Decode 来说, 把泛型进行了拆解, 这感觉要比 Request 中绑定 ResponseModel 的类型要好一些.
        // 2
        jokesService.publisher()
        // 3
            .retry(1)
        // 4
            .decode(type: Joke.self, decoder: Self.decoder)
        // 5
            .replaceError(with: Joke.error)
        // 6
            .receive(on: DispatchQueue.main)
        // 7
        // Model 的修改, 最终变为了信号的发送.
        // 使用 @Published 使得数据存储和信号发送这两件事, 得到了统一.
            .assign(to: &$joke)
    }
    
    // ViewAction 所触发的 Model Action.
    public func updateBackgroundColorForTranslation(_ translation: Double) {
        switch translation {
        case ...(-0.5):
            backgroundColor = Color("Red")
        case 0.5...:
            backgroundColor = Color("Green")
        default:
            backgroundColor = Color("Gray")
        }
    }
    
    // ViewAction 所触发的 ModelAction .
    public func updateDecisionStateForTranslation(
        _ translation: Double,
        andPredictedEndLocationX x: CGFloat,
        inBounds bounds: CGRect) {
            switch (translation, x) {
            case (...(-0.6), ..<0):
                decisionState = .disliked
            case (0.6..., bounds.width...):
                decisionState = .liked
            default:
                decisionState = .undecided
            }
        }
    
    public func reset() {
        backgroundColor = Color("Gray")
    }
}
