import UIKit
import Combine

extension UIViewController {
  // 原本的 Completion, Delegate 的方式, 使用了 Publsiher 进行新的变化. 
  func alert(title: String, text: String?) -> AnyPublisher<Void, Never> {
    let alertVC = UIAlertController(title: title,
                                    message: text,
                                    preferredStyle: .alert)
    
    return Future { resolve in
      alertVC.addAction(UIAlertAction(title: "Close",
                                      style: .default) { _ in
        resolve(.success(()))
      })
      
      self.present(alertVC, animated: true, completion: nil)
    }
    .handleEvents(receiveCancel: {
      self.dismiss(animated: true)
    })
    .eraseToAnyPublisher()
  }
}
