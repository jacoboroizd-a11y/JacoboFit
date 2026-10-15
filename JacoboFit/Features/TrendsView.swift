import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Query(sort: \Meal.date) private var meals: [Meal]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @State private var days = 7
    private var start: Date { Calendar.current.date(byAdding: .day, value: 1 - days, to: Calendar.current.startOfDay(for: .now))! }
    private var filtered: [Meal] { meals.filter { $0.date >= start && $0.date <= .now } }
    private var totals: [(date: Date, calories: Double, protein: Double)] {
        Dictionary(grouping: filtered, by: { Calendar.current.startOfDay(for: $0.date) }).map { date, meals in
            (date, meals.reduce(0) { $0 + $1.total.calories }, meals.reduce(0) { $0 + $1.total.protein })
        }.sorted { $0.date < $1.date }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Picker("Período", selection: $days) { ForEach([7, 30, 90], id: \.self) { Text("\($0) días").tag($0) } }.pickerStyle(.segmented)
                if totals.isEmpty { ContentUnavailableView("Todavía no hay tendencias", systemImage: "chart.xyaxis.line", description: Text("Registrá comidas para ver cómo cambian tus hábitos.")) }
                else {
                    Surface {
                        Text("Calorías consumidas").font(.headline)
                        Chart(totals, id: \.date) { day in BarMark(x: .value("Día", day.date, unit: .day), y: .value("kcal", day.calories)).foregroundStyle(.teal) }.frame(height: 200)
                        Text("Promedio por día registrado: ~\((totals.reduce(0) { $0 + $1.calories } / Double(totals.count)).roundedText) kcal").font(.caption).foregroundStyle(.secondary)
                    }
                    Surface {
                        Text("Proteína").font(.headline)
                        Chart(totals, id: \.date) { day in BarMark(x: .value("Día", day.date, unit: .day), y: .value("g", day.protein)).foregroundStyle(.orange) }.frame(height: 170)
                    }
                }
                Surface {
                    Text("Peso registrado · lb").font(.headline)
                    let entries = weights.filter { $0.date >= start }
                    if entries.isEmpty { Text("Agregá tu peso desde el botón + de Hoy.").foregroundStyle(.secondary) }
                    else { Chart(entries) { entry in LineMark(x: .value("Fecha", entry.date), y: .value("lb", entry.pounds)).symbol(.circle).foregroundStyle(.teal) }.frame(height: 180) }
                }
                Text("Los días sin registros no se cuentan como cero. El historial de actividad y balance de Health se incorporará en una etapa posterior.").font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle("Tendencias")
    }
}
