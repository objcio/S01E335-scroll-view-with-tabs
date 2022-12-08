import SwiftUI

struct FramePreference: PreferenceKey {
    static var defaultValue: [Namespace.ID: CGRect] = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}

enum StickyRects: EnvironmentKey {
    static var defaultValue: [Namespace.ID: CGRect]? = nil
}

extension EnvironmentValues {
    var stickyRects: StickyRects.Value {
        get { self[StickyRects.self] }
        set { self[StickyRects.self] = newValue }
    }
}

struct Sticky: ViewModifier {
    @Environment(\.stickyRects) var stickyRects
    @State var frame: CGRect = .zero
    @Namespace private var id

    var isSticking: Bool {
        frame.minY < 0
    }

    var offset: CGFloat {
        guard isSticking else { return 0 }
        guard let stickyRects else {
            print("Warning: Using .sticky() without .useStickyHeaders()")
            return 0
        }
        var o = -frame.minY
        if let other = stickyRects.first(where: { (key, value) in
            key != id && value.minY > frame.minY && value.minY < frame.height

        }) {
            o -= frame.height - other.value.minY
        }
        return o
    }

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .zIndex(isSticking ? .infinity : 0)
            .overlay(GeometryReader { proxy in
                let f = proxy.frame(in: .named("container"))
                Color.clear
                    .onAppear { frame = f }
                    .onChange(of: f) { frame = $0 }
                    .preference(key: FramePreference.self, value: [id: frame])
            })
    }
}

extension View {
    func sticky() -> some View {
        modifier(Sticky())
    }
}

struct UseStickyHeaders: ViewModifier {
    @State private var frames: StickyRects.Value = [:]

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(FramePreference.self, perform: {
                frames = $0
            })
            .environment(\.stickyRects, frames)
            .coordinateSpace(name: "container")
    }
}

extension View {
    func useStickyHeaders() -> some View {
        modifier(UseStickyHeaders())
    }
}

enum Tab: Hashable, CaseIterable, Identifiable {
    case photos
    case videos

    var id: Self { self }

    var image: Image {
        switch self {
        case .photos: return Image(systemName: "photo")
        case .videos: return Image(systemName: "video")
        }
    }
}

extension View {
    func measureTop(in coordinateSpace: CoordinateSpace, perform: @escaping (CGFloat) -> ()) -> some View {
        overlay(alignment: .top) {
            GeometryReader { proxy in
                let top = proxy.frame(in: coordinateSpace).minY
                Color.clear
                    .onAppear {
                        perform(top)
                    }.onChange(of: top, perform: perform)
            }
        }
    }
}

struct ContentView: View {
    @State var selectedTab = Tab.photos
    @State var scrollOffset: [Tab: CGFloat] = [:]

    let items1 = (0...50).map { _ in Item() }
    let items2 = (0...50).map { _ in Item(saturation: 0.3) }

    var body: some View {
        ScrollView {
            contents
                .measureTop(in: .named("OutsideScrollView")) { top in
                    scrollOffset[selectedTab] = top
                }
        }
        .coordinateSpace(name: "OutsideScrollView")
        .useStickyHeaders()
        .overlay {
            HStack {
                Text(verbatim: "\(scrollOffset.mapValues { Int($0) })")
            }
            .foregroundColor(.white)
            .padding(2)
            .background(.black)
        }
    }

    @ViewBuilder var contents: some View {
        Image(systemName: "globe")
            .imageScale(.large)
            .foregroundColor(.accentColor)
            .padding()
        Text("Hello, World!")
            .font(.title)
        Picker("Tab", selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                tab.image
            }
        }
        .background(.background)
        .pickerStyle(.segmented)
        .sticky()
        LazyVGrid(columns: [.init(.adaptive(minimum: 100))]) {
            ForEach(selectedTab == .photos ? items1 : items2) { item in
                item.color
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
