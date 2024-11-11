import SwiftUI
import AVFoundation
extension UIImage {
    func fixOrientation() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}

struct ContentView: View {
    @StateObject private var cameraModel = CameraModel()
    @State private var isProcessing = false
    @State private var image: UIImage?
    @State private var capturedPhoto: UIImage? // Переменная для хранения сделанного снимка
    @State private var isLanguageMenuVisible = false
    @State private var selectedLanguage = "en"
    @State private var languageMenuPosition: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // Проверяем, есть ли сохранённое фото, чтобы показать его на экране
            if let capturedPhoto = capturedPhoto {
                Image(uiImage: capturedPhoto)
                    .resizable()
                    .scaledToFit()
                    .edgesIgnoringSafeArea(.all)
                Text("Идёт генерация")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                
                
            } else if let image = image {
                // Если обработанное изображение готово, показываем его
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .edgesIgnoringSafeArea(.all)
                
                // Кнопка возврата
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            resetView()
                        }) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "arrow.left")
                                        .foregroundColor(.white)
                                        .font(.system(size: 50))
                                )
                                .shadow(radius: 10)
                        }
                        .padding()
                    }
                    .padding(.bottom, 50)
                }
            } else {
                // Камера на весь экран, если фото не сделано
                CameraPreview(camera: cameraModel)
                    .edgesIgnoringSafeArea(.all)
                
                // Сообщение "Идёт генерация"
                /*if isProcessing {
                    Text("Идёт генерация")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                }*/
                
                VStack {
                    Spacer()
                    HStack {
                        // Логотип (слева)
                        Button(action: {
                            // Действия для логотипа
                        }) {
                            Image("logoImage")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .shadow(radius: 10)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        // Кнопка съёмки (по центру)
                        if !isProcessing {
                            Button(action: {
                                isProcessing = true
                                cameraModel.takePhoto { capturedImage in
                                    if let capturedImage = capturedImage {
                                        // Сохраняем фото в переменную capturedPhoto для "зависания"
                                        self.capturedPhoto = capturedImage
                                        // Запускаем обработку изображения
                                        uploadImage(image: capturedImage, selectedLanguage: selectedLanguage) { resultImage in
                                            self.image = resultImage
                                            self.capturedPhoto = nil  // Очищаем снимок после завершения обработки
                                            self.isProcessing = false
                                        }
                                    }
                                }
                            }) {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 50))
                                    )
                                    .shadow(radius: 10)
                            }
                        }
                        
                        Spacer()
                        
                        // Кнопка с тремя линиями (справа)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isLanguageMenuVisible.toggle()
                            }
                        }) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "line.horizontal.3")
                                        .foregroundColor(.white)
                                        .font(.system(size: 40))
                                )
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.bottom, 50)
                }
                
                // Меню флагов
                if isLanguageMenuVisible {
                    GeometryReader { geometry in
                        VStack(spacing: 15) {
                            ForEach(["en", "ru", "es", "fr", "de"], id: \.self) { flag in
                                Button(action: {
                                    selectedLanguage = flag
                                    isLanguageMenuVisible.toggle()
                                }) {
                                    Image(flag)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .shadow(radius: 10)
                                }
                            }
                        }
                        .padding()
                        .frame(width: 200)
                        .position(x: geometry.size.width - 60, y: geometry.size.height - 350)
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .onAppear {
            cameraModel.checkPermissions()
        }
    }
    
    func uploadImage(image: UIImage, selectedLanguage: String, completion: @escaping (UIImage?) -> Void) {
        let fixedImage = image.fixOrientation()
        
        guard let url = URL(string: "http://193.160.209.33:8000/detect") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        guard let imageData = fixedImage.jpegData(compressionQuality: 0.7) else {
            print("Ошибка: Не удалось получить данные изображения")
            completion(nil)
            return
        }
        
        var data = Data()
        
        // Добавляем изображение
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n".data(using: .utf8)!)
        
        // Добавляем выбранный язык в запрос
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"user_lang\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(selectedLanguage)\r\n".data(using: .utf8)!)
        
        // Завершаем данные
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Выполняем запрос
        URLSession.shared.uploadTask(with: request, from: data) { (responseData, response, error) in
            guard let responseData = responseData, error == nil else {
                print("Ошибка: \(error?.localizedDescription ?? "нет описания")")
                completion(nil)
                return
            }
            
            DispatchQueue.main.async {
                if let resultImage = UIImage(data: responseData) {
                    completion(resultImage)
                } else {
                    print("Не удалось создать изображение из ответа")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func resetView() {
        image = nil
        capturedPhoto = nil // Очистка "зависшего" снимка
        isProcessing = false
    }
}
