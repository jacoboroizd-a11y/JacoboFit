import SwiftUI
import UIKit
import NutritionCore

extension Double {
    var roundedText: String { formatted(.number.precision(.fractionLength(0))) }
    var quantityText: String { formatted(.number.precision(.fractionLength(0...2))) }
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassSurface(radius: 26))
    }
}

struct NutritionLine: View {
    let nutrition: Nutrients
    var body: some View {
        HStack(spacing: 14) {
            Label("\(nutrition.protein.roundedText) g", systemImage: "p.circle.fill").foregroundStyle(.teal)
            Text("C \(nutrition.carbs.roundedText) g")
            Text("G \(nutrition.fat.roundedText) g")
        }.font(.subheadline).foregroundStyle(.secondary).accessibilityElement(children: .combine)
    }
}

struct FoodImage: View {
    var data: Data?
    var symbol: String = "fork.knife"
    var height: CGFloat = 150
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.teal.opacity(0.35), .mint.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: symbol).font(.system(size: 42, weight: .light)).foregroundStyle(.teal)
                }
            }
        }.frame(height: height).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct MealCard: View {
    let meal: Meal
    var body: some View {
        Surface {
            FoodImage(data: meal.photo)
            HStack {
                Text(meal.category.uppercased()).font(.caption.bold()).foregroundStyle(.teal)
                Spacer()
                Text(meal.date, style: .time).font(.caption).foregroundStyle(.secondary)
            }
            Text(meal.name).font(.title3.bold()).foregroundStyle(.primary)
            Text("~\(meal.total.calories.roundedText) kcal").font(.title2.bold()).foregroundStyle(.primary)
            NutritionLine(nutrition: meal.total)
        }
    }
}

/// Compile-time guard keeps the project buildable with Xcode 16.4 (Swift 6.1).
/// The runtime guard enables the system effect only on supported devices.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 26
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).stroke(.primary.opacity(0.15)))
        } else {
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
            } else { legacySurface(content) }
            #else
            legacySurface(content)
            #endif
        }
    }
    private func legacySurface(_ content: Content) -> some View {
        content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(
                LinearGradient(colors: [.white.opacity(contrast == .increased ? 0.8 : 0.65), .white.opacity(0.08), .teal.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }
}

struct AppBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            if !reduceTransparency {
                GeometryReader { geometry in
                    Circle().fill(.mint.opacity(scheme == .dark ? 0.16 : 0.25))
                        .frame(width: geometry.size.width * 1.2).blur(radius: 65)
                        .offset(x: -geometry.size.width * 0.35, y: -120)
                    Circle().fill(.cyan.opacity(scheme == .dark ? 0.12 : 0.16))
                        .frame(width: geometry.size.width).blur(radius: 70)
                        .offset(x: geometry.size.width * 0.45, y: geometry.size.height * 0.35)
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

extension View {
    @ViewBuilder func primaryActionStyle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { self.buttonStyle(.glassProminent) }
        else { self.buttonStyle(.borderedProminent) }
        #else
        self.buttonStyle(.borderedProminent)
        #endif
    }
}

struct AdaptiveTabBar: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { content }
        else { content.toolbarBackground(.regularMaterial, for: .tabBar).toolbarBackground(.visible, for: .tabBar) }
        #else
        content.toolbarBackground(.regularMaterial, for: .tabBar).toolbarBackground(.visible, for: .tabBar)
        #endif
    }
}
