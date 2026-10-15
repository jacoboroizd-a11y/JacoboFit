import SwiftUI
import SwiftData
import NutritionCore

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Meal.date, order: .reverse) private var meals: [Meal]
    @Query private var goals: [NutritionGoal]
    @Query private var profiles: [UserProfile]
    @Query private var water: [WaterEntry]
    @State private var health = HealthKitService()
    @State private var error: String?
    @State private var showWeight = false
    var openLogging: () -> Void
    private var today: [Meal] { meals.filter { Calendar.current.isDateInToday($0.date) } }
    private var total: Nutrients { today.reduce(.zero) { $0 + $1.total } }
    private var waterTotal: Double { water.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.ounces } }
    private var expenditure: EnergyEstimate? {
        // Basal samples cover today so far, not a 24-hour projection.
        EstimatedTDEEService.estimate(restingEnergy: health.activity.restingCalories,
            activeEnergy: health.activity.activeCalories,
            workoutEnergy: health.activity.workouts.reduce(0) { $0 + ($1.calories ?? 0) },
            manualRestingEstimate: profiles.first.flatMap { $0.restingEnergyEstimate > 0 ? $0.restingEnergyEstimate : nil },
            consumed: total.calories)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.subheadline).foregroundStyle(.secondary)
                        Text("Vamos a cuidarte,\n\(profiles.first?.name ?? "Jacobo").").font(.largeTitle.bold())
                    }
                    Spacer()
                    NavigationLink { SettingsView() } label: { Image(systemName: "slider.horizontal.3").font(.title3).padding(12).background(.teal.opacity(0.1), in: Circle()) }
                        .accessibilityLabel("Ajustes")
                }
                Surface {
                    Label("TU DÍA, DE UN VISTAZO", systemImage: "sun.max.fill").font(.caption.bold()).foregroundStyle(.teal)
                    HStack(alignment: .firstTextBaseline) {
                        Text("~\(total.calories.roundedText)").font(.system(size: 49, weight: .bold, design: .rounded)).minimumScaleFactor(0.6)
                        Text("/ \((goals.first?.calories ?? 1800).roundedText) kcal").foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(total.calories, goals.first?.calories ?? 1800), total: max(1, goals.first?.calories ?? 1800)).tint(.teal)
                    Text("Calorías consumidas · estimación").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    HStack { Text("Proteína").font(.headline); Spacer(); Text("\(total.protein.roundedText) / \((goals.first?.protein ?? 170).roundedText) g").bold() }
                    ProgressView(value: min(total.protein, goals.first?.protein ?? 170), total: max(1, goals.first?.protein ?? 170)).tint(.orange).scaleEffect(x: 1, y: 1.8)
                    NutritionLine(nutrition: total)
                }
                Surface {
                    Text("Balance estimado").font(.title3.bold())
                    balanceRow("Consumido", value: "~\(total.calories.roundedText) kcal")
                    balanceRow(health.activity.restingCalories == nil ? "Gasto estimado del día" : "Gasto registrado hasta ahora", value: expenditure.map { "~\($0.totalExpenditure.roundedText) kcal" } ?? "Sin base suficiente")
                    balanceRow("Balance (− = déficit)", value: expenditure.map { "\($0.balance.roundedText) kcal" } ?? "—")
                    if let estimate = expenditure, estimate.balance < -1000 {
                        Text("El déficit estimado es elevado. El gasto y las estimaciones de alimentos pueden tener margen de error.").font(.footnote).foregroundStyle(.orange)
                    }
                    Text(health.activity.restingCalories != nil
                         ? "Health refleja muestras de hoy hasta ahora; este balance cambia durante el día. La energía activa ya incluye los entrenamientos."
                         : "Configurá tu gasto en reposo estimado en Ajustes o conectá Health. Sin datos de actividad, el cálculo solo incluye la base disponible.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Surface {
                    HStack { Text("Actividad de hoy").font(.title3.bold()); Spacer(); if health.isLoading { ProgressView() } }
                    HStack {
                        activityStat("flame.fill", title: "kcal activas", value: health.activity.activeCalories?.roundedText)
                        Spacer(); activityStat("figure.walk", title: "pasos", value: health.activity.steps?.roundedText)
                    }
                    HStack {
                        activityStat("figure.strengthtraining.traditional", title: "min ejercicio", value: health.activity.exerciseMinutes?.roundedText)
                        Spacer(); activityStat("location.fill", title: "km", value: health.activity.kilometers?.quantityText)
                    }
                    ForEach(health.activity.workouts) { workout in
                        Label("\(workout.name) · \(workout.minutes.roundedText) min · \(workout.calories.map { "~\($0.roundedText) kcal" } ?? "sin kcal")", systemImage: "figure.strengthtraining.traditional").font(.subheadline)
                    }
                    if let weight = health.activity.latestWeightLB { Text("Último peso en Health: \(weight.quantityText) lb").font(.caption).foregroundStyle(.secondary) }
                    Button("Conectar / actualizar Apple Health") { Task { await health.connect() } }.disabled(health.isLoading)
                    if let message = health.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                Surface {
                    HStack { Label("Agua", systemImage: "drop.fill").font(.headline); Spacer(); Text("\(waterTotal.roundedText) / \((goals.first?.waterOunces ?? 96).roundedText) oz") }
                    HStack {
                        ForEach([8, 12, 16, 24], id: \.self) { amount in
                            Button("+\(amount)") { context.insert(WaterEntry(ounces: Double(amount))); save() }.buttonStyle(.bordered)
                                .accessibilityLabel("Agregar \(amount) onzas de agua")
                        }
                    }
                }
                HStack { Text("Tus comidas de hoy").font(.title2.bold()); Spacer(); Button("Registrar", action: openLogging) }
                if today.isEmpty { ContentUnavailableView("Un nuevo día", systemImage: "camera", description: Text("Tu próxima comida empieza con una foto.")) }
                ForEach(today) { meal in
                    NavigationLink { MealDetailView(meal: meal) } label: { MealCard(meal: meal) }.buttonStyle(.plain)
                }
                NavigationLink { TrendsView() } label: { Label("Ver tendencias", systemImage: "chart.xyaxis.line").font(.headline).frame(maxWidth: .infinity).padding() }.buttonStyle(.bordered)
            }.padding().padding(.bottom, 72)
        }.background { AppBackdrop() }.navigationTitle("Hoy").navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            Menu {
                Button("Tomar foto / registrar comida", systemImage: "camera", action: openLogging)
                Button("Registrar peso", systemImage: "scalemass") { showWeight = true }
                Button("Agregar 12 oz de agua", systemImage: "drop") { context.insert(WaterEntry(ounces: 12)); save() }
                NavigationLink { RecipeEditorView() } label: { Label("Crear receta", systemImage: "book") }
            } label: { Image(systemName: "plus").font(.title2.bold()).foregroundStyle(.white).padding(23).background(.teal, in: Circle()).shadow(color: .teal.opacity(0.3), radius: 12, y: 6) }
                .accessibilityLabel("Registro rápido").padding(22)
        }
        .sheet(isPresented: $showWeight) { NavigationStack { WeightEditorView() } }
        .refreshable { await health.refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await health.refresh() } } }
        .alert("No se pudo guardar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Cerrar") { error = nil } } message: { Text(error ?? "") }
    }
    private func balanceRow(_ title: String, value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.semibold) }.font(.subheadline)
    }
    private func activityStat(_ symbol: String, title: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) { Label(value ?? "—", systemImage: symbol).font(.title3.bold()).foregroundStyle(.teal); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func save() { do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription } }
}
