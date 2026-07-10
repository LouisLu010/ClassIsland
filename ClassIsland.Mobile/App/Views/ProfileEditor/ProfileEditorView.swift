import SwiftUI
import UniformTypeIdentifiers

enum ProfileEditorSection: String, CaseIterable, Identifiable {
    case classPlans
    case timeLayouts
    case subjects
    case groups
    case orderedSchedules

    var id: Self { self }

    var title: String {
        switch self {
        case .classPlans: "课表"
        case .timeLayouts: "时间表"
        case .subjects: "科目"
        case .groups: "课表群"
        case .orderedSchedules: "预定"
        }
    }

    var systemImage: String {
        switch self {
        case .classPlans: "calendar"
        case .timeLayouts: "tablecells"
        case .subjects: "books.vertical"
        case .groups: "folder"
        case .orderedSchedules: "calendar.badge.clock"
        }
    }
}

struct ProfileEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var draft: ClassIslandProfile?
    @State private var baseline: ClassIslandProfile?
    @State private var selectedSection = ProfileEditorSection.classPlans
    @State private var errorMessage = ""
    @State private var isErrorPresented = false
    @State private var isCreateSheetPresented = false
    @State private var createProfileName = "新档案"
    @State private var createProfileError = ""
    @State private var isCreatingProfile = false
    @State private var isSaving = false
    @State private var isExporterPresented = false
    @State private var exportDocument: ProfileFileDocument?

    private var hasUnsavedChanges: Bool {
        draft != nil && draft != baseline
    }

    private var issues: [ProfileValidationIssue] {
        draft.map { ProfileEditingService.validationIssues(for: $0) } ?? []
    }

    var body: some View {
        Group {
            if draft != nil {
                editor
            } else {
                emptyState
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("档案编辑")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { editorToolbar }
        .task {
            loadProfileIfNeeded()
        }
        .onChange(of: model.profile) { _, profile in
            guard !hasUnsavedChanges else { return }
            load(profile)
        }
        .onDisappear {
            saveValidChangesIfNeeded()
        }
        .sheet(isPresented: $isCreateSheetPresented) {
            createProfileSheet
        }
        .alert("无法完成操作", isPresented: $isErrorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fileExporter(
            isPresented: $isExporterPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Profile.json"
        ) { result in
            if case .failure(let error) = result {
                present(error)
            }
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            ProfileEditorSectionBar(selection: $selectedSection)
            Divider()

            VStack(spacing: 12) {
                profileHeader
                if let issue = issues.first {
                    ProfileIssueBanner(issue: issue)
                }
            }
            .frame(maxWidth: 980)
            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
            .padding(.top, 16)
            .frame(maxWidth: .infinity)

            editorContent
                .frame(maxWidth: 980, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            Image("ClassIslandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                TextField("档案名称", text: profileNameBinding)
                    .font(.headline)
                    .textFieldStyle(.plain)
                if let draft {
                    Text("\(draft.classPlans.count) 个课表 · \(draft.timeLayouts.count) 个时间表 · \(draft.subjects.count) 个科目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if hasUnsavedChanges {
                Label("未保存", systemImage: "circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.16))
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        if let binding = draftBinding {
            switch selectedSection {
            case .classPlans:
                ClassPlansEditorView(profile: binding, onError: present)
            case .timeLayouts:
                TimeLayoutsEditorView(profile: binding, onError: present)
            case .subjects:
                SubjectsEditorView(profile: binding, onError: present)
            case .groups:
                ClassPlanGroupsEditorView(profile: binding, onError: present)
            case .orderedSchedules:
                OrderedSchedulesEditorView(profile: binding, onError: present)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有可编辑的档案", systemImage: "doc.badge.plus")
        } description: {
            Text("新建档案后即可编辑科目、时间表和每周课表。")
        } actions: {
            Button("新建档案", systemImage: "plus") {
                createProfileName = "新档案"
                createProfileError = ""
                isCreateSheetPresented = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if draft != nil {
                Menu {
                    Button("重新载入", systemImage: "arrow.counterclockwise") {
                        load(model.profile)
                    }
                    .disabled(!hasUnsavedChanges)

                    Button("导出档案", systemImage: "square.and.arrow.up") {
                        prepareExport()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("更多")

                Button("保存", systemImage: "checkmark") {
                    save()
                }
                .disabled(!hasUnsavedChanges || isSaving || issues.contains { $0.severity == .error })
            }
        }
    }

    private var createProfileSheet: some View {
        NavigationStack {
            Form {
                Section("档案信息") {
                    TextField("档案名称", text: $createProfileName)
                        .disabled(isCreatingProfile)
                }

                if !createProfileError.isEmpty {
                    Section {
                        Label(createProfileError, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("新建档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isCreateSheetPresented = false }
                        .disabled(isCreatingProfile)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createProfileError = ""
                        isCreatingProfile = true
                        Task {
                            if await model.createProfile(named: createProfileName) {
                                load(model.profile)
                                isCreateSheetPresented = false
                            } else {
                                createProfileError = model.statusMessage
                            }
                            isCreatingProfile = false
                        }
                    }
                    .disabled(
                        isCreatingProfile
                            || createProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var profileNameBinding: Binding<String> {
        Binding(
            get: { draft?.name ?? "" },
            set: { draft?.name = $0 }
        )
    }

    private var draftBinding: Binding<ClassIslandProfile>? {
        guard draft != nil else { return nil }
        return Binding(
            get: { draft ?? ClassIslandProfile.newProfile() },
            set: { draft = $0 }
        )
    }

    private func loadProfileIfNeeded() {
        guard draft == nil else { return }
        load(model.profile)
    }

    private func load(_ profile: ClassIslandProfile?) {
        draft = profile
        baseline = profile
    }

    private func save() {
        guard let draft, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await model.saveProfile(draft)
            isSaving = false
            if saved {
                load(model.profile)
            } else {
                present(ProfileEditingError.validationFailed(model.statusMessage))
            }
        }
    }

    private func saveValidChangesIfNeeded() {
        guard hasUnsavedChanges,
              !issues.contains(where: { $0.severity == .error }) else { return }
        save()
    }

    private func prepareExport() {
        guard let draft else { return }
        do {
            let data = try ProfileDocumentCodec.encode(draft, preserving: try? model.profileDocumentData())
            exportDocument = ProfileFileDocument(data: data)
            isExporterPresented = true
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        isErrorPresented = true
    }
}

private struct ProfileEditorSectionBar: View {
    @Binding var selection: ProfileEditorSection

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ProfileEditorSection.allCases) { section in
                    Button {
                        withAnimation(.snappy) { selection = section }
                    } label: {
                        Label(section.title, systemImage: section.systemImage)
                            .font(.subheadline.weight(selection == section ? .semibold : .regular))
                            .foregroundStyle(selection == section ? Color.accentColor : Color.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(selection == section ? Color.accentColor.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == section ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.regularMaterial)
    }
}

private struct ProfileIssueBanner: View {
    let issue: ProfileValidationIssue

    private var color: Color {
        issue.severity == .error ? .red : .orange
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.severity == .error ? "exclamationmark.octagon" : "exclamationmark.triangle")
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.subheadline.weight(.semibold))
                Text(issue.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct ProfileFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
