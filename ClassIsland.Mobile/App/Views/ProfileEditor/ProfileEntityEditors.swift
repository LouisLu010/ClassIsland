import SwiftUI

struct SubjectsEditorView: View {
    @Binding var profile: ClassIslandProfile
    let onError: (Error) -> Void

    @State private var editingSubject: SubjectEditorDraft?

    private var subjects: [(key: String, value: ClassIslandSubject)] {
        ProfileEditingService.sortedEntries(profile.subjects)
    }

    var body: some View {
        List {
            Section {
                ForEach(subjects, id: \.key) { entry in
                    Button {
                        editingSubject = SubjectEditorDraft(sourceId: entry.key, value: entry.value)
                    } label: {
                        SubjectRow(subject: entry.value)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("删除", systemImage: "trash", role: .destructive) {
                            remove(entry.key)
                        }
                    }
                }
            } header: {
                EditorSectionHeader(
                    title: "科目",
                    subtitle: "维护科目名称、简称、教师及户外课程标记。",
                    addTitle: "添加科目"
                ) {
                    editingSubject = SubjectEditorDraft(sourceId: nil, value: ClassIslandSubject(name: "新科目", initial: "新"))
                }
            }
        }
        .editorListStyle()
        .sheet(item: $editingSubject) { draft in
            SubjectEditorSheet(draft: draft) { saved in
                commit(saved)
            }
        }
    }

    private func commit(_ draft: SubjectEditorDraft) -> Bool {
        var updated = profile
        do {
            let id = draft.sourceId ?? ProfileEditingService.addSubject(to: &updated)
            try ProfileEditingService.updateSubject(id: id, value: draft.value, in: &updated)
            profile = updated
            return true
        } catch {
            onError(error)
            return false
        }
    }

    private func remove(_ id: String) {
        var updated = profile
        do {
            try ProfileEditingService.removeSubject(id: id, from: &updated)
            profile = updated
        } catch {
            onError(error)
        }
    }
}

private struct SubjectRow: View {
    let subject: ClassIslandSubject

    var body: some View {
        HStack(spacing: 12) {
            Text(subject.initial.isEmpty ? String(subject.name.prefix(1)) : String(subject.initial.prefix(2)))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.name)
                    .font(.body.weight(.medium))
                Text(subject.teacherName.isEmpty ? "未填写任课教师" : subject.teacherName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            if subject.isOutdoor {
                Image(systemName: "figure.run")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("户外课程")
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct SubjectEditorDraft: Identifiable {
    let id = UUID()
    let sourceId: String?
    var value: ClassIslandSubject
}

private struct SubjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sourceId: String?
    let onSave: (SubjectEditorDraft) -> Bool
    @State private var value: ClassIslandSubject

    init(draft: SubjectEditorDraft, onSave: @escaping (SubjectEditorDraft) -> Bool) {
        sourceId = draft.sourceId
        self.onSave = onSave
        _value = State(initialValue: draft.value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("科目信息") {
                    TextField("名称", text: $value.name)
                    TextField("简称", text: $value.initial)
                        .onChange(of: value.initial) { _, newValue in
                            if newValue.count > 4 {
                                value.initial = String(newValue.prefix(4))
                            }
                        }
                    TextField("任课教师", text: $value.teacherName)
                    Toggle("户外课程", isOn: $value.isOutdoor)
                }
            }
            .navigationTitle(sourceId == nil ? "添加科目" : "编辑科目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if onSave(SubjectEditorDraft(sourceId: sourceId, value: value)) {
                            dismiss()
                        }
                    }
                    .disabled(value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TimeLayoutsEditorView: View {
    @Binding var profile: ClassIslandProfile
    let onError: (Error) -> Void

    @State private var editingLayout: TimeLayoutEditorDraft?

    private var layouts: [(key: String, value: ClassIslandTimeLayout)] {
        ProfileEditingService.sortedEntries(profile.timeLayouts)
    }

    var body: some View {
        List {
            Section {
                ForEach(layouts, id: \.key) { entry in
                    Button {
                        editingLayout = TimeLayoutEditorDraft(sourceId: entry.key, value: entry.value)
                    } label: {
                        TimeLayoutRow(layout: entry.value)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button("复制", systemImage: "plus.square.on.square") {
                            duplicate(entry.key)
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("删除", systemImage: "trash", role: .destructive) {
                            remove(entry.key)
                        }
                    }
                }
            } header: {
                EditorSectionHeader(
                    title: "时间表",
                    subtitle: "时间点顺序会同步决定课表中的课程顺序。",
                    addTitle: "添加时间表"
                ) {
                    editingLayout = TimeLayoutEditorDraft(sourceId: nil, value: ClassIslandTimeLayout())
                }
            }
        }
        .editorListStyle()
        .sheet(item: $editingLayout) { draft in
            TimeLayoutEditorSheet(draft: draft, profile: profile) { saved in
                commit(saved)
            }
        }
    }

    private func commit(_ draft: TimeLayoutEditorDraft) -> Bool {
        var updated = profile
        do {
            let id = draft.sourceId ?? ProfileEditingService.addTimeLayout(to: &updated)
            try ProfileEditingService.updateTimeLayout(id: id, value: draft.value, in: &updated)
            profile = updated
            return true
        } catch {
            onError(error)
            return false
        }
    }

    private func duplicate(_ id: String) {
        var updated = profile
        _ = ProfileEditingService.addTimeLayout(to: &updated, copying: id)
        profile = updated
    }

    private func remove(_ id: String) {
        var updated = profile
        do {
            try ProfileEditingService.removeTimeLayout(id: id, from: &updated)
            profile = updated
        } catch {
            onError(error)
        }
    }
}

private struct TimeLayoutRow: View {
    let layout: ClassIslandTimeLayout

    private var classCount: Int {
        layout.layouts.filter { $0.timeType == 0 }.count
    }

    private var range: String {
        guard let first = layout.layouts.first, let last = layout.layouts.last else { return "没有时间点" }
        return "\(shortTime(first.startTimeValue))–\(shortTime(last.endTimeValue))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tablecells")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(layout.name)
                    .font(.body.weight(.medium))
                Text("\(classCount) 节课 · \(range)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if layout.isOverlay {
                Text("临时")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct TimeLayoutEditorDraft: Identifiable {
    let id = UUID()
    let sourceId: String?
    var value: ClassIslandTimeLayout
}

private struct TimeLayoutEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sourceId: String?
    let profile: ClassIslandProfile
    let onSave: (TimeLayoutEditorDraft) -> Bool

    @State private var value: ClassIslandTimeLayout
    @State private var editingPoint: TimePointEditorDraft?

    init(
        draft: TimeLayoutEditorDraft,
        profile: ClassIslandProfile,
        onSave: @escaping (TimeLayoutEditorDraft) -> Bool
    ) {
        sourceId = draft.sourceId
        self.profile = profile
        self.onSave = onSave
        _value = State(initialValue: draft.value)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("时间表信息") {
                    TextField("名称", text: $value.name)
                }

                Section {
                    ForEach(value.layouts) { point in
                        Button {
                            editingPoint = TimePointEditorDraft(point: point)
                        } label: {
                            TimePointRow(point: point)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { value.layouts.remove(atOffsets: $0) }
                    .onMove { value.layouts.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("时间点")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("拖动可调整顺序；上课时间点的顺序会同步调整所有关联课表。")
                        if hasInvalidTimePoints {
                            Text("存在无法识别的时间，或结束时间不晚于开始时间。")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(sourceId == nil ? "添加时间表" : "编辑时间表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Menu {
                        Button("上课", systemImage: "book.closed") { addPoint(type: 0) }
                        Button("课间", systemImage: "cup.and.saucer") { addPoint(type: 1) }
                        Button("分割线", systemImage: "minus") { addPoint(type: 2) }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加时间点")

                    Button("保存") {
                        if onSave(TimeLayoutEditorDraft(sourceId: sourceId, value: value)) {
                            dismiss()
                        }
                    }
                    .disabled(
                        value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || !value.layouts.contains { $0.timeType == 0 }
                            || hasInvalidTimePoints
                    )
                }
            }
        }
        .sheet(item: $editingPoint) { draft in
            TimePointEditorSheet(draft: draft, subjects: profile.subjects) { point in
                if let index = value.layouts.firstIndex(where: { $0.id == point.id }) {
                    value.layouts[index] = point
                } else {
                    value.layouts.append(point)
                }
            }
        }
    }

    private func addPoint(type: Int) {
        let previousEnd = value.layouts.last?.endTimeValue ?? "08:00:00"
        let start = timeDate(previousEnd)
        let duration = type == 0 ? 45 : type == 1 ? 10 : 0
        let end = Calendar.current.date(byAdding: .minute, value: duration, to: start) ?? start
        let point = ClassIslandTimePoint(
            startTimeValue: timeString(start),
            endTimeValue: timeString(end),
            timeType: type,
            breakName: type == 1 ? "课间休息" : ""
        )
        editingPoint = TimePointEditorDraft(point: point)
    }

    private var hasInvalidTimePoints: Bool {
        value.layouts.contains { point in
            guard (0...3).contains(point.timeType),
                  let start = ClassIslandDateParser.secondsSinceMidnight(point.startTimeValue),
                  let end = ClassIslandDateParser.secondsSinceMidnight(point.endTimeValue) else {
                return true
            }
            return (point.timeType == 0 || point.timeType == 1) && end <= start
        }
    }
}

private struct TimePointRow: View {
    let point: ClassIslandTimePoint

    private var title: String {
        switch point.timeType {
        case 0: "上课"
        case 1: point.displayBreakName
        case 2: "分割线"
        case 3: "行动"
        default: "未知类型"
        }
    }

    private var icon: String {
        switch point.timeType {
        case 0: "book.closed"
        case 1: "cup.and.saucer"
        case 2: "minus"
        case 3: "bolt"
        default: "questionmark"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(point.timeType == 0 ? Color.accentColor : Color.secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text("\(shortTime(point.startTimeValue))–\(shortTime(point.endTimeValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct TimePointEditorDraft: Identifiable {
    let id = UUID()
    var point: ClassIslandTimePoint
}

private struct TimePointEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let subjects: [String: ClassIslandSubject]
    let onSave: (ClassIslandTimePoint) -> Void

    @State private var point: ClassIslandTimePoint
    @State private var start: Date
    @State private var end: Date

    init(
        draft: TimePointEditorDraft,
        subjects: [String: ClassIslandSubject],
        onSave: @escaping (ClassIslandTimePoint) -> Void
    ) {
        self.subjects = subjects
        self.onSave = onSave
        _point = State(initialValue: draft.point)
        _start = State(initialValue: timeDate(draft.point.startTimeValue))
        _end = State(initialValue: timeDate(draft.point.endTimeValue))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("类型") {
                    Picker("时间点类型", selection: $point.timeType) {
                        Text("上课").tag(0)
                        Text("课间").tag(1)
                        Text("分割线").tag(2)
                        if point.timeType == 3 {
                            Text("行动").tag(3)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("时间") {
                    DatePicker("开始", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("结束", selection: $end, displayedComponents: .hourAndMinute)
                        .disabled(point.timeType == 2 || point.timeType == 3)
                }

                if point.timeType == 0 {
                    Section("课程默认值") {
                        Picker("默认科目", selection: $point.defaultClassId) {
                            Text("未指定").tag(ProfileEditingService.emptyId)
                            ForEach(ProfileEditingService.sortedEntries(subjects), id: \.key) { entry in
                                Text(entry.value.name).tag(entry.key)
                            }
                        }
                        Toggle("默认隐藏", isOn: $point.isHideDefault)
                    }
                } else if point.timeType == 1 {
                    Section("课间") {
                        TextField("课间名称", text: $point.breakName)
                    }
                } else if point.timeType == 3 {
                    Section {
                        Text("桌面端行动配置会被完整保留；移动端暂不修改行动内容。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("编辑时间点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        point.startTimeValue = timeString(start)
                        point.endTimeValue = point.timeType == 2 || point.timeType == 3
                            ? point.startTimeValue
                            : timeString(end)
                        onSave(point)
                        dismiss()
                    }
                    .disabled(hasInvalidRange)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var hasInvalidRange: Bool {
        guard point.timeType == 0 || point.timeType == 1 else { return false }
        let startSeconds = ClassIslandDateParser.secondsSinceMidnight(timeString(start)) ?? 0
        let endSeconds = ClassIslandDateParser.secondsSinceMidnight(timeString(end)) ?? 0
        return endSeconds <= startSeconds
    }
}

struct ClassPlansEditorView: View {
    @Binding var profile: ClassIslandProfile
    let onError: (Error) -> Void

    @State private var editingPlan: ClassPlanEditorDraft?

    private var groupedPlans: [(groupId: String, group: ClassIslandClassPlanGroup, plans: [(key: String, value: ClassIslandClassPlan)])] {
        ProfileEditingService.sortedEntries(profile.classPlanGroups).map { groupEntry in
            let plans = ProfileEditingService.sortedEntries(profile.classPlans).filter {
                $0.value.associatedGroup.caseInsensitiveCompare(groupEntry.key) == .orderedSame
            }
            return (groupEntry.key, groupEntry.value, plans)
        }
    }

    private var orphanPlans: [(key: String, value: ClassIslandClassPlan)] {
        ProfileEditingService.sortedEntries(profile.classPlans).filter { plan in
            profile.key(in: profile.classPlanGroups, matching: plan.value.associatedGroup) == nil
        }
    }

    var body: some View {
        List {
            weeklyOverview

            ForEach(groupedPlans, id: \.groupId) { group in
                if !group.plans.isEmpty {
                    Section(group.group.name) {
                        ForEach(group.plans, id: \.key) { entry in
                            planRow(entry)
                        }
                    }
                }
            }

            if !orphanPlans.isEmpty {
                Section("未分组") {
                    ForEach(orphanPlans, id: \.key) { entry in
                        planRow(entry)
                    }
                }
            }
        }
        .editorListStyle()
        .safeAreaInset(edge: .top) {
            EditorCommandStrip(
                title: "课表",
                subtitle: "按星期与轮换周管理每天使用的课程。",
                addTitle: "添加课表"
            ) {
                createPlan(copying: nil)
            }
        }
        .sheet(item: $editingPlan) { draft in
            ClassPlanEditorSheet(draft: draft, profile: profile) { saved in
                commit(saved)
            }
        }
    }

    private var weeklyOverview: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { weekday in
                        let count = profile.classPlans.values.filter {
                            !$0.isOverlay && $0.timeRule.weekDay == weekday % 7
                        }.count
                        VStack(spacing: 4) {
                            Text(weekdayTitle(weekday % 7))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(count)")
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                            Text("个课表")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: 64, height: 72)
                        .background(Color.accentColor.opacity(count == 0 ? 0.04 : 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("周视图")
        }
    }

    private func planRow(
        _ entry: (key: String, value: ClassIslandClassPlan)
    ) -> some View {
        Button {
            editingPlan = ClassPlanEditorDraft(
                sourceId: entry.key,
                proposedId: entry.key,
                value: entry.value
            )
        } label: {
            ClassPlanRow(plan: entry.value, profile: profile)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button("复制", systemImage: "plus.square.on.square") {
                createPlan(copying: entry.key)
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button("删除", systemImage: "trash", role: .destructive) {
                remove(entry.key)
            }
        }
    }

    private func createPlan(copying sourceId: String?) {
        var temporary = profile
        do {
            let id = try ProfileEditingService.addClassPlan(to: &temporary, copying: sourceId)
            guard let value = temporary.classPlans[id] else { return }
            editingPlan = ClassPlanEditorDraft(sourceId: nil, proposedId: id, value: value)
        } catch {
            onError(error)
        }
    }

    private func commit(_ draft: ClassPlanEditorDraft) -> Bool {
        var updated = profile
        do {
            let id = draft.sourceId ?? draft.proposedId
            if draft.sourceId == nil {
                updated.classPlans[id] = draft.value
            }
            try ProfileEditingService.updateClassPlan(id: id, value: draft.value, in: &updated)
            profile = updated
            return true
        } catch {
            onError(error)
            return false
        }
    }

    private func remove(_ id: String) {
        var updated = profile
        do {
            try ProfileEditingService.removeClassPlan(id: id, from: &updated)
            profile = updated
        } catch {
            onError(error)
        }
    }
}

private struct ClassPlanRow: View {
    let plan: ClassIslandClassPlan
    let profile: ClassIslandProfile

    private var layoutName: String {
        guard let key = profile.key(in: profile.timeLayouts, matching: plan.timeLayoutId) else { return "时间表缺失" }
        return profile.timeLayouts[key]?.name ?? "时间表缺失"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: plan.isOverlay ? "square.3.layers.3d" : "doc.text")
                .foregroundStyle(plan.isOverlay ? Color.orange : Color.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(plan.isOverlay ? "临时层" : weekdayTitle(plan.timeRule.weekDay))
                    Text("·")
                    Text(layoutName)
                    if plan.timeRule.weekCountDiv > 0 {
                        Text("· \(plan.timeRule.weekCountDiv)/\(plan.timeRule.weekCountDivTotal) 周")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            if !plan.isEnabled && !plan.isOverlay {
                Image(systemName: "tag.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("未自动启用")
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct ClassPlanEditorDraft: Identifiable {
    let id = UUID()
    let sourceId: String?
    let proposedId: String
    var value: ClassIslandClassPlan
}

private struct ClassPlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sourceId: String?
    let proposedId: String
    let profile: ClassIslandProfile
    let onSave: (ClassPlanEditorDraft) -> Bool

    @State private var value: ClassIslandClassPlan

    init(
        draft: ClassPlanEditorDraft,
        profile: ClassIslandProfile,
        onSave: @escaping (ClassPlanEditorDraft) -> Bool
    ) {
        sourceId = draft.sourceId
        proposedId = draft.proposedId
        self.profile = profile
        self.onSave = onSave
        _value = State(initialValue: draft.value)
    }

    private var classPoints: [ClassIslandTimePoint] {
        guard let key = profile.key(in: profile.timeLayouts, matching: value.timeLayoutId),
              let layout = profile.timeLayouts[key] else { return [] }
        return layout.layouts.filter { $0.timeType == 0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("课表信息") {
                    TextField("名称", text: $value.name)
                    Picker("时间表", selection: $value.timeLayoutId) {
                        ForEach(ProfileEditingService.sortedEntries(profile.timeLayouts), id: \.key) { entry in
                            Text(entry.value.name).tag(entry.key)
                        }
                    }
                    .onChange(of: value.timeLayoutId) { _, _ in normalizeLocalClasses() }

                    Picker("课表群", selection: $value.associatedGroup) {
                        ForEach(ProfileEditingService.sortedEntries(profile.classPlanGroups), id: \.key) { entry in
                            Text(entry.value.name).tag(entry.key)
                        }
                    }
                    Toggle("自动启用", isOn: $value.isEnabled)
                        .disabled(value.isOverlay)
                }

                if !value.isOverlay {
                    Section("触发规则") {
                        Picker("星期", selection: $value.timeRule.weekDay) {
                            ForEach(0...6, id: \.self) { day in
                                Text(weekdayTitle(day)).tag(day)
                            }
                        }
                        Toggle(
                            "启用多周轮换",
                            isOn: Binding(
                                get: { value.timeRule.weekCountDiv > 0 },
                                set: { enabled in
                                    value.timeRule.weekCountDiv = enabled ? 1 : 0
                                }
                            )
                        )
                        if value.timeRule.weekCountDiv > 0 {
                            Stepper(
                                "轮换周期：\(value.timeRule.weekCountDivTotal) 周",
                                value: $value.timeRule.weekCountDivTotal,
                                in: 2...12
                            )
                            Picker("启用周", selection: $value.timeRule.weekCountDiv) {
                                ForEach(1...value.timeRule.weekCountDivTotal, id: \.self) { week in
                                    Text("第 \(week) 周").tag(week)
                                }
                            }
                        }
                    }
                }

                Section {
                    ForEach(Array(classPoints.enumerated()), id: \.element.id) { index, point in
                        if value.classes.indices.contains(index) {
                            ClassInfoEditorRow(
                                index: index,
                                point: point,
                                subjects: profile.subjects,
                                value: $value.classes[index]
                            )
                        }
                    }
                } header: {
                    Text("课程")
                } footer: {
                    Text("课程顺序由所选时间表中的上课时间点决定。")
                }
            }
            .navigationTitle(sourceId == nil ? "添加课表" : "编辑课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        normalizeLocalClasses()
                        let saved = onSave(
                            ClassPlanEditorDraft(
                                sourceId: sourceId,
                                proposedId: proposedId,
                                value: value
                            )
                        )
                        if saved {
                            dismiss()
                        }
                    }
                    .disabled(value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { normalizeLocalClasses() }
            .onChange(of: value.timeRule.weekCountDivTotal) { _, total in
                value.timeRule.weekCountDiv = min(value.timeRule.weekCountDiv, total)
            }
        }
    }

    private func normalizeLocalClasses() {
        let targetCount = classPoints.count
        if value.classes.count > targetCount {
            value.classes.removeLast(value.classes.count - targetCount)
        } else if value.classes.count < targetCount {
            let subjectId = ProfileEditingService.sortedEntries(profile.subjects).first?.key
                ?? ProfileEditingService.emptyId
            value.classes.append(
                contentsOf: Array(
                    repeating: ClassIslandClassInfo(subjectId: subjectId),
                    count: targetCount - value.classes.count
                )
            )
        }
    }
}

private struct ClassInfoEditorRow: View {
    let index: Int
    let point: ClassIslandTimePoint
    let subjects: [String: ClassIslandSubject]
    @Binding var value: ClassIslandClassInfo

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("第 \(index + 1) 节")
                    .font(.subheadline.weight(.medium))
                Text("\(shortTime(point.startTimeValue))–\(shortTime(point.endTimeValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Picker("科目", selection: $value.subjectId) {
                Text("未设置").tag(ProfileEditingService.emptyId)
                ForEach(ProfileEditingService.sortedEntries(subjects), id: \.key) { entry in
                    Text(entry.value.name).tag(entry.key)
                }
            }
            .labelsHidden()
            Toggle("启用", isOn: $value.isEnabled)
                .labelsHidden()
        }
    }
}

struct ClassPlanGroupsEditorView: View {
    @Binding var profile: ClassIslandProfile
    let onError: (Error) -> Void

    @State private var editingGroup: GroupEditorDraft?
    @State private var deletingGroupId: String?

    private var groups: [(key: String, value: ClassIslandClassPlanGroup)] {
        ProfileEditingService.sortedEntries(profile.classPlanGroups)
    }

    var body: some View {
        List {
            Section("当前课表群") {
                Picker("启用课表群", selection: $profile.selectedClassPlanGroupId) {
                    ForEach(groups.filter { !isGlobalGroup($0.key) }, id: \.key) { entry in
                        Text(entry.value.name).tag(entry.key)
                    }
                }
            }

            Section {
                ForEach(groups, id: \.key) { entry in
                    if isProtected(entry.key) {
                        groupRow(entry, showsDisclosure: false)
                    } else {
                        Button {
                            editingGroup = GroupEditorDraft(sourceId: entry.key, value: entry.value)
                        } label: {
                            groupRow(entry, showsDisclosure: true)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("删除", systemImage: "trash", role: .destructive) {
                                deletingGroupId = entry.key
                            }
                        }
                    }
                }
            } header: {
                EditorSectionHeader(
                    title: "课表群",
                    subtitle: "对课表分组，并选择当前启用的课表群。",
                    addTitle: "添加课表群"
                ) {
                    editingGroup = GroupEditorDraft(sourceId: nil, value: ClassIslandClassPlanGroup())
                }
            }
        }
        .editorListStyle()
        .sheet(item: $editingGroup) { draft in
            GroupEditorSheet(draft: draft) { saved in
                commit(saved)
            }
        }
        .confirmationDialog(
            "删除课表群",
            isPresented: Binding(
                get: { deletingGroupId != nil },
                set: { if !$0 { deletingGroupId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("解散课表群") { removeGroup(deletingPlans: false) }
            Button("删除课表群及其中课表", role: .destructive) { removeGroup(deletingPlans: true) }
            Button("取消", role: .cancel) { deletingGroupId = nil }
        } message: {
            Text("解散会把其中课表移到默认课表群；删除则会同时删除其中课表。")
        }
    }

    private func commit(_ draft: GroupEditorDraft) -> Bool {
        var updated = profile
        do {
            let id = draft.sourceId ?? ProfileEditingService.addGroup(to: &updated)
            try ProfileEditingService.updateGroup(id: id, value: draft.value, in: &updated)
            profile = updated
            return true
        } catch {
            onError(error)
            return false
        }
    }

    private func removeGroup(deletingPlans: Bool) {
        guard let deletingGroupId else { return }
        var updated = profile
        do {
            try ProfileEditingService.removeGroup(
                id: deletingGroupId,
                deletingPlans: deletingPlans,
                from: &updated
            )
            profile = updated
            self.deletingGroupId = nil
        } catch {
            onError(error)
        }
    }

    private func planCount(in groupId: String) -> Int {
        profile.classPlans.values.filter {
            $0.associatedGroup.caseInsensitiveCompare(groupId) == .orderedSame
        }.count
    }

    private func isProtected(_ id: String) -> Bool {
        id.caseInsensitiveCompare(ClassIslandClassPlan.defaultGroupId) == .orderedSame
            || id.caseInsensitiveCompare(ClassIslandClassPlan.globalGroupId) == .orderedSame
    }

    private func isGlobalGroup(_ id: String) -> Bool {
        id.caseInsensitiveCompare(ClassIslandClassPlan.globalGroupId) == .orderedSame
    }

    private func groupRow(
        _ entry: (key: String, value: ClassIslandClassPlanGroup),
        showsDisclosure: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isGlobalGroup(entry.key) ? "globe" : "folder")
                .foregroundStyle(isGlobalGroup(entry.key) ? Color.orange : Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.value.name)
                    .foregroundStyle(.primary)
                Text("\(planCount(in: entry.key)) 个课表")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isProtected(entry.key) {
                Text("系统")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct GroupEditorDraft: Identifiable {
    let id = UUID()
    let sourceId: String?
    var value: ClassIslandClassPlanGroup
}

private struct GroupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sourceId: String?
    let onSave: (GroupEditorDraft) -> Bool
    @State private var value: ClassIslandClassPlanGroup

    init(
        draft: GroupEditorDraft,
        onSave: @escaping (GroupEditorDraft) -> Bool
    ) {
        sourceId = draft.sourceId
        self.onSave = onSave
        _value = State(initialValue: draft.value)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("名称", text: $value.name)
            }
            .navigationTitle(sourceId == nil ? "添加课表群" : "编辑课表群")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if onSave(GroupEditorDraft(sourceId: sourceId, value: value)) {
                            dismiss()
                        }
                    }
                    .disabled(value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct OrderedSchedulesEditorView: View {
    @Binding var profile: ClassIslandProfile
    let onError: (Error) -> Void

    @State private var isAdding = false
    @State private var selectedDate = Date()
    @State private var selectedPlanId = ""

    private var schedules: [(key: String, value: ClassIslandOrderedSchedule)] {
        ProfileEditingService.sortedOrderedSchedules(profile)
    }

    var body: some View {
        List {
            Section {
                if schedules.isEmpty {
                    ContentUnavailableView("没有预定课表", systemImage: "calendar.badge.clock")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(schedules, id: \.key) { entry in
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(planName(entry.value.classPlanId))
                                    .font(.body.weight(.medium))
                                Text(scheduleDate(entry.key))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete {
                        var updated = profile
                        ProfileEditingService.removeOrderedSchedules(at: $0, from: &updated)
                        profile = updated
                    }
                }
            } header: {
                EditorSectionHeader(
                    title: "预定课表",
                    subtitle: "在指定日期优先使用某个课表。",
                    addTitle: "添加预定"
                ) {
                    selectedDate = Date()
                    selectedPlanId = ProfileEditingService.sortedEntries(profile.classPlans).first?.key ?? ""
                    isAdding = true
                }
            }
        }
        .editorListStyle()
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                Form {
                    DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                    Picker("课表", selection: $selectedPlanId) {
                        ForEach(ProfileEditingService.sortedEntries(profile.classPlans), id: \.key) { entry in
                            Text(entry.value.name).tag(entry.key)
                        }
                    }
                }
                .navigationTitle("添加预定")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { isAdding = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("添加") { addSchedule() }
                            .disabled(selectedPlanId.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func addSchedule() {
        var updated = profile
        do {
            try ProfileEditingService.setOrderedSchedule(
                on: selectedDate,
                classPlanId: selectedPlanId,
                in: &updated
            )
            profile = updated
            isAdding = false
        } catch {
            onError(error)
        }
    }

    private func planName(_ id: String) -> String {
        guard let key = profile.key(in: profile.classPlans, matching: id) else { return "课表已删除" }
        return profile.classPlans[key]?.name ?? "课表已删除"
    }

    private func scheduleDate(_ value: String) -> String {
        guard let date = ClassIslandDateParser.date(from: value) else { return value }
        return date.formatted(.dateTime.year().month().day().weekday(.wide))
    }
}

private struct EditorSectionHeader: View {
    let title: String
    let subtitle: String
    let addTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .textCase(nil)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(addTitle, systemImage: "plus", action: action)
                .font(.caption.weight(.semibold))
                .textCase(nil)
        }
    }
}

private struct EditorCommandStrip: View {
    let title: String
    let subtitle: String
    let addTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(addTitle, systemImage: "plus", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

private extension View {
    func editorListStyle() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
    }
}

private func shortTime(_ value: String) -> String {
    let pieces = value.split(separator: ":")
    guard pieces.count >= 2 else { return value }
    return "\(pieces[0]):\(pieces[1])"
}

private func timeDate(_ value: String) -> Date {
    let start = Calendar.current.startOfDay(for: Date())
    let seconds = ClassIslandDateParser.secondsSinceMidnight(value) ?? 0
    return Calendar.current.date(byAdding: .second, value: Int(seconds), to: start) ?? start
}

private func timeString(_ date: Date) -> String {
    let values = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    return String(format: "%02d:%02d:%02d", values.hour ?? 0, values.minute ?? 0, values.second ?? 0)
}

private func weekdayTitle(_ weekday: Int) -> String {
    switch weekday {
    case 0: "星期日"
    case 1: "星期一"
    case 2: "星期二"
    case 3: "星期三"
    case 4: "星期四"
    case 5: "星期五"
    case 6: "星期六"
    default: "未知星期"
    }
}
