import SwiftUI

public struct MatEditorView: View {
    @State private var mat: MatBoard = MatBoard(title: "My Home Mat")
    @State private var selectedItemId: UUID?
    @State private var showingImagePicker = false
    @State private var isProcessingCutout = false
    @State private var showingNotePrompt = false
    @State private var noteInputText = ""

    private let lifter = SubjectLifter()

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Widget Preview Container
                GeometryReader { geo in
                    ZStack {
                        // Canvas Background
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(hex: mat.backgroundColorHex))
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)

                        // Placed Elements
                        ForEach($mat.items) { $item in
                            DraggableItemView(
                                item: $item,
                                containerSize: geo.size,
                                isSelected: selectedItemId == item.id,
                                onSelect: { selectedItemId = item.id }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                }

                // Controls & Toolbar
                bottomToolbar
            }
            .navigationTitle("Mat Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: saveAndSyncWidget) {
                        Text("Save & Sync")
                            .fontWeight(.semibold)
                    }
                }
            }
            .overlay {
                if isProcessingCutout {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Lifting subject...")
                                .font(.callout)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 24) {
            Button(action: { showingImagePicker = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                    Text("Cutout").font(.caption2)
                }
            }

            Button(action: { showingNotePrompt = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.title2)
                    Text("Post-it").font(.caption2)
                }
            }

            Button(action: addEmojiSticker) {
                VStack(spacing: 4) {
                    Image(systemName: "face.smiling")
                        .font(.title2)
                    Text("Sticker").font(.caption2)
                }
            }

            Button(action: addLetter) {
                VStack(spacing: 4) {
                    Image(systemName: "character")
                        .font(.title2)
                    Text("Letter").font(.caption2)
                }
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func saveAndSyncWidget() {
        do {
            try MatStorageService.shared.saveMat(mat)
            // Trigger WidgetKit reload
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            print("Failed to save mat: \(error)")
        }
    }

    private func addEmojiSticker() {
        let emojis = ["✨", "❤️", "☕️", "🐶", "🌿", "🥐", "📷"]
        let randomEmoji = emojis.randomElement() ?? "✨"
        let newItem = MatItem(
            type: .sticker(emoji: randomEmoji),
            x: 0.5,
            y: 0.5,
            scale: 1.0,
            rotationDegrees: Double.random(in: -15...15),
            zIndex: Double(mat.items.count)
        )
        mat.items.append(newItem)
        selectedItemId = newItem.id
    }

    private func addLetter() {
        let sampleLetters = ["A", "M", "O", "R", "L", "O", "V", "E"]
        let newItem = MatItem(
            type: .letter(char: sampleLetters.randomElement() ?? "M", style: "paper"),
            x: 0.5,
            y: 0.5,
            scale: 1.0,
            rotationDegrees: Double.random(in: -10...10),
            zIndex: Double(mat.items.count)
        )
        mat.items.append(newItem)
        selectedItemId = newItem.id
    }
}

// MARK: - Gesture Enabled Draggable Item
struct DraggableItemView: View {
    @Binding var item: MatItem
    let containerSize: CGSize
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var currentRotation: Angle = .zero
    @State private var currentScale: CGFloat = 1.0

    var body: some View {
        let posX = item.x * containerSize.width + dragOffset.width
        let posY = item.y * containerSize.height + dragOffset.height

        contentView
            .scaleEffect(item.scale * currentScale)
            .rotationEffect(.degrees(item.rotationDegrees) + currentRotation)
            .position(x: posX, y: posY)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    .position(x: posX, y: posY)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onSelect()
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let deltaX = value.translation.width / containerSize.width
                        let deltaY = value.translation.height / containerSize.height
                        item.x = min(max(item.x + deltaX, 0.05), 0.95)
                        item.y = min(max(item.y + deltaY, 0.05), 0.95)
                        dragOffset = .zero
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { angle in currentRotation = angle }
                    .onEnded { angle in
                        item.rotationDegrees += angle.degrees
                        currentRotation = .zero
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in currentScale = scale }
                    .onEnded { scale in
                        item.scale = min(max(item.scale * scale, 0.5), 2.5)
                        currentScale = 1.0
                    }
            )
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.type {
        case .cutout(let fileName):
            if let image = MatStorageService.shared.loadCutoutImage(fileName: fileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: containerSize.width * 0.45)
                    .shadow(radius: 5)
            }
        case .postIt(let text, let colorHex):
            Text(text)
                .font(.system(size: 13, design: .serif))
                .padding(10)
                .frame(width: 100, height: 90)
                .background(Color(hex: colorHex))
                .cornerRadius(4)
                .shadow(radius: 3)
        case .letter(let char, _):
            Text(char)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black)
                .cornerRadius(6)
        case .sticker(let emoji):
            Text(emoji)
                .font(.system(size: 40))
        case .polaroid(let fileName, let caption):
            VStack(spacing: 4) {
                if let image = MatStorageService.shared.loadCutoutImage(fileName: fileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipped()
                }
                Text(caption)
                    .font(.caption2)
            }
            .padding(6)
            .background(Color.white)
            .cornerRadius(4)
        }
    }
}
