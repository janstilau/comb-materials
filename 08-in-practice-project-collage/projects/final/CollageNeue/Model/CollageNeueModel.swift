import Combine
import UIKit
import Photos

extension CollageNeueModel {
  static let collageSize = CGSize(width: UIScreen.main.bounds.width, height: 200)
}

class CollageNeueModel: ObservableObject {
  // MARK: - Collage
  
  private(set) var lastSavedPhotoID = ""
  private(set) var lastErrorMessage = ""
  
  private var subscriptions = Set<AnyCancellable>()
  private let images = CurrentValueSubject<[UIImage], Never>([])
  
  @Published var imagePreview: UIImage?
  
  let updateUISubject = PassthroughSubject<Int, Never>()
  
  private(set) var selectedPhotosSubject = PassthroughSubject<UIImage, Never>()
  
  func bindMainView() {
    // 1
    // images 的修改, 会触发后续信号, 后触发 $imagePreview 的修改. 但是这个逻辑很怪, 不是一个合理的数据流转的途径. 
    images
      .handleEvents(receiveOutput: { [weak self] photos in
        self?.updateUISubject.send(photos.count)
      })
    // 2
      .map { photos in
        UIImage.collage(images: photos, size: Self.collageSize)
      }
      .assign(to: &$imagePreview)
  }
  
  func add() {
    // 这里我感觉不应该使用 selectedPhotosSubject, 让代码变得混乱.
    // 最终是进行 images 的修改.
    selectedPhotosSubject = PassthroughSubject<UIImage, Never>()
    // selectedPhotosSubject 的后续信号, 都在这里.
    let newPhotos = selectedPhotosSubject
      .eraseToAnyPublisher()
      .prefix(while: { [unowned self] _ in
        self.images.value.count < 6
      })
      .share()
    
    newPhotos
      .map { [unowned self] newImage in
        // 1
        return self.images.value + [newImage]
      }
    // 2
      .assign(to: \.value, on: images)
    // 3
      .store(in: &subscriptions)
  }
  
  func clear() {
    images.send([])
  }
  
  func save() {
    guard let image = imagePreview else { return }
    
    // 1
    PhotoWriter.save(image)
      .sink(
        receiveCompletion: { [unowned self] completion in
          // 2
          if case .failure(let error) = completion {
            lastErrorMessage = error.localizedDescription
          }
          clear()
        },
        receiveValue: { [unowned self] id in
          // 3
          lastSavedPhotoID = id
        }
      )
      .store(in: &subscriptions)
  }
  
  // MARK: -  Displaying photos picker
  private lazy var imageManager = PHCachingImageManager()
  private(set) var thumbnails = [String: UIImage]()
  private let thumbnailSize = CGSize(width: 200, height: 200)
  
  func bindPhotoPicker() {
    
  }
  
  // 业务逻辑还是要写在 ViewModel 里面的, 这是 Controller 层的责任. 
  func loadPhotos() -> PHFetchResult<PHAsset> {
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    return PHAsset.fetchAssets(with: allPhotosOptions)
  }
  
  func enqueueThumbnail(asset: PHAsset) {
    guard thumbnails[asset.localIdentifier] == nil else { return }
    
    imageManager.requestImage(
      for: asset,
      targetSize: thumbnailSize,
      contentMode: .aspectFill,
      options: nil,
      resultHandler: { image, _ in
      guard let image = image else { return }
      self.thumbnails[asset.localIdentifier] = image
    })
  }
  
  // 当选择图片页面的图片被点击之后, 调用这里的方法.
  func selectImage(asset: PHAsset) {
    imageManager.requestImage(
      for: asset,
      targetSize: UIScreen.main.bounds.size,
      contentMode: .aspectFill,
      options: nil
    ) { [weak self] image, info in
      guard let self = self,
            let image = image,
            let info = info else { return }
      
      if let isThumbnail = info[PHImageResultIsDegradedKey as String] as? Bool, isThumbnail {
        // Skip the thumbnail version of the asset
        return
      }
      
      self.selectedPhotosSubject.send(image)
    }
  }
}
