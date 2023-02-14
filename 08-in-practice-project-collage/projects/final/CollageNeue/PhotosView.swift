import SwiftUI
import Photos
import Combine

struct PhotosView: View {
  @EnvironmentObject var modelSubject: CollageNeueModel
  @Environment(\.presentationMode) var presentationMode
  
  let columns: [GridItem] = [.init(.adaptive(minimum: 100, maximum: 200))]
  
  @State private var subscriptions = [AnyCancellable]()
  
  @State private var allPhotos = PHFetchResult<PHAsset>()
  @State private var imageManager = PHCachingImageManager()
  @State private var isDisplayingError = false
  
  var body: some View {
    NavigationView {
      ScrollView {
        LazyVGrid(columns: columns, spacing: 2) {
          ForEach((0..<allPhotos.count), id: \.self) { index in
            let asset = allPhotos[index]
            // 在 View 层进行了 Model 的数据变化, 这里的逻辑有问题.
            // 这块逻辑, 应该放到 Model 的内部.
            let _ = modelSubject.enqueueThumbnail(asset: asset)
            
            // 这是 Cell 的实现.
            Button(action: {
              // View Action 触发 ModelAction.
              modelSubject.selectImage(asset: asset)
            }, label: {
              Image(uiImage: modelSubject.thumbnails[asset.localIdentifier] ?? UIImage(named: "IMG_1907")!)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .clipShape(
                  RoundedRectangle(cornerRadius: 5)
                )
                .padding(4)
            })
          }
        }
        .padding()
      }
      .navigationTitle("Photos")
      .toolbar {
        Button("Close", role: .cancel) {
          self.presentationMode.wrappedValue.dismiss()
        }
      }
    }
    .alert("No access to Camera Roll", isPresented: $isDisplayingError, actions: { }, message: {
      Text("You can grant access to Collage Neue from the Settings app")
    })
    .onAppear {
      // Check for Photos access authorization and reload the list if authorized.
      PHPhotoLibrary.fetchAuthorizationStatus { status in
        if status {
          DispatchQueue.main.async {
            // 使用 ViewModel 的方法, 来进行实际的业务逻辑数据的加载.
            // allPhotos 的修改, 会导致整个页面进行重新刷新. CollectionView 是依赖于 allPhotos 的实现的.
            self.allPhotos = modelSubject.loadPhotos()
          }
        }
      }
      
      modelSubject.bindPhotoPicker()
    }
    .onDisappear {
      // 这里的逻辑有问题, selectedPhotosSubject 应该完全的在 ViewModel 的内部. 
      modelSubject.selectedPhotosSubject.send(completion: .finished)
    }
  }
}
