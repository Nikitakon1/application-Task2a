//
//  ContentView.swift
//  JHUB_Application-2
//
//  Created by Nikita on 29/07/2025.
//

import SwiftUI
import CoreData
import PhotosUI

// MARK: - UIImagePicker for Camera Access
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    var sourceType: UIImagePickerController.SourceType = .camera
    @Binding var selectedImage: UIImage?
    var onImagePicked: (() -> Void)? // Callback after image is picked

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
            parent.onImagePicked?()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    @State private var showGBPPrompt = false
    @State private var gbpInput = ""
    @State private var pendingItem: Item?

    @State private var selectedImage: UIImage?
    @State private var photoItem: PhotosPickerItem?

    @State private var showCamera = false

    // MARK: - Total Amount Calculation
    var totalAmount: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    private func saveItemWithAmount() {
        guard let item = pendingItem else { return }

        let cleaned = gbpInput
            .replacingOccurrences(of: "£", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let amount = Double(cleaned) {
            item.amount = amount

            if let selectedImage = selectedImage,
               let imageData = selectedImage.jpegData(compressionQuality: 0.8) {
                item.imageData = imageData
            } else {
                item.imageData = nil
            }

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }

        pendingItem = nil
        gbpInput = ""
        selectedImage = nil
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        VStack {
                            Text("Item at \(item.timestamp!, formatter: itemFormatter) for £\(String(format: "%.2f", item.amount))")
                            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .padding()
                            } else {
                                Text("No image available for this item.")
                                    .foregroundColor(.gray)
                            }
                        }
                        .navigationTitle("Receipt Details")
                    } label: {
                        HStack {
                            Text(item.timestamp!, formatter: itemFormatter)
                            Spacer()
                            if item.imageData != nil {
                                Image(systemName: "photo.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Receipt", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Total: £\(String(format: "%.2f", totalAmount))")
            Text("Select an item")
        }
        .alert("Enter GBP Amount", isPresented: $showGBPPrompt) {
            TextField("£0.00", text: $gbpInput)
                .keyboardType(.decimalPad)

            Button("Take Photo") {
                showCamera = true
            }

            Button("Submit") {
                saveItemWithAmount()
            }

            Button("Cancel", role: .cancel) {
                pendingItem = nil
                gbpInput = ""
                selectedImage = nil
            }
        } message: {
            Text("Please enter the amount in GBP and take a photo of the receipt")
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $selectedImage) {
                saveItemWithAmount()
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            pendingItem = newItem
            showGBPPrompt = true
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
