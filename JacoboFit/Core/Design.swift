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
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26))
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
