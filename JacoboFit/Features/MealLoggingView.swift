import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import NutritionCore

struct MealLoggingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Meal.date, order: .reverse) private var meals: [Meal]
    @State private var draft = MealDraft()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showEditor = false
    @State private var showManual = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var isLoadingPhoto = false
    @State private var notice: String?
    private var groups: [Date] { Set(meals.map { Calendar.current.startOfDay(for: $0.date) }).sorted(by: >) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Surface {
                    Label("MENOS FRICCIÓN, MÁS CONTEXTO", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.teal)
                    Text("Tu comida,\nsin complicaciones.").font(.largeTitle.bold())
                    Text("Foto → revisá la estimación → guardá.").foregroundStyle(.secondary)
                    Label("Modo demo · la IA usa una muestra fija", systemImage: "info.circle").font(.footnote).foregroundStyle(.orange)
                    if draft.photo != nil { FoodImage(data: draft.photo, height: 210) }
                    HStack {
                        Button { Task { await openCamera() } } label: { Label("Tomar foto", systemImage: "camera") }
                            .primaryActionStyle()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Elegir", systemImage: "photo") }
                            .buttonStyle(.bordered)
                    }.disabled(draft.isAnalyzing || isLoadingPhoto)
                    TextField("O describí tu comida…", text: $draft.description, axis: .vertical)
                        .textFieldStyle(.roundedBorder).disabled(draft.isAnalyzing)
                    Button {
                        analysisTask = Task {
                            await draft.analyze()
                            if draft.analysis != nil { showEditor = true }
                        }
                    } label: {
                        HStack {
                            if draft.isAnalyzing || isLoadingPhoto { ProgressView().tint(.white) }
                            Text(draft.isAnalyzing ? "Analizando tu comida…" : isLoadingPhoto ? "Preparando foto…" : "Analizar comida")
                                .fontWeight(.semibold)
                            Spacer(); Image(systemName: "sparkles")
                        }.padding(.vertical, 10)
                    }.primaryActionStyle().disabled(draft.isAnalyzing || isLoadingPhoto)
                    Button("Prefiero registrar manualmente") { showManual = true }.font(.subheadline)
                }
                HStack { Text("Tu historial").font(.title2.bold()); Spacer(); Text("\(meals.count) comidas").foregroundStyle(.secondary) }
                if meals.isEmpty {
                    ContentUnavailableView("Tu historia empieza acá", systemImage: "fork.knife", description: Text("Registrá tu primera comida. Las fotos se guardan solo en tu dispositivo."))
                }
                ForEach(groups, id: \.self) { date in
                    let entries = meals.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
                    Text(date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                    ForEach(entries) { meal in
                        NavigationLink { MealDetailView(meal: meal) } label: { MealCard(meal: meal) }.buttonStyle(.plain)
                    }
                    Text("Total estimado: \(entries.reduce(0) { $0 + $1.total.calories }.roundedText) kcal")
                        .font(.subheadline.bold()).foregroundStyle(.secondary)
                }
            }.padding()
        }.background { AppBackdrop() }.navigationTitle("Registro")
        .onChange(of: selectedPhoto) { _, item in
            Task {
                isLoadingPhoto = true
                defer { isLoadingPhoto = false }
                do {
                    guard let data = try await item?.loadTransferable(type: Data.self), let photo = PhotoSupport.normalized(data) else {
                        notice = "No pudimos abrir esa imagen. Elegí otra foto."; return
                    }
                    draft.photo = photo
                } catch { notice = error.localizedDescription }
            }
        }
        .sheet(isPresented: $showCamera) { CameraPicker { draft.photo = $0 }.ignoresSafeArea() }
        .sheet(isPresented: $showEditor) {
            if let original = draft.original, let analysis = draft.analysis {
                NavigationStack { MealEditorView(initial: analysis, original: original, photo: draft.photo, category: draft.category) {
                    draft.reset(); selectedPhoto = nil
                } }
            }
        }
        .sheet(isPresented: $showManual) {
            NavigationStack { MealEditorView(initial: .init(mealName: "Mi comida", items: []), original: nil, photo: draft.photo, category: draft.category) { draft.reset(); selectedPhoto = nil } }
        }
        .alert("Registro", isPresented: Binding(get: { notice != nil || draft.error != nil }, set: { if !$0 { notice = nil; draft.error = nil } })) {
            Button("Cerrar") { notice = nil; draft.error = nil }
        } message: { Text(notice ?? draft.error ?? "") }
        .onDisappear { analysisTask?.cancel() }
    }
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { notice = "No hay cámara disponible. En el simulador usá Elegir foto."; return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized { showCamera = true }
        else if status == .notDetermined, await AVCaptureDevice.requestAccess(for: .video) { showCamera = true }
        else { notice = "Activá el permiso de cámara en Ajustes para tomar una foto. También podés elegir una imagen." }
    }
}
