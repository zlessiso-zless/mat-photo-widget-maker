import SwiftUI
import WidgetKit

public struct MatWidgetCanvasView: View {
    public let mat: MatBoard

    public init(mat: MatBoard) {
        self.mat = mat
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background Mat texture/color
                Color(hex: mat.backgroundColorHex)
                    .overlay(
                        // Subtle grain / paper edge
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                // Render placed items
                ForEach(mat.items.sorted(by: { $0.zIndex < $1.zIndex })) { item in
                    renderItem(item, in: geo.size)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func renderItem(_ item: MatItem, in size: CGSize) -> some View {
        let posX = item.x * size.width
        let posY = item.y * size.height

        Group {
            switch item.type {
            case .cutout(let fileName):
                if let uiImage = MatStorageService.shared.loadCutoutImage(fileName: fileName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width * 0.45 * item.scale)
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 2, y: 4)
                }
            case .postIt(let text, let colorHex):
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundColor(Color.black.opacity(0.85))
                        .lineLimit(4)
                }
                .padding(8)
                .frame(width: 85 * item.scale, height: 75 * item.scale)
                .background(Color(hex: colorHex))
                .cornerRadius(4)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 1, y: 3)

            case .letter(let char, _):
                Text(char)
                    .font(.system(size: 32 * item.scale, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 2)

            case .sticker(let emoji):
                Text(emoji)
                    .font(.system(size: 36 * item.scale))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 2)

            case .polaroid(let fileName, let caption):
                VStack(spacing: 4) {
                    if let uiImage = MatStorageService.shared.loadCutoutImage(fileName: fileName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70 * item.scale, height: 70 * item.scale)
                            .clipped()
                    }
                    Text(caption)
                        .font(.system(size: 8, weight: .regular, design: .handwriting))
                        .foregroundColor(.black.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(6)
                .padding(.bottom, 10)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(color: .black.opacity(0.15), radius: 5, x: 2, y: 4)
            }
        }
        .rotationEffect(.degrees(item.rotationDegrees))
        .position(x: posX, y: posY)
    }
}

// MARK: - WidgetKit Entry & Provider
public struct MatWidgetEntry: TimelineEntry {
    public let date: Date
    public let mat: MatBoard
}

public struct MatWidgetProvider: TimelineProvider {
    public func placeholder(in context: Context) -> MatWidgetEntry {
        MatWidgetEntry(date: Date(), mat: MatBoard(title: "Preview"))
    }

    public func getSnapshot(in context: Context, completion: @escaping (MatWidgetEntry) -> Void) {
        let mat = MatStorageService.shared.loadMat() ?? MatBoard()
        completion(MatWidgetEntry(date: Date(), mat: mat))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<MatWidgetEntry>) -> Void) {
        let currentMat = MatStorageService.shared.loadMat() ?? MatBoard()
        let entry = MatWidgetEntry(date: Date(), mat: currentMat)
        // Refresh every 2 hours or when user edits in the main app
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

public struct MatPhotoWidget: Widget {
    public let kind: String = "MatPhotoWidget"

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MatWidgetProvider()) { entry in
            MatWidgetCanvasView(mat: entry.mat)
                .containerBackground(Color.clear, for: .widget)
        }
        .configurationDisplayName("Mat Photo Collage")
        .description("Your favorite photo cutouts, notes, and memories on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Color Hex Extension Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 240, 237, 226)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
