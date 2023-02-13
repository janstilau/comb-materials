import SwiftUI
import Combine

struct MainView: View {
  @EnvironmentObject var modelSubject: CollageNeueModel
  
  @State private var isDisplayingSavedMessage = false
  
  @State private var lastErrorMessage = "" {
    didSet {
      isDisplayingErrorMessage = true
    }
  }
  @State private var isDisplayingErrorMessage = false
  
  @State private var isDisplayingPhotoPicker = false
  
  @State private(set) var saveIsEnabled = true
  @State private(set) var clearIsEnabled = true
  @State private(set) var addIsEnabled = true
  @State private(set) var title = ""
  
  var body: some View {
    VStack {
      HStack {
        Text(title)
          .font(.title)
          .fontWeight(.bold)
        Spacer()
        
        Button(action: {
          // UIAction 触发 ModelAction
          modelSubject.add()
          isDisplayingPhotoPicker = true
        }, label: {
          Text("＋").font(.title)
        })
        .disabled(!addIsEnabled)
      }
      .padding(.bottom)
      .padding(.bottom)
      
      Image(uiImage: modelSubject.imagePreview ?? UIImage())
        .resizable()
        .frame(height: 200, alignment: .center)
        .border(Color.gray, width: 2)
      
      Button(action: modelSubject.clear, label: {
        Text("Clear")
          .fontWeight(.bold)
          .frame(maxWidth: .infinity)
      })
      .disabled(!clearIsEnabled)
      .buttonStyle(.bordered)
      .padding(.vertical)
      
      Button(action: modelSubject.save, label: {
        Text("Save")
          .fontWeight(.bold)
          .frame(maxWidth: .infinity)
      })
      .disabled(!saveIsEnabled)
      .buttonStyle(.borderedProminent)
      
    }
    .padding()
    .onChange(of: modelSubject.lastSavedPhotoID, perform: { lastSavedPhotoID in
      isDisplayingSavedMessage = true
    })
    .alert("Saved photo with id: \(modelSubject.lastSavedPhotoID)", isPresented: $isDisplayingSavedMessage, actions: { })
    .alert(lastErrorMessage, isPresented: $isDisplayingErrorMessage, actions: { })
    .sheet(isPresented: $isDisplayingPhotoPicker, onDismiss: {
      
    }) {
      PhotosView().environmentObject(modelSubject)
    }
    .onAppear(perform: modelSubject.bindMainView)
    .onReceive(modelSubject.updateUISubject, perform: updateUI)
  }
  
  func updateUI(photosCount: Int) {
    saveIsEnabled = photosCount > 0 && photosCount % 2 == 0
    clearIsEnabled = photosCount > 0
    addIsEnabled = photosCount < 6
    title = photosCount > 0 ? "\(photosCount) photos" : "Collage Neue"
  }
}
