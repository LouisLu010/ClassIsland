import SwiftUI

private enum WeatherSettingsSheet: String, Hashable, Identifiable {
    case cityPicker

    var id: Self { self }
}

struct WeatherSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var presentedSheet: WeatherSettingsSheet?

    var body: some View {
        SettingsPageLayout(title: "天气") {
            SettingsSectionTitle("天气服务", systemImage: "cloud.sun")

            SettingsCard(
                systemImage: "cloud.sun.fill",
                title: "启用天气",
                description: "显示当前天气、预报和预警，并向实时活动提供天气数据。"
            ) {
                Toggle("启用天气", isOn: $model.settings.weatherEnabled)
                    .labelsHidden()
            }

            currentWeatherPanel

            SettingsSectionTitle("位置", systemImage: "location")

            SettingsPanel(
                systemImage: "mappin.and.ellipse",
                title: "天气城市",
                description: "使用手动选择的城市获取天气，无需定位权限。"
            ) {
                SettingsInlineRow(
                    title: model.settings.weatherCityName,
                    description: model.settings.weatherCityID
                ) {
                    Button("更改", systemImage: "magnifyingglass") {
                        presentedSheet = .cityPicker
                    }
                    .buttonStyle(.bordered)
                }
            }

            if model.settings.weatherEnabled, let weather = model.weather {
                forecastPanel(weather)
                alertsPanel(weather)
            }

            if !model.weatherStatusMessage.isEmpty {
                SettingsStatusMessage(model.weatherStatusMessage)
            }

            SettingsInfoBanner("天气数据来自小米天气；无网络时会继续显示本机最近一次缓存。")
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .cityPicker:
                WeatherCityPickerView()
            }
        }
    }

    @ViewBuilder
    private var currentWeatherPanel: some View {
        if let weather = model.weather {
            SettingsPanel(
                systemImage: weather.presentation.symbolName(for: .condition),
                title: weather.city.displayName,
                description: "更新于 \(weather.updatedAt.formatted(date: .abbreviated, time: .shortened))"
            ) {
                WeatherOverview(snapshot: weather)
                    .padding(16)

                Divider()

                refreshRow
            }
            .opacity(model.settings.weatherEnabled ? 1 : 0.6)
        } else {
            SettingsPanel(
                systemImage: "cloud.slash",
                title: model.settings.weatherCityName,
                description: model.settings.weatherEnabled ? "尚未取得天气数据。" : "天气服务已关闭。"
            ) {
                refreshRow
            }
        }
    }

    private var refreshRow: some View {
        HStack(spacing: 10) {
            if model.isRefreshingWeather {
                ProgressView()
                    .controlSize(.small)
                Text("正在更新天气")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("立即刷新", systemImage: "arrow.clockwise") {
                Task { await model.refreshWeather() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.settings.weatherEnabled || model.isRefreshingWeather)
        }
        .padding(12)
    }

    private func forecastPanel(_ weather: WeatherSnapshot) -> some View {
        Group {
            if !weather.dailyForecast.isEmpty {
                SettingsSectionTitle("近期预报", systemImage: "calendar")

                SettingsPanel(
                    systemImage: "calendar.badge.clock",
                    title: "未来天气",
                    description: "所选城市最近几天的天气与温度范围。"
                ) {
                    ForEach(Array(weather.dailyForecast.prefix(3)).indices, id: \.self) { index in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 12)
                        }
                        WeatherForecastRow(forecast: weather.dailyForecast[index])
                    }
                }
            }
        }
    }

    private func alertsPanel(_ weather: WeatherSnapshot) -> some View {
        Group {
            SettingsSectionTitle("气象预警", systemImage: "exclamationmark.triangle")

            if weather.alerts.isEmpty {
                SettingsCard(
                    systemImage: "checkmark.shield",
                    title: "当前无气象预警",
                    description: "天气服务没有返回该城市的有效预警。"
                ) {
                    EmptyView()
                }
            } else {
                SettingsPanel(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "\(weather.alerts.count) 条气象预警",
                    description: "按发布时间保留每种类型的最新预警。"
                ) {
                    ForEach(Array(weather.alerts.prefix(3)).indices, id: \.self) { index in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 12)
                        }
                        WeatherAlertRow(alert: weather.alerts[index])
                    }
                }
            }
        }
    }
}

private struct WeatherOverview: View {
    let snapshot: WeatherSnapshot

    private var presentation: WeatherPresentation {
        snapshot.presentation
    }

    private let metrics: [WeatherMetric] = [
        .feelsLike,
        .humidity,
        .wind,
        .airQuality,
        .pressure
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: presentation.symbolName(for: .condition))
                    .font(.system(size: 38, weight: .medium))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.conditionTitle)
                        .font(.headline)
                    Text(snapshot.current.temperature)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104, maximum: 180), spacing: 14)],
                alignment: .leading,
                spacing: 14
            ) {
                ForEach(metrics) { metric in
                    WeatherMetricValue(
                        metric: metric,
                        value: metricValue(metric)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricValue(_ metric: WeatherMetric) -> String {
        switch metric {
        case .condition: presentation.value(for: .condition)
        case .humidity: snapshot.current.humidity
        case .wind: snapshot.current.windSpeed
        case .airQuality: snapshot.airQualityIndex
        case .pressure: snapshot.current.pressure
        case .feelsLike: snapshot.current.feelsLike
        }
    }
}

private struct WeatherMetricValue: View {
    let metric: WeatherMetric
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: metric.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(metric.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct WeatherForecastRow: View {
    let forecast: WeatherDailyForecast

    private var dateLabel: String {
        if Calendar.current.isDateInToday(forecast.date) {
            return "今天"
        }
        if Calendar.current.isDateInTomorrow(forecast.date) {
            return "明天"
        }
        return forecast.date.formatted(.dateTime.month().day().weekday(.abbreviated))
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: forecast.symbolName)
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(.subheadline.weight(.medium))
                Text(forecast.conditionTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text("\(forecast.lowTemperature) / \(forecast.highTemperature)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
    }
}

private struct WeatherAlertRow: View {
    let alert: WeatherAlert

    var body: some View {
        if alert.detail.isEmpty {
            label
                .padding(12)
        } else {
            DisclosureGroup {
                Text(alert.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            } label: {
                label
            }
            .padding(12)
        }
    }

    private var label: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if !alert.level.isEmpty {
                    Text(alert.level)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct WeatherCityPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if model.weatherCitySearchResults.isEmpty {
                    emptyState
                } else {
                    cityList
                }
            }
            .navigationTitle("选择天气城市")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜索城市或区县")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .task(id: query) {
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                }
                guard !Task.isCancelled else { return }
                await model.searchWeatherCities(query: query)
            }
        }
        .onDisappear {
            model.clearWeatherCitySearch()
        }
    }

    private var cityList: some View {
        List(model.weatherCitySearchResults) { city in
            Button {
                model.selectWeatherCity(city)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mappin")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(city.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        if !city.affiliation.isEmpty {
                            Text(city.affiliation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                    if city.id == model.settings.weatherCityID {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel("当前城市")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.isSearchingWeatherCities {
            VStack(spacing: 12) {
                ProgressView()
                Text(query.isEmpty ? "正在载入热门城市" : "正在搜索城市")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                model.weatherCitySearchMessage.isEmpty
                    ? "输入城市名称"
                    : model.weatherCitySearchMessage,
                systemImage: "magnifyingglass"
            )
        }
    }
}
